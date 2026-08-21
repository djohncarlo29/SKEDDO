// ─────────────────────────────────────────────────────────────────────────────
// WordPieceTokenizer — BERT-style tokenizer for all-MiniLM-L6-v2.
//
// Implements the standard BERT tokenization pipeline:
//   1. Lowercase + whitespace split
//   2. Punctuation separation
//   3. WordPiece subword segmentation against a fixed vocabulary
//   4. Special-token wrapping ([CLS] … [SEP]) and padding/truncation
//
// Produces input_ids, attention_mask, and token_type_ids tensors — the
// exact three inputs expected by the all-MiniLM-L6-v2 ONNX model.
// ─────────────────────────────────────────────────────────────────────────────

class TokenizerOutput {
  final List<int> inputIds;
  final List<int> attentionMask;
  final List<int> tokenTypeIds;

  const TokenizerOutput({
    required this.inputIds,
    required this.attentionMask,
    required this.tokenTypeIds,
  });
}

class WordPieceTokenizer {
  final Map<String, int> _vocab;
  final int _maxLen;
  final int _clsId;
  final int _sepId;
  final int _padId;
  final int _unkId;

  WordPieceTokenizer._(
    this._vocab,
    this._maxLen,
    this._clsId,
    this._sepId,
    this._padId,
    this._unkId,
  );

  /// Build from the lines of a BERT vocab.txt file.
  factory WordPieceTokenizer.fromVocabLines(
    List<String> lines, {
    int maxLen = 128,
  }) {
    final vocab = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.isNotEmpty) vocab[t] = i;
    }
    return WordPieceTokenizer._(
      vocab,
      maxLen,
      vocab['[CLS]'] ?? 101,
      vocab['[SEP]'] ?? 102,
      vocab['[PAD]'] ?? 0,
      vocab['[UNK]'] ?? 100,
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  TokenizerOutput encode(String text) {
    final tokens = _tokenize(text);

    // Truncate to maxLen − 2 (reserve slots for [CLS] and [SEP]).
    final truncated = tokens.length > _maxLen - 2
        ? tokens.sublist(0, _maxLen - 2)
        : tokens;

    final ids = [_clsId, ...truncated.map(_lookupId), _sepId];
    final seqLen = ids.length;

    // Pad to maxLen.
    final padded = [...ids, ...List.filled(_maxLen - seqLen, _padId)];
    final mask = [
      ...List.filled(seqLen, 1),
      ...List.filled(_maxLen - seqLen, 0),
    ];
    final typeIds = List.filled(_maxLen, 0);

    return TokenizerOutput(
      inputIds: padded,
      attentionMask: mask,
      tokenTypeIds: typeIds,
    );
  }

  // ── Tokenization pipeline ──────────────────────────────────────────────────

  List<String> _tokenize(String text) {
    // 1. Lowercase.
    final lower = text.toLowerCase();

    // 2. Whitespace + punctuation split → basic tokens.
    final basic = _basicTokenize(lower);

    // 3. WordPiece segmentation for each basic token.
    final result = <String>[];
    for (final token in basic) {
      result.addAll(_wordPiece(token));
    }
    return result;
  }

  List<String> _basicTokenize(String text) {
    final buf = StringBuffer();
    for (final cp in text.runes) {
      final ch = String.fromCharCode(cp);
      if (_isPunct(cp) || _isWhitespace(cp)) {
        if (buf.isNotEmpty) {
          // Yield the buffered word before adding the punctuation.
        }
        if (_isPunct(cp)) buf.write(' $ch ');
        else buf.write(' ');
      } else {
        buf.write(ch);
      }
    }
    return buf.toString().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  List<String> _wordPiece(String word) {
    if (_vocab.containsKey(word)) return [word];
    if (word.length > 100) return ['[UNK]'];

    final pieces = <String>[];
    var start = 0;
    while (start < word.length) {
      var end = word.length;
      String? found;
      while (start < end) {
        final sub = (start == 0 ? '' : '##') + word.substring(start, end);
        if (_vocab.containsKey(sub)) {
          found = sub;
          break;
        }
        end--;
      }
      if (found == null) return ['[UNK]'];
      pieces.add(found);
      start = end;
    }
    return pieces;
  }

  int _lookupId(String token) => _vocab[token] ?? _unkId;

  static bool _isWhitespace(int cp) =>
      cp == 0x20 || cp == 0x09 || cp == 0x0A || cp == 0x0D;

  static bool _isPunct(int cp) {
    if ((cp >= 33 && cp <= 47) ||
        (cp >= 58 && cp <= 64) ||
        (cp >= 91 && cp <= 96) ||
        (cp >= 123 && cp <= 126)) return true;
    // Unicode General Category P* and S*
    final cat = _unicodeCat(cp);
    return cat == 'P' || cat == 'S';
  }

  static String _unicodeCat(int cp) {
    // Simplified: only ASCII range matters for the embedding use-case.
    return '';
  }
}
