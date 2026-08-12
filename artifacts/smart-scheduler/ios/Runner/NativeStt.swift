import AVFoundation
import Flutter
import Speech

// ── NativeSttPlugin ───────────────────────────────────────────────────────────
//
// Implements speech recognition via SFSpeechRecognizer + AVAudioEngine and
// bridges it to Dart through two channels:
//
//   MethodChannel  "com.smartscheduler/stt"
//     → requestPermission  () → Bool
//     → isAvailable        () → Bool
//     → start              () → Bool
//     → stop               ()
//     → cancel             ()
//
//   EventChannel   "com.smartscheduler/stt_events"
//     ← { "type": "partial", "words": String }
//     ← { "type": "final",   "words": String }
//     ← { "type": "error",   "message": String }
//
// Silence handling:  a 3-second Timer resets on every partial result.  If the
// user is silent for 3 s (including the initial silence) the recognizer stops
// automatically, matching the behaviour of speech_to_text's pauseFor:3s.

class NativeSttPlugin: NSObject, FlutterStreamHandler {

    // ── Channels ──────────────────────────────────────────────────────────────
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    // ── Recognition state ─────────────────────────────────────────────────────
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var silenceTimer: Timer?

    // ── Init ──────────────────────────────────────────────────────────────────
    init(messenger: FlutterBinaryMessenger) {
        super.init()

        methodChannel = FlutterMethodChannel(
            name: "com.smartscheduler/stt",
            binaryMessenger: messenger
        )
        methodChannel?.setMethodCallHandler(handle)

        eventChannel = FlutterEventChannel(
            name: "com.smartscheduler/stt_events",
            binaryMessenger: messenger
        )
        eventChannel?.setStreamHandler(self)
    }

    // ── Method dispatch ───────────────────────────────────────────────────────
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    result(status == .authorized)
                }
            }

        case "isAvailable":
            let avail = SFSpeechRecognizer(locale: .current)?.isAvailable == true
                && SFSpeechRecognizer.authorizationStatus() == .authorized
            result(avail)

        case "start":
            startListening(result: result)

        case "stop":
            stopListening()
            result(nil)

        case "cancel":
            cancelListening()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ── Start ─────────────────────────────────────────────────────────────────
    private func startListening(result: @escaping FlutterResult) {
        // Always cancel any previous session before starting a new one.
        cancelListening()

        // Audio session: record mode, duck others.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            result(FlutterError(code: "AUDIO_SESSION", message: error.localizedDescription, details: nil))
            return
        }

        guard
            let recognizer = SFSpeechRecognizer(locale: .current),
            recognizer.isAvailable
        else {
            result(FlutterError(code: "NOT_AVAILABLE", message: "SFSpeechRecognizer not available", details: nil))
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else {
            result(FlutterError(code: "REQUEST", message: "Could not create recognition request", details: nil))
            return
        }
        req.shouldReportPartialResults = true

        // Install mic tap.
        let inputNode = audioEngine.inputNode
        let fmt = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }
        tapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            removeTap()
            result(FlutterError(code: "ENGINE", message: error.localizedDescription, details: nil))
            return
        }

        // Start 3-second silence timer immediately.
        scheduleSilenceTimer()

        recognitionTask = recognizer.recognitionTask(with: req) { [weak self] res, error in
            guard let self else { return }

            if let res {
                let words = res.bestTranscription.formattedString
                if res.isFinal {
                    self.eventSink?(["type": "final", "words": words])
                    self.stopListening()
                } else if !words.isEmpty {
                    // Partial result received — reset silence timer.
                    self.scheduleSilenceTimer()
                    self.eventSink?(["type": "partial", "words": words])
                }
            }

            if let error {
                let nsErr = error as NSError
                // Code 1110 = kAFAssistantErrorDomain "No speech detected" — expected on silence.
                if nsErr.code != 1110 {
                    self.eventSink?(["type": "error", "message": error.localizedDescription])
                }
                self.stopListening()
            }
        }

        result(true)
    }

    // ── Stop (send final with whatever was recognised) ────────────────────────
    private func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        removeTap()
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // ── Cancel (discard in-progress results) ──────────────────────────────────
    private func cancelListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        removeTap()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // ── Silence timer ─────────────────────────────────────────────────────────
    private func scheduleSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.stopListening()
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    private func removeTap() {
        guard tapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    // ── FlutterStreamHandler ──────────────────────────────────────────────────
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
