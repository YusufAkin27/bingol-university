package edu.bingol.bu_kampus

import android.app.NotificationManager
import android.content.ClipData
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var notifyChannel: MethodChannel? = null
    private var launchPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Ekran görüntüsü ve ekran kaydını engeller; son uygulamalar görünümünde de içerik gizlenir.
        // YALNIZ release'te: debug (debuggable) derlemede tasarım incelemesi için ekran görüntüsü serbesttir.
        // (BuildConfig üretimi kapalı olduğundan DEBUG bayrağı yerine uygulamanın debuggable bayrağına bakılır.)
        val debuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) {
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        }
        super.onCreate(savedInstanceState)
        // Sunucu push yükünde kanal kimliği gönderir (chat, event, announcement, social, poll, academic);
        // kanal yoksa Android 8+ bildirimi sessiz "Diğer" kanalına düşürür. Idempotent oluşturulur.
        Channels.ensure(this)
        launchPayload = trustedPayload(intent)
    }

    /**
     * Bu aktivite launcher oldugu icin DISARIYA ACIKTIR: baska bir uygulama `bu_reminder_payload` ekstrasi ile
     * baslatip Dart yonlendiricisine sahte yuk basabilir (A4-01). Yalnizca ReminderReceiver'in HMAC ile imzaladigi
     * yuk kabul edilir; imzasiz/bozuk ekstra yok sayilir (uygulama yine normal acilir).
     */
    private fun trustedPayload(i: Intent?): String? {
        if (i == null) return null
        val p = i.getStringExtra(LocalReminderStore.EXTRA_PAYLOAD) ?: return null
        if (p.length > MAX_PAYLOAD_CHARS) return null
        return if (LocalReminderStore.verify(this, p, i.getStringExtra(LocalReminderStore.EXTRA_SIG))) p else null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val p = trustedPayload(intent) ?: return
        // Uygulama açıkken hatırlatmaya dokunuldu: Dart'a ilet.
        try {
            notifyChannel?.invokeMethod("onTap", toMap(p))
        } catch (_: Exception) {
            launchPayload = p
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val ch = MethodChannel(messenger, "bu_kampus/notify")
        notifyChannel = ch
        ch.setMethodCallHandler { call, result -> handle(call, result) }
        // KVKK "verilerimi indir": JSON dosyasi sistem paylasim sayfasiyla verilir; pano KULLANILMAZ (A4-08).
        MethodChannel(messenger, "bu_kampus/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFile" -> shareFile(call, result)
                else -> result.notImplemented()
            }
        }
        // Eski akademik kanal (ReminderService): replaceReminders = 'academic' grubu.
        MethodChannel(messenger, "bu_kampus/academic").setMethodCallHandler { call, result ->
            when (call.method) {
                "replaceReminders" -> {
                    safe(result) {
                        val items = toItems(call.arguments as? List<*>, "academic")
                        LocalReminderStore.replaceGroup(this, "academic", items)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "replaceGroup" -> safe(result) {
                val g = call.argument<String>("group") ?: return@safe
                LocalReminderStore.replaceGroup(this, g, toItems(call.argument<List<*>>("items"), "academic"))
            }
            "upsert" -> safe(result) {
                val g = call.argument<String>("group") ?: return@safe
                val m = call.argument<Map<*, *>>("item") ?: return@safe
                LocalReminderStore.upsert(this, g, JSONObject(m))
            }
            "cancel" -> safe(result) {
                val g = call.argument<String>("group") ?: return@safe
                LocalReminderStore.cancel(this, g, call.argument<Int>("id") ?: return@safe)
            }
            "cancelGroup" -> safe(result) {
                LocalReminderStore.cancelGroup(this, call.argument<String>("group") ?: return@safe)
            }
            "cancelAll" -> safe(result) { LocalReminderStore.cancelAll(this) }
            "setChannelNames" -> safe(result) {
                val m = call.argument<Map<String, String>>("names") ?: return@safe
                Channels.setNames(this, m, call.argument<Map<String, String>>("descriptions") ?: emptyMap())
            }
            "notificationsAllowed" -> {
                val nm = getSystemService(NotificationManager::class.java)
                val ok = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) nm?.areNotificationsEnabled() ?: true else true
                result.success(ok)
            }
            // Yardim ekrani: izin + kapatilmis kanallar + uretici (pil/otomatik baslatma metni icin).
            "pushDiagnostics" -> {
                val nm = getSystemService(NotificationManager::class.java)
                result.success(
                    mapOf(
                        "enabled" to (nm?.areNotificationsEnabled() ?: true),
                        "blocked" to Channels.blocked(this),
                        "manufacturer" to (Build.MANUFACTURER ?: ""),
                        "sdk" to Build.VERSION.SDK_INT
                    )
                )
            }
            "openNotificationSettings" -> result.success(
                startSettings(
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    else appDetails()
                ) || startSettings(appDetails())
            )
            // Pil/otomatik baslatma: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS izni KULLANILMAZ (Play politikasi); yalniz ayar sayfasi acilir.
            "openBatterySettings" -> result.success(
                startSettings(appDetails()) || startSettings(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            )
            "takeLaunchPayload" -> {
                val p = launchPayload
                launchPayload = null
                result.success(if (p == null) null else toMap(p))
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Yalniz `cache/export/` altindaki bir dosyayi paylasir (FileProvider content:// URI, gecici okuma izni).
     * Dart yolu dis kaynakli degildir ama yine de dizin disi yol reddedilir.
     */
    private fun shareFile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("BAD_ARGS", "path", null)
                return
            }
            val file = File(path).canonicalFile
            val dir = File(cacheDir, "export").canonicalFile
            if (file.parentFile != dir || !file.isFile) {
                result.error("FORBIDDEN_PATH", "export disi dosya", null)
                return
            }
            val uri = FileProvider.getUriForFile(this, "$packageName.exportprovider", file)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "application/json"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri("", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(send, call.argument<String>("title"))
            chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE_FAILED", e.javaClass.simpleName, null)
        }
    }

    private fun appDetails() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))

    private fun startSettings(i: Intent): Boolean = try {
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(i)
        true
    } catch (_: Exception) {
        false
    }

    private fun safe(result: MethodChannel.Result, block: () -> Unit) {
        try {
            block()
            result.success(null)
        } catch (e: Exception) {
            result.error("REMINDER_FAILED", e.message, null)
        }
    }

    private fun toItems(list: List<*>?, defChannel: String): List<JSONObject> {
        val out = mutableListOf<JSONObject>()
        list?.forEach {
            if (it is Map<*, *>) {
                val o = JSONObject()
                for ((k, v) in it) {
                    if (k is String) o.put(k, if (v is Map<*, *>) JSONObject(v) else v)
                }
                if (!o.has("channel")) o.put("channel", defChannel)
                out.add(o)
            }
        }
        return out
    }

    /** Yalniz hedef anahtarlari (beyaz liste) ve <= 200 karakter deger; Dart tarafinda da ayni sinir uygulanir. */
    private fun toMap(json: String): Map<String, String> {
        val out = HashMap<String, String>()
        try {
            val o = JSONObject(json)
            for (k in o.keys()) {
                if (k !in PAYLOAD_KEYS) continue
                val v = o.optString(k)
                if (v.isNotEmpty() && v.length <= MAX_VALUE_CHARS) out[k] = v
            }
        } catch (_: Exception) {
        }
        return out
    }

    private companion object {
        const val MAX_PAYLOAD_CHARS = 2000
        const val MAX_VALUE_CHARS = 200

        // lib/core/push/push_targets.dart kLocalReminderPayloadKeys ile ayni liste (type/event BILEREK yok).
        val PAYLOAD_KEYS = setOf(
            "targetType", "targetId", "conversationId", "eventId", "postId", "communityId",
            "newsId", "ticketId", "pollId", "userId", "announcementId"
        )
    }
}
