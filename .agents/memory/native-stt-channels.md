---
name: Native STT channels
description: speech_to_text removed; native OS speech recognition wired via MethodChannel + EventChannel.
---

## Rule
The app uses a hand-rolled native STT bridge instead of `speech_to_text`.

**MethodChannel:** `com.smartscheduler/stt`  
Methods: `requestPermission → bool`, `isAvailable → bool`, `start → bool`, `stop`, `cancel`

**EventChannel:** `com.smartscheduler/stt_events`  
Events: `{"type":"partial","words":String}`, `{"type":"final","words":String}`, `{"type":"error","message":String}`

## iOS (`ios/Runner/NativeStt.swift`)
- `SFSpeechRecognizer` + `AVAudioEngine`
- 3-second silence timer; resets on every partial result; fires `stopListening` on expiry
- `tapInstalled` Bool guard — always check before calling `inputNode.removeTap` to avoid crash
- SFSpeechRecognizer error code 1110 ("no speech") is suppressed (expected on silence)
- Registered in `AppDelegate.swift` via `FlutterViewController.binaryMessenger`

## Android (`NativeSttPlugin.kt`)
- `SpeechRecognizer` with `EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS = 3000`
- Permission requested via `ActivityCompat.requestPermissions`; result forwarded from `MainActivity.onRequestPermissionsResult`
- `ERROR_NO_MATCH` (7) and `ERROR_SPEECH_TIMEOUT` (6) → emit empty final result, not error
- Destroy + recreate `SpeechRecognizer` per session (required by Android API)

## Dart (`lib/services/speech_service.dart`)
- Same public API as before: `SttRequestResult`, `requestPermission`, `startListening`, `stop`, `cancel`, `isListening`, `isAvailable`
- `kIsWeb` guard returns `denied`/`false` on web (no native channels)
- Subscribe to EventChannel stream BEFORE invoking `start` to avoid dropping early events
- `MicPermissionSheet` / `_MicPermissionSheetOverlay` UI widgets are unchanged

**Why:** `speech_to_text` v7 had a silent session-lifecycle bug (recognizer stuck in "completed" state after first use). Native implementation gives full lifecycle control and eliminates the workaround.
