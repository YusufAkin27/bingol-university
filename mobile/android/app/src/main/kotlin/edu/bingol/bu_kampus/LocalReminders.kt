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
    // Varsayilan (Turkce) adlar; Dart acilista setNames ile kullanicinin diline gunceller.
    private val names = mutableMapOf(
        "chat" to "Mesajlar", "event" to "Etkinlikler", "announcement" to "Duyurular ve haberler",
        "social" to "Sosyal (begeni, takip)", "poll" to "Anketler", "academic" to "Ders ve sinav hatirlatmalari"
    )
    private val importance = mapOf(
        "chat" to NotificationManager.IMPORTANCE_HIGH, "event" to NotificationManager.IMPORTANCE_DEFAULT,
        "announcement" to NotificationManager.IMPORTANCE_DEFAULT, "social" to NotificationManager.IMPORTANCE_LOW,
        "poll" to NotificationManager.IMPORTANCE_DEFAULT, "academic" to NotificationManager.IMPORTANCE_HIGH
    )

    fun setNames(c: Context, n: Map<String, String>) {
        n.forEach { (k, v) -> if (names.containsKey(k) && v.isNotBlank()) names[k] = v }
        ensure(c)
    }

    // Idempotent: var olan kanalin yalniz adi guncellenir, kullanicinin sistem ayari korunur.
    fun ensure(c: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val nm = c.getSystemService(NotificationManager::class.java) ?: return
            names.forEach { (id, name) ->
                nm.createNotificationChannel(NotificationChannel(id, name, importance[id] ?: NotificationManager.IMPORTANCE_DEFAULT))
            }
        } catch (_: Exception) {
        }
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
