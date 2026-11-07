package edu.bingol.bu_kampus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android "Canli Guncellemeler" (kanal `bu_kampus/live_updates`, Dart: lib/core/live/live_activity_service.dart).
 *
 * KAPSAM: yalniz kullanicinin kendi baslattigi etkinlik/sinav geri sayimi; sohbet/arkadaslik/duyuru ASLA.
 * - Android 16+ (API 36): Notification.ProgressStyle + setRequestPromotedOngoing(true) (+ kisa kritik metin). Sistem
 *   "promoted ongoing" icin uygunluga bakar ve istemeyebilir; bildirim yine standart ilerleme bildirimi olarak gorunur.
 * - Daha eski surumler: ayni bildirim standart ilerleme cubugu + geri sayim kronometresiyle (setUsesChronometer).
 * Geri sayimi sistem kronometresi surer: ARKA PLAN SERVISI / FOREGROUND SERVICE YOKTUR. Ilerleme cubugu yayin ve
 * uygulama her acilisinda yeniden hesaplanir; uygulama kapaliyken yalniz kronometre akar. Bildirim, bitisten sonra
 * setTimeoutAfter ile kendiliginden kalkar.
 * GERCEK CIHAZ TESTI GEREKLI (emulatorde promoted gorunum degisir).
 */
object BuLiveUpdates {
    private const val CHANNEL = "bu_kampus/live_updates"
    private const val NOTIF_CHANNEL_ID = "live_updates"
    private const val ID_BASE = 7_400_000

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "promotedSupported" -> result.success(promotedSupported(context))
                    "start" -> result.success(start(context, call))
                    "end" -> result.success(end(context, call))
                    "isActive" -> result.success(isActive(context, call))
                    "endAll" -> result.success(endAll(context))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("live_failed", e.javaClass.simpleName, null)
            }
        }
    }

    private fun notificationId(kind: String, refId: Long): Int = ID_BASE + ((kind.hashCode() * 31 + refId.hashCode()) and 0xFFFFF)

    private fun promotedSupported(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 36) return false
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return try { nm.canPostPromotedNotifications() } catch (_: Throwable) { false }
    }

    private fun start(context: Context, call: MethodCall): Boolean {
        val kind = call.argument<String>("kind") ?: return false
        if (kind != "EVENT" && kind != "EXAM") return false
        val refId = (call.argument<Number>("refId") ?: return false).toLong()
        val title = (call.argument<String>("title") ?: return false).take(80)
        val text = (call.argument<String>("text") ?: "").take(120)
        val shortText = (call.argument<String>("shortText") ?: "").take(7)
        val channelName = call.argument<String>("channelName") ?: "Live"
        val startMs = (call.argument<Number>("startMs") ?: return false).toLong()
        val endMs = (call.argument<Number>("endMs") ?: return false).toLong()
        val targetMs = (call.argument<Number>("targetMs") ?: return false).toLong()
        val now = System.currentTimeMillis()
        if (endMs <= now || endMs <= startMs) return false

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(NOTIF_CHANNEL_ID) == null) {
            // Sessiz, rozetsiz: geri sayim bildirimi ses/titresim cikarmaz.
            nm.createNotificationChannel(NotificationChannel(NOTIF_CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
            })
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
        ) return false

        val link = if (kind == "EXAM") "bukampus://timetable" else "bukampus://events/$refId"
        val open = PendingIntent.getActivity(
            context, notificationId(kind, refId),
            Intent(Intent.ACTION_VIEW, Uri.parse(link)).setPackage(context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val total = (endMs - startMs).coerceAtLeast(1L)
        val progress = (((now - startMs).coerceIn(0L, total)) * 1000L / total).toInt()

        val b = Notification.Builder(context, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_bu)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setWhen(targetMs)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setTimeoutAfter((endMs - now) + 60_000L)

        if (Build.VERSION.SDK_INT >= 36) {
            // Android 16: ilerleme sistem tarafindan "canli guncelleme" olarak cizilir.
            b.setStyle(Notification.ProgressStyle().setStyledByProgress(true).setProgress(progress)
                .setProgressSegments(listOf(Notification.ProgressStyle.Segment(1000))))
            b.setRequestPromotedOngoing(true)
            if (shortText.isNotEmpty()) b.setShortCriticalText(shortText)
        } else {
            b.setProgress(1000, progress, false)
        }
        nm.notify(notificationId(kind, refId), b.build())
        return true
    }

    private fun isActive(context: Context, call: MethodCall): Boolean {
        val kind = call.argument<String>("kind") ?: return false
        val refId = (call.argument<Number>("refId") ?: return false).toLong()
        val id = notificationId(kind, refId)
        return (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).activeNotifications.any { it.id == id }
    }

    /** Cikis: bu uygulamanin tum canli guncellemeleri kalkar (kimlik araligi ID_BASE..ID_BASE+0xFFFFF). */
    private fun endAll(context: Context): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.activeNotifications.filter { it.id in ID_BASE..(ID_BASE + 0xFFFFF) }.forEach { nm.cancel(it.id) }
        return true
    }

    private fun end(context: Context, call: MethodCall): Boolean {
        val kind = call.argument<String>("kind") ?: return false
        val refId = (call.argument<Number>("refId") ?: return false).toLong()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(notificationId(kind, refId))
        return true
    }
}
