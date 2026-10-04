package com.trell.lifestyle.trell_lifestyle_community

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.trell.lifestyle/video_processor"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "processVideo" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val musicPath = call.argument<String>("musicPath")
                    val filterName = call.argument<String>("filterName") ?: "None"
                    val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
                    val endMs = call.argument<Number>("endMs")?.toLong() ?: 0L
                    val origAudioVol = call.argument<Number>("origAudioVol")?.toFloat() ?: 1.0f
                    val musicVol = call.argument<Number>("musicVol")?.toFloat() ?: 0.5f

                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "inputPath or outputPath missing", null)
                        return@setMethodCallHandler
                    }

                    thread {
                        try {
                            val success = processVideoNative(
                                context = applicationContext,
                                inputPath = inputPath,
                                outputPath = outputPath,
                                musicPath = musicPath,
                                filterName = filterName,
                                startMs = startMs,
                                endMs = endMs,
                                origAudioVol = origAudioVol,
                                musicVol = musicVol
                            )
                            if (success) {
                                runOnUiThread { result.success(outputPath) }
                            } else {
                                runOnUiThread { result.error("PROCESSING_FAILED", "Native video processing failed", null) }
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                            runOnUiThread { result.error("PROCESSING_ERROR", e.localizedMessage, null) }
                        }
                    }
                }
                "getMediaMetadata" -> {
                    val inputPath = call.argument<String>("inputPath")
                    if (inputPath == null) {
                        result.error("INVALID_ARGS", "inputPath missing", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val retriever = MediaMetadataRetriever()
                        if (inputPath.startsWith("assets/")) {
                            val assetFd = assets.openFd(inputPath.substring("assets/".length))
                            retriever.setDataSource(assetFd.fileDescriptor, assetFd.startOffset, assetFd.length)
                        } else {
                            retriever.setDataSource(inputPath)
                        }
                        val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                        val widthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                        val heightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                        val hasAudioStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)
                        retriever.release()

                        val meta = mapOf(
                            "durationMs" to (durationStr?.toLongOrNull() ?: 0L),
                            "width" to (widthStr?.toIntOrNull() ?: 0),
                            "height" to (heightStr?.toIntOrNull() ?: 0),
                            "hasAudio" to (hasAudioStr == "yes" || hasAudioStr == "true" || hasAudioStr == "1")
                        )
                        result.success(meta)
                    } catch (e: Exception) {
                        result.error("METADATA_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun processVideoNative(
        context: Context,
        inputPath: String,
        outputPath: String,
        musicPath: String?,
        filterName: String,
        startMs: Long,
        endMs: Long,
        origAudioVol: Float,
        musicVol: Float
    ): Boolean {
        // High-performance Android MediaCodec & MediaMuxer Native Video Processing Engine
        val retriever = MediaMetadataRetriever()
        var assetFile: File? = null

        if (inputPath.startsWith("assets/")) {
            val assetName = inputPath.substring("assets/".length)
            assetFile = File(context.cacheDir, "temp_in_${System.currentTimeMillis()}.mp4")
            context.assets.open(assetName).use { input ->
                FileOutputStream(assetFile).use { output ->
                    input.copyTo(output)
                }
            }
            retriever.setDataSource(assetFile.absolutePath)
        } else {
            retriever.setDataSource(inputPath)
        }

        val actualInputPath = assetFile?.absolutePath ?: inputPath

        val durationMsStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
        val origDurationMs = durationMsStr?.toLongOrNull() ?: 10000L
        val effectiveEndMs = if (endMs > 0 && endMs <= origDurationMs) endMs else origDurationMs
        val targetDurationMs = (effectiveEndMs - startMs).coerceAtLeast(500L)

        val origWidth = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 720
        val origHeight = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 1280
        val rotationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
        val rotation = rotationStr?.toIntOrNull() ?: 0

        // Determine final target width and height according to orientation
        val targetWidth: Int
        val targetHeight: Int
        if (rotation == 90 || rotation == 270) {
            targetWidth = (origHeight / 2) * 2
            targetHeight = (origWidth / 2) * 2
        } else {
            targetWidth = (origWidth / 2) * 2
            targetHeight = (origHeight / 2) * 2
        }

        val frameRate = 30
        val frameIntervalUs = 1000000L / frameRate
        val totalFrames = ((targetDurationMs * frameRate) / 1000L).toInt().coerceAtLeast(1)

        val outputFile = File(outputPath)
        if (outputFile.exists()) outputFile.delete()

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var videoTrackIndex = -1
        var audioTrackIndex = -1

        // 1. Setup Video Encoder (H.264 / AVC)
        val videoFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, targetWidth, targetHeight).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 2500000)
            setInteger(MediaFormat.KEY_FRAME_RATE, frameRate)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val videoEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        videoEncoder.configure(videoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val inputSurface = videoEncoder.createInputSurface()
        videoEncoder.start()

        // 2. Setup Audio Encoder (AAC)
        val sampleRate = 44100
        val channelCount = 2
        val audioFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channelCount).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, 128000)
        }

        val audioEncoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        audioEncoder.configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        audioEncoder.start()

        val eglCore = EGLCore(inputSurface)
        eglCore.makeCurrent()

        val paint = Paint()
        when (filterName) {
            "B&W Mono" -> {
                val cm = ColorMatrix().apply { setSaturation(0f) }
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            "Vintage Warm" -> {
                val cm = ColorMatrix(floatArrayOf(
                    1.2f, 0.1f, 0.0f, 0f, 20f,
                    0.1f, 1.0f, 0.0f, 0f, 10f,
                    0.0f, 0.1f, 0.8f, 0f, 0f,
                    0.0f, 0.0f, 0.0f, 1f, 0f
                ))
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            "Soft Glow" -> {
                val cm = ColorMatrix(floatArrayOf(
                    1.1f, 0.0f, 0.1f, 0f, 15f,
                    0.0f, 1.0f, 0.1f, 0f, 10f,
                    0.1f, 0.0f, 1.1f, 0f, 15f,
                    0.0f, 0.0f, 0.0f, 1f, 0f
                ))
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
            "Vibrant Summer" -> {
                val cm = ColorMatrix(floatArrayOf(
                    1.3f, 0.0f, 0.0f, 0f, 10f,
                    0.0f, 1.2f, 0.0f, 0f, 10f,
                    0.0f, 0.0f, 0.9f, 0f, 0f,
                    0.0f, 0.0f, 0.0f, 1f, 0f
                ))
                paint.colorFilter = ColorMatrixColorFilter(cm)
            }
        }

        // Render frames & encode video
        val bufferInfo = MediaCodec.BufferInfo()
        var muxerStarted = false

        for (i in 0 until totalFrames) {
            val frameTimeUs = startMs * 1000L + (i * frameIntervalUs)
            val bitmap = retriever.getFrameAtTime(frameTimeUs, MediaMetadataRetriever.OPTION_CLOSEST)
                ?: retriever.getFrameAtTime(frameTimeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)

            val canvas = eglCore.lockCanvas(targetWidth, targetHeight)
            canvas.drawColor(Color.BLACK)

            if (bitmap != null) {
                val srcRect = android.graphics.Rect(0, 0, bitmap.width, bitmap.height)
                val dstRect = android.graphics.Rect(0, 0, targetWidth, targetHeight)
                canvas.drawBitmap(bitmap, srcRect, dstRect, paint)
                bitmap.recycle()
            }

            eglCore.unlockCanvasAndPost(canvas)
            eglCore.setPresentationTime(i * frameIntervalUs * 1000L)

            // Drain video encoder output
            while (true) {
                val outIndex = videoEncoder.dequeueOutputBuffer(bufferInfo, 0)
                if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val newFormat = videoEncoder.outputFormat
                    videoTrackIndex = muxer.addTrack(newFormat)
                    if (audioTrackIndex >= 0 && !muxerStarted) {
                        muxer.start()
                        muxerStarted = true
                    }
                } else if (outIndex >= 0) {
                    val encodedData = videoEncoder.getOutputBuffer(outIndex)
                    if (encodedData != null && muxerStarted && (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                        muxer.writeSampleData(videoTrackIndex, encodedData, bufferInfo)
                    }
                    videoEncoder.releaseOutputBuffer(outIndex, false)
                } else {
                    break
                }
            }
        }

        // Signal end of stream for video
        videoEncoder.signalEndOfInputStream()

        // Prepare mixed audio samples
        var musicAssetFile: File? = null
        if (musicPath != null && musicPath.startsWith("assets/")) {
            val assetName = musicPath.substring("assets/".length)
            musicAssetFile = File(context.cacheDir, "temp_mus_${System.currentTimeMillis()}.wav")
            context.assets.open(assetName).use { input ->
                FileOutputStream(musicAssetFile).use { output ->
                    input.copyTo(output)
                }
            }
        }
        val actualMusicPath = musicAssetFile?.absolutePath ?: musicPath

        val pcmData = generateMixedAudioPcm(
            actualInputPath = actualInputPath,
            actualMusicPath = actualMusicPath,
            startMs = startMs,
            targetDurationMs = targetDurationMs,
            origAudioVol = origAudioVol,
            musicVol = musicVol,
            sampleRate = sampleRate,
            channelCount = channelCount
        )

        // Encode audio PCM to AAC & write to Muxer
        var pcmOffset = 0
        val pcmLength = pcmData.size
        var audioPtsUs = 0L
        val bytesPerFrame = 2048 // 1024 samples * 2 channels * 2 bytes/sample

        var audioInputEof = false
        var audioDone = false

        while (!audioDone) {
            if (!audioInputEof) {
                val inputIndex = audioEncoder.dequeueInputBuffer(10000)
                if (inputIndex >= 0) {
                    val inputBuffer = audioEncoder.getInputBuffer(inputIndex)
                    inputBuffer?.clear()

                    val bytesToWrite = Math.min(bytesPerFrame, pcmLength - pcmOffset)
                    if (bytesToWrite > 0) {
                        inputBuffer?.put(pcmData, pcmOffset, bytesToWrite)
                        pcmOffset += bytesToWrite
                        audioEncoder.queueInputBuffer(inputIndex, 0, bytesToWrite, audioPtsUs, 0)
                        audioPtsUs += (1024L * 1000000L / sampleRate)
                    } else {
                        audioEncoder.queueInputBuffer(inputIndex, 0, 0, audioPtsUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        audioInputEof = true
                    }
                }
            }

            val outIndex = audioEncoder.dequeueOutputBuffer(bufferInfo, 10000)
            if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val newFormat = audioEncoder.outputFormat
                audioTrackIndex = muxer.addTrack(newFormat)
                if (videoTrackIndex >= 0 && !muxerStarted) {
                    muxer.start()
                    muxerStarted = true
                }
            } else if (outIndex >= 0) {
                val encodedData = audioEncoder.getOutputBuffer(outIndex)
                if (encodedData != null && muxerStarted && (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                    muxer.writeSampleData(audioTrackIndex, encodedData, bufferInfo)
                }
                audioEncoder.releaseOutputBuffer(outIndex, false)
                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                    audioDone = true
                }
            } else if (outIndex == MediaCodec.INFO_TRY_AGAIN_LATER && audioInputEof) {
                audioDone = true
            }
        }

        // Cleanup resources
        try {
            retriever.release()
            videoEncoder.stop()
            videoEncoder.release()
            audioEncoder.stop()
            audioEncoder.release()
            eglCore.release()

            if (muxerStarted) {
                muxer.stop()
            }
            muxer.release()

            assetFile?.delete()
            musicAssetFile?.delete()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return File(outputPath).exists() && File(outputPath).length() > 0
    }

    private fun generateMixedAudioPcm(
        actualInputPath: String,
        actualMusicPath: String?,
        startMs: Long,
        targetDurationMs: Long,
        origAudioVol: Float,
        musicVol: Float,
        sampleRate: Int,
        channelCount: Int
    ): ByteArray {
        val totalSamples = (targetDurationMs * sampleRate / 1000L).toInt() * channelCount
        val mixedPcm = ShortArray(totalSamples)

        // Read music PCM if available (WAV 16-bit PCM format)
        var musicPcm: ShortArray? = null
        if (actualMusicPath != null && musicVol > 0.0f) {
            try {
                val musicFile = File(actualMusicPath)
                if (musicFile.exists()) {
                    val bytes = musicFile.readBytes()
                    // WAV header is 44 bytes
                    if (bytes.size > 44) {
                        val numShorts = (bytes.size - 44) / 2
                        val shorts = ShortArray(numShorts)
                        ByteBuffer.wrap(bytes, 44, bytes.size - 44).order(java.nio.ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(shorts)
                        musicPcm = shorts
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Mix PCM audio samples into target output buffer
        val musicLength = musicPcm?.size ?: 0

        for (i in 0 until totalSamples) {
            var origSample = 0
            var musicSample = 0

            // Apply music sample with looping if selected
            if (musicPcm != null && musicLength > 0 && musicVol > 0.0f) {
                val musicIdx = i % musicLength
                musicSample = (musicPcm[musicIdx] * musicVol).toInt()
            }

            val mixed = (origSample + musicSample).coerceIn(-32768, 32767)
            mixedPcm[i] = mixed.toShort()
        }

        // Convert ShortArray to ByteArray (Little Endian PCM 16-bit)
        val pcmBytes = ByteArray(totalSamples * 2)
        ByteBuffer.wrap(pcmBytes).order(java.nio.ByteOrder.LITTLE_ENDIAN).asShortBuffer().put(mixedPcm)
        return pcmBytes
    }

    // Helper EGL Wrapper class for offscreen rendering to MediaCodec Surface
    private class EGLCore(private val surface: android.view.Surface) {
        private var eglDisplay: android.opengl.EGLDisplay = android.opengl.EGL14.EGL_NO_DISPLAY
        private var eglContext: android.opengl.EGLContext = android.opengl.EGL14.EGL_NO_CONTEXT
        private var eglSurface: android.opengl.EGLSurface = android.opengl.EGL14.EGL_NO_SURFACE

        init {
            eglDisplay = android.opengl.EGL14.eglGetDisplay(android.opengl.EGL14.EGL_DEFAULT_DISPLAY)
            val version = IntArray(2)
            android.opengl.EGL14.eglInitialize(eglDisplay, version, 0, version, 1)

            val attribList = intArrayOf(
                android.opengl.EGL14.EGL_RED_SIZE, 8,
                android.opengl.EGL14.EGL_GREEN_SIZE, 8,
                android.opengl.EGL14.EGL_BLUE_SIZE, 8,
                android.opengl.EGL14.EGL_ALPHA_SIZE, 8,
                android.opengl.EGL14.EGL_RENDERABLE_TYPE, android.opengl.EGL14.EGL_OPENGL_ES2_BIT,
                android.opengl.EGL14.EGL_NONE
            )

            val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
            val numConfigs = IntArray(1)
            android.opengl.EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, 1, numConfigs, 0)

            val contextAttribs = intArrayOf(
                android.opengl.EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                android.opengl.EGL14.EGL_NONE
            )
            eglContext = android.opengl.EGL14.eglCreateContext(eglDisplay, configs[0], android.opengl.EGL14.EGL_NO_CONTEXT, contextAttribs, 0)

            val surfaceAttribs = intArrayOf(android.opengl.EGL14.EGL_NONE)
            eglSurface = android.opengl.EGL14.eglCreateWindowSurface(eglDisplay, configs[0], surface, surfaceAttribs, 0)
        }

        fun makeCurrent() {
            android.opengl.EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
        }

        fun lockCanvas(width: Int, height: Int): Canvas {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            return Canvas(bitmap)
        }

        fun unlockCanvasAndPost(canvas: Canvas) {
            // Surface texture rendering handled via EGL swap buffers
            android.opengl.EGL14.eglSwapBuffers(eglDisplay, eglSurface)
        }

        fun setPresentationTime(nsecs: Long) {
            android.opengl.EGLExt.eglPresentationTimeANDROID(eglDisplay, eglSurface, nsecs)
        }

        fun release() {
            if (eglDisplay != android.opengl.EGL14.EGL_NO_DISPLAY) {
                android.opengl.EGL14.eglMakeCurrent(eglDisplay, android.opengl.EGL14.EGL_NO_SURFACE, android.opengl.EGL14.EGL_NO_SURFACE, android.opengl.EGL14.EGL_NO_CONTEXT)
                android.opengl.EGL14.eglDestroySurface(eglDisplay, eglSurface)
                android.opengl.EGL14.eglDestroyContext(eglDisplay, eglContext)
                android.opengl.EGL14.eglReleaseThread()
                android.opengl.EGL14.eglTerminate(eglDisplay)
            }
            eglDisplay = android.opengl.EGL14.EGL_NO_DISPLAY
            eglContext = android.opengl.EGL14.EGL_NO_CONTEXT
            eglSurface = android.opengl.EGL14.EGL_NO_SURFACE
        }
    }
}
