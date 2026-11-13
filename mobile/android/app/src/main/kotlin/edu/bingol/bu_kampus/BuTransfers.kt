package edu.bingol.bu_kampus

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Arka plan aktarimi koprusu (kanal `bu_kampus/transfers`; Dart tarafi lib/core/transfers/transfer_platform.dart).
 *  - update{live,active,waiting,processing,failed,percent,...metinler}: TEK ilerleme bildirimini gunceller (sabit id,
 *    her ilerlemede yeni bildirim YOK). On plan servisi KULLANILMAZ (Play "on plan hizmeti izni" beyani gerektirir).
 *  - stop(): bildirimi kaldirir.
 * Yuzde: `percent < 0` = belirsiz ilerleme (toplam bilinmiyor ya da sunucu isliyor); yuzde uydurulmaz.
 * GIZLILIK: bildirim yalniz genel sayim tasir; alici, mesaj metni, dosya adi, onizleme YOK.
 * SINIR (durust): aktarim Dart surecinde surer; uygulama arka plana gecince sistem sureci durdurabilir. Dart kuyrugu
 * acilista kalan isi ayni Idempotency-Key ile surdurur.
 */
object BuTransfers {
    private const val CHANNEL = "bu_kampus/transfers"
    const val NOTIF_CHANNEL_ID = "bu_transfers"
    const val NOTIF_ID = 7710

    class State(
        val live: Int, val active: Int, val waiting: Int, val processing: Int, val failed: Int, val percent: Int,
        val channelName: String, val uploading: String, val waitingText: String, val processingText: String,
        val failedText: String, val retryHint: String,
    )

    fun register(messenger: BinaryMessenger, activity: Activity) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val s = parse(call)
                    result.success(update(activity.applicationContext, s))
                }
                "stop" -> {
                    stop(activity.applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun parse(call: io.flutter.plugin.common.MethodCall): State {
        fun i(k: String) = call.argument<Number>(k)?.toInt() ?: 0
        fun s(k: String, d: String) = call.argument<String>(k)?.takeIf { it.isNotBlank() } ?: d
        return State(
            live = i("live"), active = i("active"), waiting = i("waiting"), processing = i("processing"),
            failed = i("failed"), percent = call.argument<Number>("percent")?.toInt() ?: -1,
            channelName = s("channelName", "Transfers"), uploading = s("uploading", "Uploading"),
            waitingText = s("waitingText", "Waiting for connection"), processingText = s("processingText", "Processing"),
            failedText = s("failedText", "Transfer failed"), retryHint = s("retryHint", "Tap to retry"),
        )
    }

    /** true: bildirim gosterildi / servis ayakta. Hata firlatmaz (izin yok, arka plandan baslatma yasagi...). */
    fun update(ctx: Context, s: State): Boolean {
        return try {
            ensureChannel(ctx, s.channelName)
            if (s.live > 0) {
                // Canli is: TEK ilerleme bildirimi (sabit id, yerinde guncellenir). On plan servisi YOK (Play politikasi).
                nm(ctx)?.notify(NOTIF_ID, build(ctx, s, ongoing = true))
            } else {
                // Canli is yok: bildirim kalkar; basarisiz is varsa kalici (silinebilir) uyari birakilir.
                nm(ctx)?.cancel(NOTIF_ID)
                if (s.failed > 0) nm(ctx)?.notify(NOTIF_ID, build(ctx, s, ongoing = false))
            }
            true
        } catch (e: Exception) {
            // Bildirim izni yok vb.: bildirim gorunmez, uygulama ici takip surer.
            false
        }
    }

    fun stop(ctx: Context) {
        nm(ctx)?.cancel(NOTIF_ID)
    }

    private fun nm(ctx: Context) = ctx.getSystemService(NotificationManager::class.java)

    private fun ensureChannel(ctx: Context, name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val ch = NotificationChannel(NOTIF_CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW)
        ch.setShowBadge(false)
        nm(ctx)?.createNotificationChannel(ch)
    }

    fun build(ctx: Context, s: State, ongoing: Boolean): Notification {
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        val pi = open?.let {
            PendingIntent.getActivity(ctx, 0, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val b = NotificationCompat.Builder(ctx, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_bu)
            .setOnlyAlertOnce(true) // ilerleme guncellemesi ses/titresim yapmaz
            .setSilent(true)
            .setOngoing(ongoing)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setContentIntent(pi)
        if (s.live > 0) {
            val text = when {
                s.active > 0 -> "${s.uploading} (${s.live})"
                s.waiting > 0 -> s.waitingText
                else -> s.processingText
            }
            b.setContentTitle(text)
            if (s.active > 0 && s.percent in 0..100) {
                b.setProgress(100, s.percent, false)
                b.setContentText("${s.percent}%")
            } else {
                b.setProgress(0, 0, true) // belirsiz
            }
        } else {
            b.setContentTitle(s.failedText).setContentText(s.retryHint).setAutoCancel(true)
        }
        return b.build()
    }
}
