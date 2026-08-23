package com.smartscheduler.smart_scheduler

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import java.io.FileOutputStream

class NativeOfflineOcrPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "com.smartscheduler/offline_ocr")
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    private var cancellation = CancellationTokenSource()

    init {
        channel.setMethodCallHandler(this)
        cleanupStaleTempFiles()
    }

    private fun cleanupStaleTempFiles() {
        activity.cacheDir.listFiles()
            ?.filter { it.name.startsWith("offline-ocr-") }
            ?.forEach { file ->
                if (file.lastModified() < System.currentTimeMillis() - 60 * 60 * 1000) {
                    file.delete()
                }
            }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancel") {
            cancellation.cancel()
            result.success(null)
            return
        }
        if (call.method != "recognize") {
            result.notImplemented()
            return
        }
        val bytes = call.argument<ByteArray>("bytes")
        val sourceType = call.argument<String>("sourceType") ?: "image"
        if (bytes == null || bytes.isEmpty()) {
            result.error("INVALID_INPUT", "OCR input is empty", null)
            return
        }
        cancellation.cancel()
        cancellation = CancellationTokenSource()
        val pageIndices = call.argument<List<Int>>("pageIndices")?.toSet()
        if (sourceType == "pdf") {
            recognizePdf(bytes, pageIndices, result)
        } else {
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            if (bitmap == null) {
                result.error("INVALID_IMAGE", "The image could not be decoded", null)
                return
            }
            recognizeBitmap(bitmap, 0, result)
        }
    }

    private fun recognizePdf(bytes: ByteArray, pageIndices: Set<Int>?, result: MethodChannel.Result) {
        val file = File.createTempFile("offline-ocr-", ".pdf", activity.cacheDir)
        try {
            FileOutputStream(file).use { it.write(bytes) }
            val descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            val renderer = PdfRenderer(descriptor)
            val pages = mutableListOf<Map<String, Any?>>()
            processPdfPage(renderer, 0, pageIndices, pages) {
                renderer.close()
                descriptor.close()
                file.delete()
                result.success(response(pages, "Android ML Kit bundled text recognition"))
            }
        } catch (error: Exception) {
            file.delete()
            result.error("PDF_RENDER", error.message, null)
        }
    }

    private fun processPdfPage(
        renderer: PdfRenderer,
        index: Int,
        pageIndices: Set<Int>?,
        blocks: MutableList<Map<String, Any?>>,
        done: () -> Unit,
    ) {
        if (cancellation.token.isCancellationRequested) {
            done()
            return
        }
        if (index >= renderer.pageCount) {
            done()
            return
        }
        if (pageIndices != null && !pageIndices.contains(index)) {
            processPdfPage(renderer, index + 1, pageIndices, blocks, done)
            return
        }
        val page = renderer.openPage(index)
        val bitmap = Bitmap.createBitmap(
            page.width * 2,
            page.height * 2,
            Bitmap.Config.ARGB_8888,
        )
        bitmap.eraseColor(android.graphics.Color.WHITE)
        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
        page.close()
        recognizeBitmap(bitmap, index, object : MethodChannel.Result {
            override fun success(value: Any?) {
                if (value is Map<*, *>) {
                    val pageBlocks = value["blocks"] as? List<*>
                    pageBlocks?.filterIsInstance<Map<String, Any?>>()?.let(blocks::addAll)
                }
                processPdfPage(renderer, index + 1, pageIndices, blocks, done)
            }
            override fun error(code: String, message: String?, details: Any?) {
                processPdfPage(renderer, index + 1, pageIndices, blocks, done)
            }
            override fun notImplemented() {
                processPdfPage(renderer, index + 1, pageIndices, blocks, done)
            }
        })
    }

    private fun recognizeBitmap(
        bitmap: Bitmap,
        pageIndex: Int,
        result: MethodChannel.Result,
    ) {
        val image = InputImage.fromBitmap(bitmap, 0)
        recognizer.process(image)
            .addOnSuccessListener { text ->
                val blocks = text.textBlocks
                    .flatMap { block -> block.lines }
                    .mapIndexed { index, line -> lineMap(line, pageIndex, index, bitmap) }
                result.success(response(blocks, "Android ML Kit bundled text recognition"))
                bitmap.recycle()
            }
            .addOnFailureListener { error ->
                result.error("OCR_FAILED", error.message, null)
                bitmap.recycle()
            }
    }

    private fun lineMap(
        line: Text.Line,
        pageIndex: Int,
        order: Int,
        bitmap: Bitmap,
    ): Map<String, Any?> {
        val box = line.boundingBox
        val left = (box?.left ?: 0).toDouble() / bitmap.width
        val top = (box?.top ?: 0).toDouble() / bitmap.height
        val width = (box?.width() ?: 0).toDouble() / bitmap.width
        val height = (box?.height() ?: 0).toDouble() / bitmap.height
        return mapOf(
            "text" to line.text,
            "pageIndex" to pageIndex,
            "order" to order,
            "confidence" to null,
            "orientation" to 0,
            "boundingBox" to mapOf(
                "left" to left,
                "top" to top,
                "width" to width,
                "height" to height,
            ),
        )
    }

    private fun response(
        blocks: List<Map<String, Any?>>,
        engine: String,
    ): Map<String, Any?> = mapOf(
        "engine" to engine,
        "offline" to true,
        "orientation" to 0,
        "confidence" to 0.0,
        "confidenceSource" to "unavailable: ML Kit bundled text recognition exposes no confidence score",
        "blocks" to blocks,
        "warnings" to buildList {
            add("Android ML Kit does not expose per-line recognition confidence.")
            if (blocks.isEmpty()) add("No text was recognized")
        },
    )

    fun dispose() {
        cancellation.cancel()
        recognizer.close()
        channel.setMethodCallHandler(null)
    }
}