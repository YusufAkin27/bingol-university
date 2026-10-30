package edu.bingol.bu_kampus

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * Yerel hatirlatmalar: grup basina SharedPreferences'ta JSON listesi + AlarmManager (yaklasik zaman,
 * tam alarm izni gerekmez). Cihaz yeniden baslayinca / saat degisince BootReceiver yeniden kurar.
 * Dart tarafi: lib/core/notify/local_reminders.dart
 */
object LocalReminderStore {
    private const val PREFS = "bu_local_reminders"
    const val EXTRA_PAYLOAD = "bu_reminder_payload"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun groups(c: Context): List<String> = prefs(c).all.keys.toList()

    fun read(c: Context, group: String): MutableList<JSONObject> {
        val out = mutableListOf<JSONObject>()
        try {
            val arr = JSONArray(prefs(c).getString(group, "[]"))
            for (i in 0 until arr.length()) out.add(arr.getJSONObject(i))
        } catch (_: Exception) {
        }
        return out
    }

    private fun write(c: Context, group: String, items: List<JSONObject>) {
        val e = prefs(c).edit()
        if (items.isEmpty()) e.remove(group) else e.putString(group, JSONArray(items).toString())
        e.apply()
    }

    private fun requestCode(group: String, id: Int) = group.hashCode() * 31 + id

    private fun pending(c: Context, group: String, item: JSONObject, create: Boolean): PendingIntent? {
        val id = item.optInt("id")
        val i = Intent(c, ReminderReceiver::class.java).apply {
            action = "tr.com.bukampus.app.REMINDER"
            putExtra("group", group)
            putExtra("id", id)
            putExtra("title", item.optString("title"))
            putExtra("body", item.optString("body"))
            putExtra("channel", item.optString("channel", "academic"))
            putExtra("payload", item.optJSONObject("payload")?.toString() ?: "{}")
        }
        val flags = PendingIntent.FLAG_IMMUTABLE or
            (if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE)
        return PendingIntent.getBroadcast(c, requestCode(group, id), i, flags)
    }

    private fun arm(c: Context, group: String, item: JSONObject) {
        val at = item.optLong("at")
        if (at <= System.currentTimeMillis()) return
        val am = c.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pi = pending(c, group, item, true) ?: return
        try {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } catch (_: Exception) {
        }
    }

    private fun disarm(c: Context, group: String, item: JSONObject) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        pending(c, group, item, false)?.let {
            am.cancel(it)
            it.cancel()
        }
    }

    fun replaceGroup(c: Context, group: String, items: List<JSONObject>) {
        read(c, group).forEach { disarm(c, group, it) }
        val keep = items.filter { it.optLong("at") > System.currentTimeMillis() }
        write(c, group, keep)
        keep.forEach { arm(c, group, it) }
    }

    fun upsert(c: Context, group: String, item: JSONObject) {
        val list = read(c, group)
        list.filter { it.optInt("id") == item.optInt("id") }.forEach { disarm(c, group, it) }
        list.removeAll { it.optInt("id") == item.optInt("id") }
        if (item.optLong("at") > System.currentTimeMillis()) {
            list.add(item)
            arm(c, group, item)
        }
        write(c, group, list)
    }

    fun cancel(c: Context, group: String, id: Int) {
        val list = read(c, group)
        list.filter { it.optInt("id") == id }.forEach { disarm(c, group, it) }
        list.removeAll { it.optInt("id") == id }
        write(c, group, list)
    }

    fun cancelGroup(c: Context, group: String) = replaceGroup(c, group, emptyList())

    fun cancelAll(c: Context) = groups(c).forEach { cancelGroup(c, it) }

    fun remove(c: Context, group: String, id: Int) {
        val list = read(c, group)
        list.removeAll { it.optInt("id") == id }
        write(c, group, list)
    }

    /** Acilis/saat degisimi sonrasi tum alarmlari yeniden kurar. */
    fun rearmAll(c: Context) {
        for (g in groups(c)) {
            val list = read(c, g).filter { it.optLong("at") > System.currentTimeMillis() }
            write(c, g, list)
            list.forEach { arm(c, g, it) }
        }
    }
}

object Channels {
    /** Marka kirmizisi (#F73B2E); bildirim vurgusu ve isik rengi. res/values/colors.xml notification_accent ile ayni. */
    const val ACCENT = 0xFFF73B2E.toInt()

    private const val PREFS = "bu_channels"

    // Kimlikler SUNUCU sozlesmesiyle ayni (PushMessages: chat/event/announcement/poll/social); academic yerel hatirlatma.
    // Varsayilan (Turkce) adlar; Dart acilista/on plana donuste setNames ile kullanicinin diline gunceller ve
    // SharedPreferences'a yazar: uygulama kapaliyken FCM sureci Application.onCreate'te kanallari son dille kurar.
    private val defaultNames = mapOf(
        "chat" to "Mesajlar", "event" to "Etkinlikler", "announcement" to "Duyurular ve haberler",
        "social" to "Sosyal (begeni, takip)", "poll" to "Anketler", "academic" to "Ders ve sinav hatirlatmalari"
    )
    private val defaultDescs = mapOf(
        "chat" to "Birebir ve grup sohbet mesajlari.", "event" to "Etkinlik hatirlatmalari ve degisiklikler.",
        "announcement" to "Haber, duyuru, kulup ve sistem bildirimleri.", "social" to "Begeni ve takip bildirimleri.",
        "poll" to "Yeni anketler ve sonuclari.", "academic" to "Ders ve sinav saatinden onceki hatirlatmalar."
    )

    // Onem (kanal olusturulunca sabitlenir; kullanici sistem ayarindan degistirebilir, kod dusuremez):
    // mesaj = HIGH (ses + titresim + baslik ustu), duyuru/etkinlik/anket = DEFAULT (ses), sosyal = LOW (sessiz).
    private val importance = mapOf(
        "chat" to NotificationManager.IMPORTANCE_HIGH, "event" to NotificationManager.IMPORTANCE_DEFAULT,
        "announcement" to NotificationManager.IMPORTANCE_DEFAULT, "social" to NotificationManager.IMPORTANCE_LOW,
        "poll" to NotificationManager.IMPORTANCE_DEFAULT, "academic" to NotificationManager.IMPORTANCE_HIGH
    )

    /** Kullanici bunlari sistem ayarindan kapatirsa bildirim gelmez; yardim ekrani uyarir. (social bilincli kapatilabilir.) */
    private val critical = listOf("chat", "event", "announcement")

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun setNames(c: Context, n: Map<String, String>, d: Map<String, String> = emptyMap()) {
        val e = prefs(c).edit()
        n.forEach { (k, v) -> if (defaultNames.containsKey(k) && v.isNotBlank()) e.putString("n_$k", v) }
        d.forEach { (k, v) -> if (defaultDescs.containsKey(k) && v.isNotBlank()) e.putString("d_$k", v) }
        e.apply()
        ensure(c)
    }

    // Idempotent: var olan kanalin yalniz adi/aciklamasi guncellenir, kullanicinin sistem ayari (onem, ses) korunur.
    fun ensure(c: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val nm = c.getSystemService(NotificationManager::class.java) ?: return
            val p = prefs(c)
            defaultNames.forEach { (id, defName) ->
                val ch = NotificationChannel(
                    id,
                    p.getString("n_$id", null) ?: defName,
                    importance[id] ?: NotificationManager.IMPORTANCE_DEFAULT
                )
                ch.description = p.getString("d_$id", null) ?: defaultDescs[id]
                when (id) {
                    "chat" -> {
                        ch.enableVibration(true)
                        ch.enableLights(true)
                        ch.lightColor = ACCENT
                        ch.setShowBadge(true)
                    }
                    "social" -> ch.setShowBadge(false)
                }
                nm.createNotificationChannel(ch)
            }
        } catch (_: Exception) {
        }
    }

    /** Kullanicinin sistem ayarindan tamamen kapattigi onemli kanallar (Android 8+). */
    fun blocked(c: Context): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return emptyList()
        return try {
            val nm = c.getSystemService(NotificationManager::class.java) ?: return emptyList()
            critical.filter { nm.getNotificationChannel(it)?.importance == NotificationManager.IMPORTANCE_NONE }
        } catch (_: Exception) {
            emptyList()
        }
    }
}

/** Surec FCM ile (uygulama kapaliyken) baslasa bile kanallar hazir olsun: sistem bildirimi dogru kanaldan/sesle gosterir. */
class BuApplication : android.app.Application() {
    override fun onCreate() {
        super.onCreate()
        Channels.ensure(this)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val group = intent.getStringExtra("group") ?: return
            val id = intent.getIntExtra("id", 0)
            LocalReminderStore.remove(context, group, id)
            val nm = context.getSystemService(NotificationManager::class.java) ?: return
            // Kullanici bildirimleri kapattiysa sessizce birak.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !nm.areNotificationsEnabled()) return
            Channels.ensure(context)
            val channel = intent.getStringExtra("channel") ?: "academic"
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(LocalReminderStore.EXTRA_PAYLOAD, intent.getStringExtra("payload") ?: "{}")
            }
            val tap = PendingIntent.getActivity(
                context, group.hashCode() * 31 + id, open,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                Notification.Builder(context, channel) else Notification.Builder(context)
            b.setSmallIcon(R.drawable.ic_stat_bu)
                .setContentTitle(intent.getStringExtra("title"))
                .setContentText(intent.getStringExtra("body"))
                .setStyle(Notification.BigTextStyle().bigText(intent.getStringExtra("body")))
                .setContentIntent(tap)
                .setColor(Channels.ACCENT)
                .setCategory(Notification.CATEGORY_REMINDER)
                .setAutoCancel(true)
            nm.notify(group.hashCode() * 31 + id, b.build())
        } catch (_: Exception) {
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            LocalReminderStore.rearmAll(context)
        } catch (_: Exception) {
        }
    }
}
