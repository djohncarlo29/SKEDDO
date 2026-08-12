---
name: STT session lifecycle — speech_to_text v7
description: Why STT breaks after the first use and how to reliably restart it.
---

## The rule
Always call `cancel()` + `await Future.delayed(250ms)` + `initialize()` before every `listen()` call. Never skip this even when `isListening` is `false`.

## Why
`speech_to_text` v7 does NOT recreate the native `SpeechRecognizer` (Android) or `SFSpeechAudioBufferRecognitionRequest` (iOS) between sessions. After a session ends via `pauseFor` auto-stop, `isListening` becomes `false` but the platform recognizer is in a "completed" state. Calling `listen()` on it again silently fails — Android's `SpeechRecognizer.startListening()` is rejected on a completed instance. The 250ms delay lets the OS fully release the microphone handle before the next `initialize()` + `listen()`.

## Symptoms without the fix
- STT works exactly once per app session
- On second tap: pulsing mic UI shows (because `_micListening = true` was set optimistically before the await) but green Android privacy dot never appears and no audio is captured
- No error or exception is thrown — the failure is completely silent

## How to apply
In `SpeechService.startListening()`:
```dart
await _stt.cancel();                                    // always, even if !isListening
await Future.delayed(const Duration(milliseconds: 250)); // OS mic handle release
_initialized = await _stt.initialize(...);              // fresh recognizer
if (!_initialized || !_stt.isAvailable) return false;
await _stt.listen(...);
return true;
```

## UI contract
`startListening()` returns `bool`. The caller sets `_micListening = true` optimistically before the await for immediate visual feedback. If `false` is returned, caller must reset `_micListening = false` so the user isn't stuck on a pulsing mic recording nothing.

## pauseFor window
`pauseFor: 3s` (increased from 2s). After Android detects end-of-speech the green dot goes away, but `onFinal` doesn't fire until `pauseFor` expires. Users see pulsing mic but no green dot during this 3s window — this is expected and correct.
