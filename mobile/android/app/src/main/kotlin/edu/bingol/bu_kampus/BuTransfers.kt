package edu.bingol.bu_kampus

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Arka plan aktarimi koprusu (kanal `bu_kampus/transfers`; Dart tarafi lib/core/transfers/transfer_platform.dart).
 *  - update{live,active,waiting,processing,failed,percent,...metinler}: TEK ilerleme bildirimini gunceller (sabit id,
 *    her ilerlemede yeni bildirim YOK). Canli is varken `TransferService` on plan servisi (dataSync) sureci canli tutar.
 *  - stop(): servisi ve bildirimi kaldirir.
 * Yuzde: `percent < 0` = belirsiz ilerleme (toplam bilinmiyor ya da sunucu isliyor); yuzde uydurulmaz.
 * GIZLILIK: bildirim yalniz genel sayim tasir; alici, mesaj metni, dosya adi, onizleme YOK.
 * SINIR (durust): servis sureci canli tutar ama kullanici "Zorla durdur" derse ya da sistem sonlandirirsa aktarim biter;
 * Android 15+ dataSync servisi gunluk ~6 saat ust sinira tabidir (onTimeout). Dart kuyrugu acilista kalan isi surdurur.
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
            val svc = TransferService.current
            if (s.live > 0) {
                if (svc != null) {
                    svc.render(s)
                } else {
                    val i = Intent(ctx, TransferService::class.java)
                    TransferService.pending = s
                    ContextCompat.startForegroundService(ctx, i)
                }
            } else {
                // Canli is yok: servis kapanir; basarisiz is varsa kalici (silinebilir) uyari birakilir.
                svc?.shutdown()
                if (svc == null) nm(ctx)?.cancel(NOTIF_ID)
                if (s.failed > 0) nm(ctx)?.notify(NOTIF_ID, build(ctx, s, ongoing = false))
            }
            true
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException vb.: servis kurulamadi; sade bildirimle devam et.
            runCatching { nm(ctx)?.notify(NOTIF_ID, build(ctx, s, ongoing = s.live > 0)) }
            false
        }
    }

    fun stop(ctx: Context) {
        TransferService.current?.shutdown()
        TransferService.pending = null
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

/** Dataszync turunde on plan servisi: yalniz sureci canli tutar ve TEK bildirimi gosterir; aktarimi Dart kuyrugu surdurur. */
class TransferService : Service() {
    companion object {
        @Volatile var current: TransferService? = null
        @Volatile var pending: BuTransfers.State? = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        current = this
        val s = pending
        if (s == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        render(s, first = true)
        // Sistem sonlandirirsa yeniden baslatma: Dart kuyrugu bir sonraki acilista kalan isi kurtarir.
        return START_NOT_STICKY
    }

    fun render(s: BuTransfers.State, first: Boolean = false) {
        pending = s
        val n = BuTransfers.build(this, s, ongoing = true)
        if (first) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(BuTransfers.NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(BuTransfers.NOTIF_ID, n)
            }
        } else {
            getSystemService(NotificationManager::class.java)?.notify(BuTransfers.NOTIF_ID, n)
        }
    }

    fun shutdown() {
        current = null
        pending = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION") stopForeground(true)
        }
        stopSelf()
    }

    /** Android 15+: dataSync zaman asimi; servis kapanir (Dart kuyrugu islerini sonraki acilista surdurur). */
    override fun onTimeout(startId: Int, fgsType: Int) {
        shutdown()
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }
}
