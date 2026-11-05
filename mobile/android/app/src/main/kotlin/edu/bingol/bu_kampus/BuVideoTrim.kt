package edu.bingol.bu_kampus

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * Videodan bir zaman araligini YENIDEN KODLAMADAN keser (kanal `bu_kampus/video_trim`, Dart:
 * lib/core/platform/video_trim.dart). `MediaExtractor` ornekleri okur, `MediaMuxer` yeni mp4'e yazar; ek bagimlilik yok.
 *
 * `trim {path, startMs, endMs, maxMs}` -> yeni dosyanin yolu (cache/video_trim/). Baslangic EN YAKIN anahtar kareye oturur
 * (kodlama bozulmasin), bu yuzden sure birkac yuz ms oynayabilir; `maxMs` > 0 ise cikti baslangic + maxMs'i asmaz.
 * Hata: `FAILED` (bozuk/desteklenmeyen kodek, okuma-yazma hatasi). Isi arka is parcaciginda yapilir.
 */
object BuVideoTrim {
    private const val CHANNEL = "bu_kampus/video_trim"
    private const val DIR = "video_trim"
    private const val STALE_MS = 6 * 60 * 60 * 1000L
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger, context: Context) {
        val app = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "trim" -> {
                    val path = call.argument<String>("path")
                    val startMs = call.argument<Number>("startMs")?.toLong()
                    val endMs = call.argument<Number>("endMs")?.toLong()
                    val maxMs = call.argument<Number>("maxMs")?.toLong() ?: 0L
                    if (path.isNullOrEmpty() || startMs == null || endMs == null || startMs < 0 || endMs <= startMs) {
                        result.error("BAD_ARGS", "path/startMs/endMs", null)
                        return@setMethodCallHandler
                    }
                    worker.execute {
                        val out = try {
                            trim(app, path, startMs, endMs, maxMs)
                        } catch (_: Throwable) {
                            null
                        }
                        main.post {
                            if (out != null) result.success(out) else result.error("FAILED", "trim", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun outDir(context: Context): File {
        val dir = File(context.cacheDir, DIR)
        dir.mkdirs()
        // Eski kesim dosyalarini temizle (cache sismesin).
        val now = System.currentTimeMillis()
        dir.listFiles()?.forEach { if (now - it.lastModified() > STALE_MS) it.delete() }
        return dir
    }

    private fun rotationOf(path: String): Int {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        } catch (_: Throwable) {
            0
        } finally {
            try { r.release() } catch (_: Throwable) {}
        }
    }

    private fun trim(context: Context, path: String, startMs: Long, endMs: Long, maxMs: Long): String? {
        val out = File(outDir(context), "trim_${System.nanoTime()}.mp4")
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var started = false
        var ok = false
        try {
            extractor.setDataSource(path)
            muxer = MediaMuxer(out.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val map = HashMap<Int, Int>() // kaynak iz -> cikti izi
            var hasVideo = false
            var hasAudio = false
            var bufSize = 4 * 1024 * 1024
            for (i in 0 until extractor.trackCount) {
                val fmt = extractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                val take = (mime.startsWith("video/") && !hasVideo) || (mime.startsWith("audio/") && !hasAudio)
                if (!take) continue
                if (mime.startsWith("video/")) hasVideo = true else hasAudio = true
                extractor.selectTrack(i)
                map[i] = muxer.addTrack(fmt)
                if (fmt.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    bufSize = maxOf(bufSize, fmt.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE))
                }
            }
            if (!hasVideo) return null
            muxer.setOrientationHint(rotationOf(path))
            muxer.start()
            started = true

            extractor.seekTo(startMs * 1000L, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            val buf = ByteBuffer.allocate(bufSize)
            val info = MediaCodec.BufferInfo()
            var baseUs = -1L
            val endUs = endMs * 1000L
            var capUs = Long.MAX_VALUE
            var wrote = 0
            while (true) {
                val track = extractor.sampleTrackIndex
                if (track < 0) break
                val t = extractor.sampleTime
                if (t < 0) break
                val dst = map[track]
                if (dst == null) {
                    extractor.advance()
                    continue
                }
                if (baseUs < 0) {
                    baseUs = t
                    if (maxMs > 0) capUs = baseUs + maxMs * 1000L
                }
                if (t > endUs || t > capUs) break
                buf.clear()
                val size = extractor.readSampleData(buf, 0)
                if (size < 0) break
                info.set(0, size, maxOf(0L, t - baseUs), if ((extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                muxer.writeSampleData(dst, buf, info)
                wrote++
                extractor.advance()
            }
            ok = wrote > 0
        } finally {
            try { extractor.release() } catch (_: Throwable) {}
            try {
                if (started) muxer?.stop()
            } catch (_: Throwable) {
                ok = false
            }
            try { muxer?.release() } catch (_: Throwable) {}
            if (!ok) out.delete()
        }
        return if (ok && out.length() > 0) out.absolutePath else null
    }
}
