package com.example.video_compress

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

class Utility(private val channelName: String) {

    fun isLandscapeImage(orientation: Int) = orientation != 90 && orientation != 270

    fun deleteFile(file: File) {
        if (file.exists()) {
            file.delete()
        }
    }

    fun timeStrToTimestamp(time: String): Long {
        val timeArr = time.split(":")
        val hour = Integer.parseInt(timeArr[0])
        val min = Integer.parseInt(timeArr[1])
        val secArr = timeArr[2].split(".")
        val sec = Integer.parseInt(secArr[0])
        val mSec = Integer.parseInt(secArr[1])

        val timeStamp = (hour * 3600 + min * 60 + sec) * 1000 + mSec
        return timeStamp.toLong()
    }

    fun getMediaInfoJson(context: Context, path: String): JSONObject {
        val file = File(path)
        val retriever = MediaMetadataRetriever()

        var durationStr: String? = null
        var title = ""
        var author = ""
        var widthStr: String? = null
        var heightStr: String? = null
        var orientation: String? = null
        try {
            retriever.setDataSource(context, Uri.fromFile(file))
            durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""
            author = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_AUTHOR) ?: ""
            widthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            heightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            orientation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
        } finally {
            // Ayrinti okunamasa da (bozuk dosya) yerel kaynak sizmasin.
            try {
                retriever.release()
            } catch (ignored: RuntimeException) {
            }
        }
        // Eksik/bozuk metadata (sesli dosya, yarim cikti) NumberFormatException ile cokertmesin: 0 olarak raporlanir.
        val duration = durationStr?.toLongOrNull() ?: 0L
        var width = widthStr?.toLongOrNull() ?: 0L
        var height = heightStr?.toLongOrNull() ?: 0L
        val filesize = file.length()
        val ori = orientation?.toIntOrNull()
        if (ori != null && isLandscapeImage(ori)) {
            val tmp = width
            width = height
            height = tmp
        }

        val json = JSONObject()

        json.put("path", path)
        json.put("title", title)
        json.put("author", author)
        json.put("width", width)
        json.put("height", height)
        json.put("duration", duration)
        json.put("filesize", filesize)
        if (ori != null) {
            json.put("orientation", ori)
        }

        return json
    }

    /**
     * Videodan kare okur (en uzun kenar en cok 512 px). Bozuk dosya, kare yok ya da bellek yetmezligi (yuksek
     * cozunurluklu video) durumunda null doner; YANIT VERMEZ: cagiran tek kez yanitlar. (Eskiden hata yolunda
     * hem result.error hem result.success cagriliyor ve null bitmap `!!` ile NullPointerException veriyordu;
     * OutOfMemoryError ise Error oldugundan kanal tarafindan yakalanmayip sureci oldururdu.)
     */
    fun getBitmap(path: String, position: Long): Bitmap? {
        var bitmap: Bitmap? = null
        val retriever = MediaMetadataRetriever()

        try {
            retriever.setDataSource(path)
            bitmap = retriever.getFrameAtTime(position, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
        } catch (ex: RuntimeException) {
            return null
        } catch (ex: OutOfMemoryError) {
            return null
        } finally {
            try {
                retriever.release()
            } catch (ex: RuntimeException) {
            }
        }

        val source = bitmap ?: return null
        val max = Math.max(source.width, source.height)
        if (max > 512) {
            val scale = 512f / max
            val w = Math.max(1, Math.round(scale * source.width))
            val h = Math.max(1, Math.round(scale * source.height))
            return try {
                Bitmap.createScaledBitmap(source, w, h, true)
            } catch (ex: OutOfMemoryError) {
                source
            }
        }
        return source
    }

    fun getFileNameWithGifExtension(path: String): String {
        val file = File(path)
        var fileName = ""
        val gifSuffix = "gif"
        val dotGifSuffix = ".$gifSuffix"

        if (file.exists()) {
            val name = file.name
            fileName = name.replaceAfterLast(".", gifSuffix)

            if (!fileName.endsWith(dotGifSuffix)) {
                fileName += dotGifSuffix
            }
        }
        return fileName
    }

    fun deleteAllCache(context: Context, result: MethodChannel.Result) {
        val dir = context.getExternalFilesDir("video_compress")
        result.success(dir?.deleteRecursively())
    }
}