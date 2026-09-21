package bo.edu.software1.software1_mobile

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ResponseFormat
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.ai.edge.litertlm.ThinkingConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class LocalLlmController(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val CHANNEL = "bo.edu.software1/local_llm"
        private const val MODEL_REQUEST = 7201
        private const val MODEL_FILE_NAME = "assistant.litertlm"
        private const val TAG = "Software1LocalAI"
        private const val MIN_FREE_SPACE_BYTES = 100L * 1024L * 1024L

        private val INTENT_SCHEMA =
            """
            {
              "type": "object",
              "properties": {
                "operation": {
                  "type": "string",
                  "enum": [
                    "CREATE_ENTITY", "GET_ENTITY", "LIST_ENTITIES",
                    "UPDATE_ENTITY", "DELETE_ENTITY", "SEARCH_ENTITY"
                  ]
                },
                "entity": {"type": "string"},
                "identifier": {
                  "anyOf": [
                    {"type": "string"}, {"type": "number"}, {"type": "null"}
                  ]
                },
                "parameters": {
                  "type": "object",
                  "additionalProperties": {
                    "anyOf": [
                      {"type": "string"}, {"type": "number"},
                      {"type": "boolean"}, {"type": "null"},
                      {
                        "type": "array",
                        "items": {
                          "anyOf": [
                            {"type": "string"}, {"type": "number"},
                            {"type": "boolean"}, {"type": "null"}
                          ]
                        }
                      }
                    ]
                  }
                }
              },
              "required": ["operation", "entity", "parameters"],
              "additionalProperties": false
            }
            """.trimIndent()

        private val SYSTEM_INSTRUCTION =
            """
            You are an offline intent parser for a CRUD application.
            Convert the user's Spanish instruction into exactly one JSON object.
            Use only the operations and entities described in the supplied domain context.
            Never answer conversationally, never add Markdown, and never invent fields.
            For CREATE_ENTITY and UPDATE_ENTITY include every required writable field.
            Omit optional fields the user did not specify. Do not invent zero values.
            For numeric fields use JSON numbers, not quoted strings.
            For GET_ENTITY, UPDATE_ENTITY and DELETE_ENTITY include identifier.
            For SEARCH_ENTITY include one or more field filters in parameters.
            The first output character must be { and the last must be }.
            Example for "lista los clientes":
            {"operation":"LIST_ENTITIES","entity":"Cliente","parameters":{}}
            """.trimIndent()
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val modelDirectory = File(activity.filesDir, "models")
    private val modelFile = File(modelDirectory, MODEL_FILE_NAME)
    private val cacheDirectory = File(activity.cacheDir, "litert-lm")
    private var pendingImport: MethodChannel.Result? = null
    private var engine: Engine? = null

    @Volatile
    private var modelLoaded = false

    init {
        channel.setMethodCallHandler(::handleCall)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(statusPayload())
            "importModel" -> openModelPicker(result)
            "loadModel" -> runModelTask(result) { loadModel(); null }
            "generate" -> generate(call, result)
            "dispose" -> runModelTask(result) { releaseEngine(); null }
            else -> result.notImplemented()
        }
    }

    private fun openModelPicker(result: MethodChannel.Result) {
        if (pendingImport != null) {
            result.error("BUSY", "A model import is already active.", null)
            return
        }
        pendingImport = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/octet-stream", "*/*"))
        }
        try {
            activity.startActivityForResult(intent, MODEL_REQUEST)
        } catch (_: RuntimeException) {
            pendingImport = null
            result.error("IMPORT_FAILED", "Could not open the model picker.", null)
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != MODEL_REQUEST) return false
        val result = pendingImport ?: return true
        pendingImport = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.error("IMPORT_CANCELLED", "No local model was selected.", null)
            return true
        }
        val displayName = queryDisplayName(uri)
        if (displayName == null || !displayName.endsWith(".litertlm", ignoreCase = true)) {
            result.error("INVALID_MODEL_FILE", "The selected file is not a .litertlm model.", null)
            return true
        }
        runModelTask(result) {
            importModel(uri)
            statusPayload()
        }
        return true
    }

    private fun importModel(uri: Uri) {
        val declaredSize = querySize(uri)
        modelDirectory.mkdirs()
        if (declaredSize != null && modelDirectory.usableSpace < declaredSize + MIN_FREE_SPACE_BYTES) {
            throw ModelOperationException("NO_SPACE", "Not enough storage for the local model.")
        }
        releaseEngine()
        val temporaryFile = File(modelDirectory, "$MODEL_FILE_NAME.importing")
        try {
            activity.contentResolver.openInputStream(uri)?.use { input ->
                temporaryFile.outputStream().buffered().use { output -> input.copyTo(output) }
            } ?: throw IOException("The selected model could not be opened.")
            if (temporaryFile.length() == 0L) {
                throw ModelOperationException("INVALID_MODEL_FILE", "The selected model is empty.")
            }
            activateImportedModel(temporaryFile)
        } catch (error: ModelOperationException) {
            temporaryFile.delete()
            throw error
        } catch (_: IOException) {
            temporaryFile.delete()
            throw ModelOperationException("IMPORT_FAILED", "Could not copy the local model.")
        } catch (_: SecurityException) {
            temporaryFile.delete()
            throw ModelOperationException("IMPORT_FAILED", "Could not copy the local model.")
        }
    }

    private fun activateImportedModel(temporaryFile: File) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Files.move(
                temporaryFile.toPath(),
                modelFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
            return
        }

        val backupFile = File(modelDirectory, "$MODEL_FILE_NAME.backup")
        backupFile.delete()
        val hadPreviousModel = modelFile.exists()
        if (hadPreviousModel && !modelFile.renameTo(backupFile)) {
            throw IOException("The previous model could not be preserved.")
        }
        if (!temporaryFile.renameTo(modelFile)) {
            if (hadPreviousModel) backupFile.renameTo(modelFile)
            throw IOException("The imported model could not be activated.")
        }
        backupFile.delete()
    }

    private fun loadModel() {
        if (modelLoaded) return
        if (!modelFile.isFile || modelFile.length() == 0L) {
            throw ModelOperationException("MODEL_NOT_INSTALLED", "No local model is installed.")
        }
        try {
            modelDirectory.mkdirs()
            cacheDirectory.mkdirs()
            releaseEngine()
            val newEngine = Engine(
                EngineConfig(
                    modelPath = modelFile.absolutePath,
                    backend = Backend.CPU(),
                    maxNumTokens = 4096,
                    cacheDir = cacheDirectory.absolutePath,
                ),
            )
            newEngine.initialize()
            engine = newEngine
            modelLoaded = true
        } catch (_: Throwable) {
            releaseEngine()
            throw ModelOperationException("MODEL_LOAD_FAILED", "LiteRT-LM could not load the model.")
        }
    }

    private fun generate(call: MethodCall, result: MethodChannel.Result) {
        val instruction = call.argument<String>("instruction")?.trim().orEmpty()
        val domainContext = call.argument<String>("domainContext")?.trim().orEmpty()
        if (instruction.isEmpty() || domainContext.isEmpty()) {
            result.error("INVALID_ARGUMENTS", "Instruction and domain context are required.", null)
            return
        }
        runModelTask(result) {
            val currentEngine = engine
                ?.takeIf { modelLoaded }
                ?: throw ModelOperationException("MODEL_NOT_LOADED", "The local model is not loaded.")
            try {
                val config = ConversationConfig(
                    systemInstruction = Contents.of(SYSTEM_INSTRUCTION),
                    samplerConfig = SamplerConfig(
                        topK = 1,
                        topP = 1.0,
                        temperature = 0.0,
                        seed = 1,
                    ),
                    maxOutputToken = 256,
                    thinkingConfig = ThinkingConfig(
                        enableThinking = false,
                        thinkingTokenBudget = 0,
                    ),
                    enableResponseFormat = true,
                )
                currentEngine.createConversation(config).use { conversation ->
                    val prompt =
                        """
                        DOMAIN CONTEXT:
                        $domainContext

                        USER INSTRUCTION:
                        $instruction
                        """.trimIndent()
                    val message = conversation.sendMessage(
                        prompt,
                        responseFormat = ResponseFormat.json(INTENT_SCHEMA),
                    )
                    val output = message.contents.contents
                        .filterIsInstance<Content.Text>()
                        .joinToString(separator = "") { it.text }
                        .trim()
                    if (output.isEmpty()) {
                        throw ModelOperationException("INFERENCE_FAILED", "The model returned no text.")
                    }
                    if (
                        activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
                    ) {
                        Log.d(TAG, "Generated structured output: ${output.take(2048)}")
                    }
                    output
                }
            } catch (error: ModelOperationException) {
                throw error
            } catch (_: Throwable) {
                throw ModelOperationException("INFERENCE_FAILED", "LiteRT-LM inference failed.")
            }
        }
    }

    private fun releaseEngine() {
        try {
            engine?.close()
        } finally {
            engine = null
            modelLoaded = false
        }
    }

    private fun statusPayload(): Map<String, Any?> = mapOf(
        "installed" to (modelFile.isFile && modelFile.length() > 0L),
        "loaded" to modelLoaded,
        "fileName" to MODEL_FILE_NAME.takeIf { modelFile.isFile },
        "sizeBytes" to modelFile.length().takeIf { modelFile.isFile },
    )

    private fun queryDisplayName(uri: Uri): String? = queryColumn(uri, OpenableColumns.DISPLAY_NAME) {
        getString(it)
    }

    private fun querySize(uri: Uri): Long? = queryColumn(uri, OpenableColumns.SIZE) {
        if (isNull(it)) null else getLong(it)
    }

    private fun <T> queryColumn(uri: Uri, column: String, value: Cursor.(Int) -> T?): T? =
        try {
            activity.contentResolver.query(uri, arrayOf(column), null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(column)
                if (index >= 0 && cursor.moveToFirst()) cursor.value(index) else null
            }
        } catch (_: RuntimeException) {
            null
        }

    private fun runModelTask(
        result: MethodChannel.Result,
        task: () -> Any?,
    ) {
        executor.execute {
            try {
                val value = task()
                activity.runOnUiThread { result.success(value) }
            } catch (error: ModelOperationException) {
                activity.runOnUiThread { result.error(error.code, error.message, null) }
            } catch (_: Throwable) {
                activity.runOnUiThread {
                    result.error("INFERENCE_FAILED", "The local model operation failed.", null)
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        pendingImport?.error("IMPORT_CANCELLED", "The activity was closed.", null)
        pendingImport = null
        executor.execute {
            releaseEngine()
            executor.shutdown()
        }
    }
}

private class ModelOperationException(
    val code: String,
    override val message: String,
) : RuntimeException(message)
