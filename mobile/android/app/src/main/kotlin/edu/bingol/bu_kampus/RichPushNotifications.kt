package edu.bingol.bu_kampus

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors
import org.json.JSONObject

/** FCM data-only renderer. The manifest SEND permission prevents another app from forging this broadcast. */
class RichPushReceiver : BroadcastReceiver() {
    companion object { private val worker = Executors.newSingleThreadExecutor() }
    override fun onReceive(context: Context, intent: Intent) {
        val extras = intent.extras ?: return
        if (extras.getString("richNotification") != "1" && extras.getString("richChat") != "1") return
        if (BuApplication.foreground) return
        val data = extras.keySet().mapNotNull { key -> (extras.get(key) as? String)?.let { key to it } }.toMap()
        if (!RichPushNotifications.canDisplay(context, data)) return
        val pending = goAsync()
        worker.execute {
            try { RichPushNotifications.show(context.applicationContext, data) }
            catch (error: Exception) { android.util.Log.w("RichPush", "Notification render failed: " + error.javaClass.simpleName) }
            finally { pending.finish() }
        }
    }
}

object RichPushNotifications {
    const val EXTRA_PAYLOAD = "bu_push_payload"
    const val EXTRA_SIGNATURE = "bu_push_signature"
    private val cache = object : android.util.LruCache<String, Bitmap>(16) {}
    private val mediaWorker = java.util.concurrent.ThreadPoolExecutor(2, 2, 30, java.util.concurrent.TimeUnit.SECONDS,
        java.util.concurrent.ArrayBlockingQueue(24), java.util.concurrent.ThreadPoolExecutor.DiscardPolicy())
    private val renderLock = Any()
    fun authorize(context: Context, userId: Long) {
        context.getSharedPreferences("bu_push_account", Context.MODE_PRIVATE).edit().putLong("recipient", userId).apply()
    }
    fun canDisplay(context: Context, data: Map<String, String>): Boolean {
        val user = context.getSharedPreferences("bu_push_account", Context.MODE_PRIVATE).getLong("recipient", -1)
        return user > 0 && (data["recipientId"]?.toLongOrNull()?.let { it == user } ?: (data["richChat"] == "1"))
    }
    fun dismiss(context: Context, tag: String) = synchronized(renderLock) {
        context.getSystemService(NotificationManager::class.java)?.cancel(tag, 0)
    }
    fun clear(context: Context) = synchronized(renderLock) {
        context.getSharedPreferences("bu_push_account", Context.MODE_PRIVATE).edit().remove("recipient").apply()
        cache.evictAll()
        context.getSystemService(NotificationManager::class.java)?.cancelAll()
    }
    private val channels = setOf("chat", "event", "announcement", "social", "poll", "academic")

    private fun label(data: Map<String, String>, tr: String, en: String, ar: String): String = when {
        data["locale"]?.startsWith("en") == true -> en
        data["locale"]?.startsWith("ar") == true -> ar
        else -> tr
    }

    fun style(data: Map<String, String>): String = data["style"] ?: when {
        data["type"] == "MESSAGE" && !data["imageUrl"].isNullOrBlank() -> "CHAT_MEDIA"
        data["type"] == "MESSAGE" && data["conversationType"] == "GROUP" -> "CHAT_GROUP"
        data["type"] == "MESSAGE" -> "CHAT_DIRECT"
        else -> "ANNOUNCEMENT"
    }

    private fun actions(data: Map<String, String>): List<Pair<String, String>> = when (style(data)) {
        "CHAT_GROUP" -> listOf("reply" to label(data, "↩ Yanıtla", "↩ Reply", "رد"), "mute_hour" to label(data, "1 Saat Sessize Al", "Mute for 1 hour", "كتم لساعة"))
        "CHAT_MEDIA" -> listOf("open" to label(data, "Görüntüle", "View", "عرض"), "reply" to label(data, "↩ Yanıtla", "↩ Reply", "رد"))
        "CHAT_DIRECT" -> listOf("reply" to label(data, "↩ Yanıtla", "↩ Reply", "رد"), "mark_read" to label(data, "Okundu İşaretle", "Mark as read", "تحديد كمقروء"))
        "FOLLOW_REQUEST" -> listOf("follow_accept" to label(data, "✓ Onayla", "✓ Accept", "قبول"), "follow_decline" to label(data, "Reddet", "Decline", "رفض"))
        "FOLLOW" -> listOf("follow" to label(data, "Takip et", "Follow", "متابعة"))
        "FOLLOW_ACCEPTED" -> listOf("open" to label(data, "Profili Gör", "View profile", "عرض الملف"))
        "EVENT_REMINDER" -> listOf("calendar" to label(data, "Takvime Ekle", "Add to calendar", "إضافة للتقويم"), "map" to label(data, "Haritada Gör", "Show on map", "عرض الخريطة"))
        "EVENT_ADMISSION" -> listOf("open" to label(data, "Giriş Kartı", "Entry card", "بطاقة الدخول"))
        "EVENT_UPDATE" -> listOf("open" to label(data, "Program Detayı", "Event details", "تفاصيل الفعالية"))
        "EXAM" -> listOf("open" to label(data, "Sınav Detayı", "Exam details", "تفاصيل الامتحان"))
        "POLL" -> listOf("open" to label(data, "Oy ver", "Vote", "تصويت"))
        "MEAL" -> listOf("open" to label(data, "Menüyü Gör", "View menu", "عرض القائمة"))
        "SUPPORT" -> listOf("open" to label(data, "Talebi Görüntüle →", "View ticket →", "عرض الطلب"))
        "SECURITY" -> listOf("security" to label(data, "Hesap Güvenliği", "Account security", "أمان الحساب"))
        else -> listOf("open" to label(data, "Detay", "Details", "التفاصيل"))
    }

    private fun section(data: Map<String, String>): String = when (style(data)) {
        "CHAT_DIRECT" -> label(data, "Sohbet", "Chat", "محادثة")
        "CHAT_GROUP" -> label(data, "Kulüp Odası", "Group chat", "محادثة جماعية")
        "CHAT_MEDIA" -> label(data, "Medya", "Media", "وسائط")
        "EVENT_REMINDER", "EVENT_UPDATE", "EVENT_ADMISSION" -> label(data, "Etkinlik", "Event", "فعالية")
        "EXAM", "ACADEMIC" -> label(data, "Akademik", "Academic", "أكاديمي")
        "POLL" -> label(data, "Anket", "Poll", "استطلاع")
        "MEAL" -> label(data, "Bugünün Menüsü", "Today's menu", "قائمة اليوم")
        "SECURITY" -> label(data, "Güvenlik", "Security", "الأمان")
        "SUPPORT" -> label(data, "Destek Masası", "Support", "الدعم")
        else -> label(data, "Bildirim", "Notification", "إشعار")
    }

    private fun tap(context: Context, data: Map<String, String>, action: String, tag: String): PendingIntent {
        val safe = data.filterKeys { it != "replyText" }
        val payload = JSONObject(safe).put("notificationAction", action).put("notificationTag", tag)
            .put("actionId", UUID.randomUUID().toString()).toString()
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            this.data = Uri.parse("bukampus://notification/" + Uri.encode(tag) + "/" + action)
            putExtra(EXTRA_PAYLOAD, payload)
            putExtra(EXTRA_SIGNATURE, LocalReminderStore.sign(context, payload))
        }
        return PendingIntent.getActivity(context, (tag + action).hashCode(), open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun views(context: Context, data: Map<String, String>, count: Int, tag: String, expanded: Boolean, avatar: Bitmap?, photo: Bitmap?): RemoteViews {
        val view = RemoteViews(context.packageName, if (expanded) R.layout.push_expanded else R.layout.push_compact)
        view.setTextViewText(R.id.push_title, data["title"].orEmpty())
        view.setTextViewText(R.id.push_body, data["body"].orEmpty())
        if (avatar != null) { view.setImageViewBitmap(R.id.push_avatar, avatar); view.setViewPadding(R.id.push_avatar, 0, 0, 0, 0) }
        if (count > 1 && style(data).startsWith("CHAT")) {
            view.setViewVisibility(R.id.push_count, View.VISIBLE)
            view.setTextViewText(R.id.push_count, label(data, "$count yeni mesaj", "$count new messages", "$count رسائل جديدة"))
        }
        if (expanded) {
            view.setTextViewText(R.id.push_section, "BU KAMPÜS · " + section(data))
            if (photo != null) { view.setViewVisibility(R.id.push_image, View.VISIBLE); view.setImageViewBitmap(R.id.push_image, photo); view.setInt(R.id.push_title, "setMaxLines", 1); view.setInt(R.id.push_body, "setMaxLines", 2) }
            val actions = actions(data).take(2)
            for ((index, id) in listOf(R.id.push_action_one, R.id.push_action_two).withIndex()) {
                if (index >= actions.size) { view.setViewVisibility(id, View.GONE); continue }
                val action = actions[index]
                view.setTextViewText(id, action.second)
                view.setOnClickPendingIntent(id, tap(context, data, action.first, tag))
            }
        }
        return view
    }

    fun show(context: Context, data: Map<String, String>) {
        if (data["title"].isNullOrBlank() && data["body"].isNullOrBlank()) return
        Channels.ensure(context)
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return
        val tag = data["tag"] ?: data["collapseKey"] ?: data["messageId"]?.let { "message:$it" } ?: UUID.randomUUID().toString()
        val previous = manager.activeNotifications.firstOrNull { it.tag == tag }?.notification
        val message = data["messageId"]
        if (message != null && previous?.extras?.getString("bu.messageId") == message) return
        val count = if (style(data).startsWith("CHAT")) maxOf(data["count"]?.toIntOrNull() ?: 1,
            (previous?.extras?.getInt("bu.count", 0) ?: 0) + 1) else 1
        val channel = data["channelId"]?.takeIf { it in channels } ?: "announcement"
        val renderId = UUID.randomUUID().toString()
        val open = tap(context, data, "open", tag)
        fun publish(avatar: Bitmap?, photo: Bitmap?, quiet: Boolean) = synchronized(renderLock) {
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
            builder.setSmallIcon(R.drawable.ic_stat_bu).setContentTitle(data["title"]).setContentText(data["body"])
                .setColor(Channels.ACCENT).setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(quiet)
                .setVisibility(Notification.VISIBILITY_PUBLIC).setNumber(count)
                .setStyle(Notification.DecoratedCustomViewStyle())
                .setCustomContentView(views(context, data, count, tag, false, avatar, null))
                .setCustomBigContentView(views(context, data, count, tag, true, avatar, photo))
                .setCustomHeadsUpContentView(views(context, data, count, tag, false, avatar, null))
                .addExtras(android.os.Bundle().apply { putString("bu.messageId", message); putInt("bu.count", count); putString("bu.renderId", renderId) })
            if (style(data).startsWith("CHAT")) builder.setCategory(Notification.CATEGORY_MESSAGE)
            manager.notify(tag, 0, builder.build())
        }
        publish(null, null, false)
        // Finish the broadcast immediately after the text card. Media is best-effort and never
        // resurrects a dismissed card or replaces a newer message from the same conversation.
        if (!data["senderAvatarUrl"].isNullOrBlank() || !data["imageUrl"].isNullOrBlank()) mediaWorker.execute {
            val avatar = bitmap(data["senderAvatarUrl"], true)
            val photo = bitmap(data["imageUrl"], false)
            synchronized(renderLock) {
            val current = manager.activeNotifications.firstOrNull { it.tag == tag }?.notification
            if ((avatar != null || photo != null) && current?.extras?.getString("bu.renderId") == renderId) {
                try { publish(avatar, photo, true) } catch (_: Exception) { }
            }
            }
        }
    }

    /** Signed HTTPS thumbnails only, bounded I/O and decoded pixels; no authorization tokens are stored here. */
    private fun bitmap(raw: String?, round: Boolean): Bitmap? {
        if (raw.isNullOrBlank() || !raw.startsWith("https://")) return null
        cache.get(raw)?.let { return it }
        return runCatching {
            val connection = URL(raw).openConnection() as HttpURLConnection
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 1800; connection.readTimeout = 1800
            try {
                if (connection.responseCode != 200) return null
                val bytes = connection.inputStream.use { input ->
                    val output = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (output.size() <= 1_048_576) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                    }
                    output.toByteArray()
                }
                if (bytes.size > 1_048_576) return null
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                val options = BitmapFactory.Options().apply { inSampleSize = maxOf(1, maxOf(bounds.outWidth, bounds.outHeight) / if (round) 128 else 512) }
                val image = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return null
                val result = if (!round) image else {
                    val side = minOf(image.width, image.height)
                    val out = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(out)
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                    canvas.drawCircle(side / 2f, side / 2f, side / 2f, paint)
                    paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
                    canvas.drawBitmap(image, Rect((image.width-side)/2, (image.height-side)/2, (image.width+side)/2, (image.height+side)/2), Rect(0,0,side,side), paint)
                    out
                }
                cache.put(raw, result); result
            } finally { connection.disconnect() }
        }.getOrNull()
    }
}
