package edu.bingol.bu_kampus

import android.app.NotificationManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
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
        launchPayload = intent?.getStringExtra(LocalReminderStore.EXTRA_PAYLOAD)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val p = intent.getStringExtra(LocalReminderStore.EXTRA_PAYLOAD) ?: return
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
                Channels.setNames(this, m)
            }
            "notificationsAllowed" -> {
                val nm = getSystemService(NotificationManager::class.java)
                val ok = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) nm?.areNotificationsEnabled() ?: true else true
                result.success(ok)
            }
            "takeLaunchPayload" -> {
                val p = launchPayload
                launchPayload = null
                result.success(if (p == null) null else toMap(p))
            }
            else -> result.notImplemented()
        }
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

    private fun toMap(json: String): Map<String, String> {
        val out = HashMap<String, String>()
        try {
            val o = JSONObject(json)
            for (k in o.keys()) out[k] = o.optString(k)
        } catch (_: Exception) {
        }
        return out
    }
}
