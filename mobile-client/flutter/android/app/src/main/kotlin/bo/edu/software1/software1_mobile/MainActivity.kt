package bo.edu.software1.software1_mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), RecognitionListener {
    companion object {
        private const val CHANNEL = "bo.edu.software1/speech_to_text"
        private const val TAG = "Software1Speech"
        private const val RECORD_AUDIO_REQUEST = 7101
        private const val DEFAULT_LOCALE = "es-US"
    }

    private var channel: MethodChannel? = null
    private var localLlmController: LocalLlmController? = null
    private var recognizer: SpeechRecognizer? = null
    private var pendingRecognition: MethodChannel.Result? = null
    private var pendingLocale = DEFAULT_LOCALE
    private var usingSystemRecognizer = false
    private var systemFallbackAttempted = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(::handleSpeechCall)
        }
        localLlmController = LocalLlmController(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    private fun handleSpeechCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isOfflineRecognizerAvailable())
            "listen" -> beginListening(
                call.argument<String>("locale")?.trim().orEmpty().ifEmpty { DEFAULT_LOCALE },
                result,
            )
            "stop" -> {
                recognizer?.stopListening()
                result.success(null)
            }
            "cancel" -> {
                cancelRecognition()
                result.success(null)
            }
            "dispose" -> {
                releaseRecognizer()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun isOfflineRecognizerAvailable(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)

    private fun beginListening(locale: String, result: MethodChannel.Result) {
        if (pendingRecognition != null) {
            result.error("BUSY", "A recognition session is already active.", null)
            return
        }
        if (!isOfflineRecognizerAvailable()) {
            result.error("OFFLINE_UNAVAILABLE", "On-device recognition is unavailable.", null)
            return
        }

        pendingRecognition = result
        pendingLocale = locale
        usingSystemRecognizer = false
        systemFallbackAttempted = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), RECORD_AUDIO_REQUEST)
            return
        }
        startRecognition()
    }

    private fun startRecognition(useSystemRecognizer: Boolean = false) {
        if (pendingRecognition == null) return
        try {
            if (recognizer == null || usingSystemRecognizer != useSystemRecognizer) {
                recognizer?.destroy()
                usingSystemRecognizer = useSystemRecognizer
                recognizer = if (useSystemRecognizer) {
                    SpeechRecognizer.createSpeechRecognizer(this)
                } else {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                }.also {
                    it.setRecognitionListener(this)
                }
            }
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, pendingLocale)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            }
            recognizer?.startListening(intent)
        } catch (error: UnsupportedOperationException) {
            Log.w(TAG, "On-device speech recognition is unavailable", error)
            if (!trySystemRecognizerFallback()) {
                completeError("OFFLINE_UNAVAILABLE", "Speech recognition is unavailable.")
            }
        } catch (error: SecurityException) {
            Log.w(TAG, "Microphone permission was rejected by Android", error)
            completeError("PERMISSION_DENIED", "Microphone permission is required.")
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not start speech recognition", error)
            if (useSystemRecognizer) {
                completeError("RECOGNITION_FAILED", "Could not start speech recognition.")
            } else if (!trySystemRecognizerFallback()) {
                completeError("RECOGNITION_FAILED", "Could not start speech recognition.")
            }
        }
    }

    private fun trySystemRecognizerFallback(): Boolean {
        if (pendingRecognition == null || systemFallbackAttempted) return false
        systemFallbackAttempted = true
        recognizer?.destroy()
        recognizer = null
        window.decorView.postDelayed({ startRecognition(useSystemRecognizer = true) }, 250L)
        return true
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != RECORD_AUDIO_REQUEST || pendingRecognition == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startRecognition()
        } else {
            completeError("PERMISSION_DENIED", "Microphone permission was denied.")
        }
    }

    override fun onResults(results: Bundle?) {
        val transcripts = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val transcript = transcripts?.firstOrNull()?.trim().orEmpty()
        if (transcript.isEmpty()) {
            completeError("NO_MATCH", "No speech recognition result was produced.")
            return
        }
        val confidence = results
            ?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
            ?.firstOrNull()
            ?.takeIf { it >= 0f }
            ?.toDouble()
        val payload = hashMapOf<String, Any>(
            "transcript" to transcript,
            "locale" to pendingLocale,
        )
        confidence?.let { payload["confidence"] = it }
        pendingRecognition?.success(payload)
        pendingRecognition = null
    }

    override fun onError(error: Int) {
        Log.w(
            TAG,
            "${if (usingSystemRecognizer) "System" else "On-device"} " +
                "speech recognition failed with code $error",
        )
        val canRetryWithSystemRecognizer = error == SpeechRecognizer.ERROR_CLIENT ||
            error == SpeechRecognizer.ERROR_SERVER ||
            error == SpeechRecognizer.ERROR_SERVER_DISCONNECTED ||
            error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
            error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE
        if (!usingSystemRecognizer && canRetryWithSystemRecognizer && trySystemRecognizerFallback()) {
            return
        }
        val code = when (error) {
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_SERVER -> "OFFLINE_UNAVAILABLE"
            SpeechRecognizer.ERROR_AUDIO -> "AUDIO_ERROR"
            SpeechRecognizer.ERROR_NO_MATCH -> "NO_MATCH"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "NO_SPEECH"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
            SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "BUSY"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSION_DENIED"
            SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "SERVICE_DISCONNECTED"
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "LANGUAGE_UNAVAILABLE"
            else -> "RECOGNITION_FAILED"
        }
        completeError(code, "On-device speech recognition failed with code $error.")
    }

    private fun cancelRecognition() {
        recognizer?.cancel()
        completeError("CANCELLED", "Recognition was cancelled.")
    }

    private fun completeError(code: String, message: String) {
        pendingRecognition?.error(code, message, null)
        pendingRecognition = null
        systemFallbackAttempted = false
    }

    private fun releaseRecognizer() {
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        usingSystemRecognizer = false
        completeError("CANCELLED", "Recognition was closed.")
    }

    override fun onDestroy() {
        localLlmController?.close()
        localLlmController = null
        channel?.setMethodCallHandler(null)
        channel = null
        releaseRecognizer()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Android, retained for the document picker bridge.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (localLlmController?.handleActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onReadyForSpeech(params: Bundle?) = Unit
    override fun onBeginningOfSpeech() = Unit
    override fun onRmsChanged(rmsdB: Float) = Unit
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech() = Unit
    override fun onPartialResults(partialResults: Bundle?) = Unit
    override fun onEvent(eventType: Int, params: Bundle?) = Unit
}
