package com.smartscheduler.smart_scheduler

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// ── NativeSttPlugin ───────────────────────────────────────────────────────────
//
// MethodChannel  "com.smartscheduler/stt"
//   → requestPermission  () → Bool
//   → isAvailable        () → Bool
//   → start              () → Bool
//   → stop               ()
//   → cancel             ()
//
// EventChannel   "com.smartscheduler/stt_events"
//   ← mapOf("type" to "partial", "words" to String)
//   ← mapOf("type" to "final",   "words" to String)
//   ← mapOf("type" to "error",   "message" to String)
//
// Silence detection is handled by Android's own SpeechRecognizer via the
// EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS extra (3 000 ms).

class NativeSttPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    RecognitionListener {

    companion object {
        const val PERMISSION_CODE = 201
    }

    private val methodChannel = MethodChannel(messenger, "com.smartscheduler/stt")
    private val eventChannel  = EventChannel(messenger, "com.smartscheduler/stt_events")

    private var eventSink: EventChannel.EventSink? = null
    private var speechRecognizer: SpeechRecognizer? = null

    // Stored while we wait for the OS permission dialog.
    private var pendingPermResult: MethodChannel.Result? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    // ── MethodCallHandler ─────────────────────────────────────────────────────
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                if (ContextCompat.checkSelfPermission(
                        activity, Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    result.success(true)
                } else {
                    pendingPermResult = result
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        PERMISSION_CODE,
                    )
                    // result will be completed in onRequestPermissionsResult()
                }
            }

            "isAvailable" -> {
                val granted = ContextCompat.checkSelfPermission(
                    activity, Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED
                result.success(granted && SpeechRecognizer.isRecognitionAvailable(activity))
            }

            "start"  -> startListening(result)
            "stop"   -> { speechRecognizer?.stopListening(); result.success(null) }
            "cancel" -> { destroyRecognizer(); result.success(null) }
            else     -> result.notImplemented()
        }
    }

    // Called by MainActivity.onRequestPermissionsResult.
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_CODE) return
        val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermResult?.success(granted)
        pendingPermResult = null
    }

    // ── Listening ─────────────────────────────────────────────────────────────
    private fun startListening(result: MethodChannel.Result) {
        destroyRecognizer()

        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            result.error("NOT_AVAILABLE", "SpeechRecognizer not available on this device", null)
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(activity)
        speechRecognizer?.setRecognitionListener(this)

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // End the session after three seconds of silence.
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 3_000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 3_000L)
        }

        speechRecognizer?.startListening(intent)
        result.success(true)
    }

    private fun destroyRecognizer() {
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    // ── RecognitionListener ───────────────────────────────────────────────────
    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {}
    override fun onEvent(eventType: Int, params: Bundle?) {}

    override fun onPartialResults(partialResults: Bundle?) {
        val words = partialResults
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull() ?: return
        if (words.isNotEmpty()) {
            eventSink?.success(mapOf("type" to "partial", "words" to words))
        }
    }

    override fun onResults(results: Bundle?) {
        val words = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull() ?: ""
        eventSink?.success(mapOf("type" to "final", "words" to words))
        destroyRecognizer()
    }

    override fun onError(error: Int) {
        // ERROR_NO_MATCH (7) and ERROR_SPEECH_TIMEOUT (6) are expected on
        // silence — send an empty final result so the caller can reset its UI.
        if (error == SpeechRecognizer.ERROR_NO_MATCH ||
            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
            eventSink?.success(mapOf("type" to "final", "words" to ""))
        } else {
            eventSink?.success(mapOf("type" to "error", "message" to "SpeechRecognizer error $error"))
        }
        destroyRecognizer()
    }

    // ── EventChannel.StreamHandler ────────────────────────────────────────────
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        destroyRecognizer()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
