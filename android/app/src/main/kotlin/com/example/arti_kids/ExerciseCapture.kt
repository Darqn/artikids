package com.example.arti_kids

import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.sqrt

internal class ExerciseCapture(private val activity: MainActivity) {
    var sink: EventChannel.EventSink? = null
    private var session: Session? = null
    private var sample: MediaPlayer? = null
    private var sampleReply: MethodChannel.Result? = null

    private inner class Session(val microphone: Boolean, val reply: MethodChannel.Result) {
        val worker = Executors.newSingleThreadExecutor()
        var provider: ProcessCameraProvider? = null
        var analyzer: ImageAnalysis? = null
        var model: FaceLandmarker? = null // Accessed on worker.
        var lastTimestamp = -1L
        var audio: AudioRecord? = null
        var bound = false
        @Volatile var closed = false

        fun event(data: Map<String, Any>) {
            activity.runOnUiThread {
                if (session === this) sink?.success(data)
            }
        }

        fun failure() {
            activity.runOnUiThread {
                if (session !== this) return@runOnUiThread
                if (bound) sink?.error("capture", "Захват прерван", null)
                close()
            }
        }

        fun close() {
            if (closed) return
            closed = true
            if (session === this) session = null
            analyzer?.clearAnalyzer()
            analyzer?.let { provider?.unbind(it) }
            audio?.let {
                try { it.stop() } catch (_: IllegalStateException) { }
            }
            worker.execute { model?.close() }
            worker.shutdown()
            if (!bound) reply.error("capture", "Не удалось открыть камеру или микрофон", null)
        }

        fun analyze(frame: ImageProxy) {
            try {
                if (closed) return
                val timestamp = max(lastTimestamp + 1, SystemClock.uptimeMillis())
                lastTimestamp = timestamp
                val bitmap = frame.toBitmap()
                val angle = frame.imageInfo.rotationDegrees
                val rotated = if (angle == 0) bitmap else Bitmap.createBitmap(
                    bitmap, 0, 0, bitmap.width, bitmap.height,
                    Matrix().apply { postRotate(angle.toFloat()) }, true
                )
                val input = BitmapImageBuilder(rotated).build()
                try {
                    val result = model!!.detectForVideo(input, timestamp)
                    val shapes = result.faceBlendshapes().orElse(emptyList())
                    val data = mutableMapOf<String, Any>(
                        "time" to timestamp, "faces" to result.faceLandmarks().size
                    )
                    if (shapes.size == 1) {
                        val scores = shapes.single().associate { it.categoryName() to it.score() }
                        data["open"] = (scores["jawOpen"] ?: 0f).toDouble()
                        data["smile"] = (((scores["mouthSmileLeft"] ?: 0f) +
                            (scores["mouthSmileRight"] ?: 0f)) / 2f).toDouble()
                        data["round"] = (scores["mouthPucker"] ?: 0f).toDouble()
                    }
                    event(data)
                } finally {
                    input.close()
                    if (rotated !== bitmap) rotated.recycle()
                    bitmap.recycle()
                }
            } catch (error: Exception) {
                Log.w("ArtiKidsCapture", "Frame analysis failed", error)
                failure()
            } finally {
                frame.close()
            }
        }

        @android.annotation.SuppressLint("MissingPermission")
        fun startAudio() {
            val rate = 16000
            val chunk = ShortArray(640)
            val minimum = AudioRecord.getMinBufferSize(
                rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
            )
            require(minimum > 0)
            val recorder = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, rate,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                max(minimum, chunk.size * 4))
            try {
                check(recorder.state == AudioRecord.STATE_INITIALIZED)
                recorder.startRecording()
                check(recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING)
            } catch (e: Exception) {
                recorder.release()
                throw e
            }
            audio = recorder
            Thread({
                try {
                    while (!closed) {
                        val count = recorder.read(chunk, 0, chunk.size)
                        if (count < 0) error("Audio input interrupted")
                        if (count == chunk.size) {
                            val time = SystemClock.uptimeMillis()
                            event(mapOf("time" to time, "voice" to voiced(chunk)))
                        }
                    }
                } catch (_: Exception) {
                    if (!closed) failure()
                } finally {
                    recorder.release()
                }
            }, "artikids-audio").start()
        }
    }

    fun start(microphone: Boolean, reply: MethodChannel.Result) {
        stop()
        val current = Session(microphone, reply)
        session = current
        val main = ContextCompat.getMainExecutor(activity)
        current.worker.execute {
            try {
                val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                    .setBaseOptions(BaseOptions.builder().setModelAssetPath("face_landmarker.task").build())
                    .setRunningMode(RunningMode.VIDEO)
                    .setNumFaces(2)
                    .setOutputFaceBlendshapes(true)
                    .build()
                current.model = FaceLandmarker.createFromOptions(activity, options)
                main.execute bind@{
                    if (session !== current) return@bind
                    val provider = ProcessCameraProvider.getInstance(activity)
                    provider.addListener({
                        if (session === current) {
                            try {
                                current.provider = provider.get()
                                val analysis = ImageAnalysis.Builder()
                                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                                    .build()
                                current.analyzer = analysis
                                analysis.setAnalyzer(current.worker, current::analyze)
                                current.provider!!.bindToLifecycle(activity,
                                    CameraSelector.DEFAULT_FRONT_CAMERA, analysis)
                                if (current.microphone) current.startAudio()
                                current.bound = true
                                reply.success(null)
                            } catch (error: Exception) {
                                Log.w("ArtiKidsCapture", "Could not bind camera or microphone", error)
                                current.close()
                            }
                        }
                    }, main)
                }
            } catch (error: Exception) {
                Log.w("ArtiKidsCapture", "Could not load face model", error)
                current.failure()
            } catch (error: LinkageError) {
                Log.w("ArtiKidsCapture", "Could not load vision runtime", error)
                current.failure()
            }
        }
    }

    fun stop() {
        endSample(false)
        session?.close()
    }

    fun playSample(reply: MethodChannel.Result) {
        stop()
        sampleReply = reply
        try {
            val player = MediaPlayer()
            sample = player
            activity.assets.openFd("vowel_a.wav").use {
                player.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
            player.setOnCompletionListener { endSample(true) }
            player.setOnErrorListener { _, _, _ -> endSample(false); true }
            player.prepare()
            player.start()
        } catch (_: Exception) {
            endSample(false)
        }
    }

    private fun endSample(played: Boolean) {
        sample?.release()
        sample = null
        val reply = sampleReply
        sampleReply = null
        reply?.success(played)
    }

    // Periodic energy indicates voicing. The clinician judges the vowel.
    private fun voiced(samples: ShortArray): Boolean {
        val mean = samples.average()
        val centered = DoubleArray(samples.size) { samples[it] - mean }
        if (centered.sumOf { it * it } / samples.size < 140.0 * 140.0) return false
        for (lag in 32..180 step 2) {
            var cross = 0.0
            var first = 0.0
            var second = 0.0
            for (i in lag until samples.size step 2) {
                val a = centered[i]
                val b = centered[i - lag]
                cross += a * b
                first += a * a
                second += b * b
            }
            if (cross > 0.65 * sqrt(first * second)) return true
        }
        return false
    }
}
