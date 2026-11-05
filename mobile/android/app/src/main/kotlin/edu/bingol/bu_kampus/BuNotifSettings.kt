package edu.bingol.bu_kampus

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Bildirim ayarlari koprusu (kanal `bu_kampus/notif_settings`; Dart sarmalayici lib/core/platform/notif_settings.dart).
 *  - openChannelSettings(channelId): o bildirim kanalinin sistem ayar sayfasi (ses/titresim/onem); Android 8 alti: uygulama bildirim ayari.
 *  - openAppNotificationSettings(): uygulamanin sistem bildirim ayari (Android 13+ izin reddedildiyse buradan acilir).
 *  - setHidePreview(bool) / hidePreview(): kilit ekrani "mesaj onizlemesini gizle" tercihi (varsayilan KAPALI).
 *  - notificationsEnabled(): uygulama duzeyi bildirim izni acik mi.
 * Hata firlatmaz: acilamayan ayar sayfasi false doner.
 */
object BuNotifSettings {
    private const val CHANNEL = "bu_kampus/notif_settings"

    fun register(messenger: BinaryMessenger, activity: Activity) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openChannelSettings" -> result.success(openChannel(activity, call.argument<String>("channelId")))
                "openAppNotificationSettings" -> result.success(openApp(activity))
                "setHidePreview" -> {
                    PushPrefs.setHidePreview(activity, call.argument<Boolean>("hide") == true)
                    result.success(true)
                }
                "hidePreview" -> result.success(PushPrefs.hidePreview(activity))
                "notificationsEnabled" -> {
                    val nm = activity.getSystemService(NotificationManager::class.java)
                    result.success(nm?.areNotificationsEnabled() ?: true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun start(activity: Activity, intent: Intent): Boolean = try {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
        true
    } catch (_: Exception) {
        false
    }

    private fun details(activity: Activity) =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", activity.packageName, null))

    private fun openApp(activity: Activity): Boolean {
        val app = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        else details(activity)
        return start(activity, app) || start(activity, details(activity))
    }

    private fun openChannel(activity: Activity, channelId: String?): Boolean {
        // Yalniz bilinen kanallar (beyaz liste); bilinmeyen kimlik uygulama ayarina duser.
        if (channelId == null || channelId !in PushRenderPlan.CHANNELS || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return openApp(activity)
        Channels.ensure(activity)
        val i = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
        return start(activity, i) || openApp(activity)
    }
}
