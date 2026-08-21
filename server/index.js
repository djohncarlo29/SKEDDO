'use strict';
// ─────────────────────────────────────────────────────────────────────────────
// SKEDDO Gemini proxy server
//
// Handles two API routes that call Google's Gemini API server-side so the
// GEMINI_API_KEY never needs to be compiled into the Flutter binary.
//
// Also serves the Flutter web build from ../artifacts/smart-scheduler/build/web
// as a static file server, replacing the previous Python HTTP server.
// ─────────────────────────────────────────────────────────────────────────────
const http  = require('http');
const https = require('https');
const path  = require('path');
const fs    = require('fs');

const PORT    = process.env.PORT || 24355;
const WEB_DIR = path.join(__dirname, '..', 'artifacts', 'smart-scheduler', 'build', 'web');

// Load GEMINI_API_KEY from the Flutter .env asset file when it isn't already
// present in the process environment (e.g. during local dev where the Replit
// secret isn't forwarded to this Node process).
if (!process.env.GEMINI_API_KEY) {
  try {
    const envPath    = path.join(__dirname, '..', 'artifacts', 'smart-scheduler', '.env');
    const envContent = fs.readFileSync(envPath, 'utf8');
    const match      = envContent.match(/^GEMINI_API_KEY=(.+)$/m);
    if (match) process.env.GEMINI_API_KEY = match[1].trim();
  } catch (_) {}
}

const API_KEY = process.env.GEMINI_API_KEY || '';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript',
  '.css':  'text/css',
  '.json': 'application/json',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.svg':  'image/svg+xml',
  '.wasm': 'application/wasm',
  '.ico':  'image/x-icon',
  '.ttf':  'font/ttf',
  '.otf':  'font/otf',
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end',  () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString())); }
      catch (e) { reject(new Error('Invalid JSON body')); }
    });
    req.on('error', reject);
  });
}

function json(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type':  'application/json',
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

// Calls the Gemini REST API and returns the parsed response object.
function callGemini(requestBody) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(requestBody);
    const req = https.request(
      {
        hostname: 'generativelanguage.googleapis.com',
        path:     `/v1beta/models/gemini-2.5-flash:generateContent?key=${API_KEY}`,
        method:   'POST',
        headers:  {
          'Content-Type':   'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      },
      (res) => {
        const chunks = [];
        res.on('data',  c => chunks.push(c));
        res.on('end',   () => {
          try { resolve(JSON.parse(Buffer.concat(chunks).toString())); }
          catch (e) { reject(e); }
        });
      },
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function geminiText(result) {
  return result?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
}

// ── Prompts ───────────────────────────────────────────────────────────────────

const PARSE_RULE_PROMPT =
  'You are a calendar assistant. Parse a Smart Category rule into its temporal and semantic components.\n\n' +
  'Return ONLY a JSON object with this exact shape:\n' +
  '{"weekdays":[],"timeOfDay":null,"months":[],"topic":""}\n\n' +
  'Fields:\n' +
  '- weekdays: lowercase weekday names in the rule. Use "weekday" for Mon–Fri group, "weekend" for Sat–Sun group. [] = no constraint.\n' +
  '- timeOfDay: "morning" (before noon), "afternoon" (noon–5 PM), "evening" (5–9 PM), "night" (after 9 PM), or null.\n' +
  '- months: month numbers 1–12 present in the rule. [] = no constraint.\n' +
  '- topic: the semantic topic with all temporal/weekday/month words removed. May be empty string.\n\n' +
  'Examples:\n' +
  '  "weekday lunches in September" → {"weekdays":["weekday"],"timeOfDay":"afternoon","months":[9],"topic":"lunch"}\n' +
  '  "Saturday morning workouts" → {"weekdays":["saturday"],"timeOfDay":"morning","months":[],"topic":"workout"}\n' +
  '  "school events before noon" → {"weekdays":[],"timeOfDay":"morning","months":[],"topic":"school"}\n' +
  '  "doctor appointments" → {"weekdays":[],"timeOfDay":null,"months":[],"topic":"doctor appointment"}\n\n' +
  'Return ONLY the JSON object, no markdown, no explanation.';

const EXTRACT_PROMPT =
  'Analyze the attached image or document and extract every event, meeting, appointment, ' +
  'reminder, deadline, or scheduled activity you can find. ' +
  'Return a JSON array of objects. Each object must have: ' +
  '"title" (string, required), ' +
  '"date" (string, optional — use natural language like "June 5" or "next Monday"), ' +
  '"time" (string, optional — use "3:00 PM" format), ' +
  '"location" (string, optional). ' +
  'Return ONLY the raw JSON array with no markdown fences or extra text. ' +
  'If there are no events, return [].';

// ── Route handlers ────────────────────────────────────────────────────────────

async function handleExtract(req, res) {
  if (!API_KEY) { json(res, 503, { error: 'AI not configured' }); return; }
  try {
    const body = await readBody(req);
    let parts;
    if (body.imageBase64 && body.mimeType) {
      parts = [
        { inline_data: { mime_type: body.mimeType, data: body.imageBase64 } },
        { text: EXTRACT_PROMPT },
      ];
    } else if (body.text) {
      parts = [{ text: `Extract events from the following text:\n\n${body.text}\n\n${EXTRACT_PROMPT}` }];
    } else {
      json(res, 400, { error: 'Provide imageBase64+mimeType or text' });
      return;
    }

    const result = await callGemini({
      contents: [{ parts }],
      generationConfig: { maxOutputTokens: 8192 },
    });

    const raw = geminiText(result);
    const cleaned = raw
      .replace(/^```[a-z]*\n?/gm, '')
      .replace(/```$/gm, '')
      .trim();

    let events = [];
    try { events = JSON.parse(cleaned); } catch (_) {}
    if (!Array.isArray(events)) events = [];

    json(res, 200, { events });
  } catch (e) {
    console.error('[extract]', e.message);
    json(res, 500, { error: 'AI analysis failed. Please try again.' });
  }
}

async function handleParseRule(req, res) {
  if (!API_KEY) { json(res, 503, { error: 'AI not configured' }); return; }
  try {
    const body = await readBody(req);
    const rule = (typeof body.rule === 'string' ? body.rule : '').trim();
    if (!rule) { json(res, 400, { error: 'rule is required' }); return; }

    const result = await callGemini({
      contents: [{
        parts: [{ text: `Rule: "${rule}"\n\n${PARSE_RULE_PROMPT}` }],
      }],
      generationConfig: { maxOutputTokens: 256, temperature: 0.1 },
    });

    const raw = geminiText(result)
      .replace(/^```[a-z]*\n?/gm, '')
      .replace(/```$/gm, '')
      .trim();

    let parsed = {};
    try { parsed = JSON.parse(raw); } catch (_) {}

    const validTods = new Set(['morning', 'afternoon', 'evening', 'night']);
    const validDays = new Set(['monday','tuesday','wednesday','thursday','friday',
                               'saturday','sunday','weekday','weekend']);

    const weekdays = (Array.isArray(parsed.weekdays) ? parsed.weekdays : [])
      .map(d => String(d).toLowerCase())
      .filter(d => validDays.has(d));

    const timeOfDay = validTods.has(String(parsed.timeOfDay).toLowerCase())
      ? String(parsed.timeOfDay).toLowerCase()
      : null;

    const months = (Array.isArray(parsed.months) ? parsed.months : [])
      .map(m => parseInt(m, 10))
      .filter(m => m >= 1 && m <= 12);

    const topic = typeof parsed.topic === 'string' ? parsed.topic.trim() : '';

    json(res, 200, { weekdays, timeOfDay, months, topic });
  } catch (e) {
    console.error('[parse-rule]', e.message);
    json(res, 500, { error: 'Parse failed' });
  }
}

async function handlePunctuate(req, res) {
  if (!API_KEY) { json(res, 503, { error: 'AI not configured' }); return; }
  let rawText = '';
  try {
    const body = await readBody(req);
    rawText = body.text ?? '';
    if (!rawText.trim()) { json(res, 200, { result: rawText }); return; }

    const result = await callGemini({
      contents: [{
        parts: [{ text:
          'Add correct punctuation, sentence capitalisation, and ' +
          'paragraph breaks to this speech transcription. Do not ' +
          'change, add, or remove any words — only fix punctuation ' +
          'and capitalisation. Return ONLY the corrected text with ' +
          `no explanation or extra text.\n\n${rawText}`,
        }],
      }],
      generationConfig: { maxOutputTokens: 1024 },
    });

    const punctuated = geminiText(result).trim();
    json(res, 200, { result: punctuated.length ? punctuated : rawText });
  } catch (e) {
    console.error('[punctuate]', e.message);
    json(res, 200, { result: rawText }); // graceful fallback — caller uses original
  }
}

// ── Static file serving ───────────────────────────────────────────────────────

function serveStatic(req, res) {
  const urlPath = req.url.split('?')[0];
  let filePath  = path.join(WEB_DIR, urlPath === '/' ? 'index.html' : urlPath);

  // SPA fallback — unknown paths serve index.html
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(WEB_DIR, 'index.html');
  }

  const ext         = path.extname(filePath).toLowerCase();
  const contentType = MIME[ext] || 'application/octet-stream';

  // Cache strategy:
  //   HTML and root-level JS/WASM — no-cache so updated builds are served
  //   immediately.  Flutter emits main.dart.js, flutter_bootstrap.js, etc.
  //   without content hashes, so they must NOT be cached immutably.
  //
  //   Files inside assets/ subdirectory — these are content-hashed by Flutter
  //   and can be cached forever.
  const isHtml        = ext === '.html' || filePath.endsWith('index.html');
  const isHashedAsset = filePath.includes(path.sep + 'assets' + path.sep);
  const cacheControl  = (isHashedAsset && !isHtml)
    ? 'public, max-age=31536000, immutable'
    : 'no-cache, no-store, must-revalidate';

  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not Found'); return; }
    res.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': cacheControl });
    res.end(data);
  });
}

// ── Main server ───────────────────────────────────────────────────────────────

const server = http.createServer((req, res) => {
  // CORS — needed so mobile APKs can POST to the deployed server URL.
  res.setHeader('Access-Control-Allow-Origin',  '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  const url = req.url.split('?')[0];

  if (req.method === 'POST' && url === '/api/gemini/extract')    { handleExtract(req, res);    return; }
  if (req.method === 'POST' && url === '/api/gemini/punctuate')  { handlePunctuate(req, res);  return; }
  if (req.method === 'POST' && url === '/api/gemini/parse-rule') { handleParseRule(req, res);  return; }

  serveStatic(req, res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`SKEDDO proxy + web server listening on port ${PORT}`);
  if (!API_KEY) {
    console.warn('WARNING: GEMINI_API_KEY is not set — AI features are disabled.');
  }
});
