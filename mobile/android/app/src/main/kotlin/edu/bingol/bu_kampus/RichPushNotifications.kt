package edu.bingol.bu_kampus

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput as CompatRemoteInput
import androidx.core.graphics.drawable.IconCompat
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors
import org.json.JSONObject

/** Sohbet bildiriminin durumu: yanit gonderilirken "Gonderiliyor", gonderilemeyip yeniden denenirken "yeniden denenecek". */
enum class ChatStatus { NORMAL, SENDING, RETRYING }

/**
 * Bildirim kartindaki uygulama-ici (arka plan islemi) dugmeleri: "ack" (Anladim: bildirimi kaldirir), satir ici yanit
 * (RemoteInput) ve "gone" (bildirim kaydirilip kapatildi: mesaj birikimi sifirlanir). Disariya KAPALI (exported=false);
 * yalniz uygulamanin kendi PendingIntent'leriyle tetiklenir.
 */
class RichPushActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val tag = intent.getStringExtra("tag") ?: return
            when (intent.getStringExtra("kind")) {
                "ack" -> RichPushNotifications.dismiss(context, tag)
                "reply" -> RichPushNotifications.reply(context, intent, tag, goAsync())
                "gone" -> ChatHistoryStore.clear(context, tag)
            }
        } catch (error: Throwable) {
            android.util.Log.w("RichPush", "Action receiver failed: " + error.javaClass.simpleName)
        }
    }
}

object RichPushNotifications {
    const val EXTRA_PAYLOAD = "bu_push_payload"
    const val EXTRA_SIGNATURE = "bu_push_signature"
    private const val KEY_REPLY = "bu_reply"
    private const val ACCOUNT_PREFS = "bu_push_account"
    private val cache = object : android.util.LruCache<String, Bitmap>(16) {}
    private val mediaWorker = java.util.concurrent.ThreadPoolExecutor(2, 2, 30, java.util.concurrent.TimeUnit.SECONDS,
        java.util.concurrent.ArrayBlockingQueue(24), java.util.concurrent.ThreadPoolExecutor.DiscardPolicy())
    private val renderLock = Any()

    /**
     * MainActivity (Flutter motoru hazirken) kurar: satir ici yanit metnini ekrani acmadan Dart `PushActions`a verir.
     * Motor yoksa (null) yanit "dokunarak gonder" bildirimine duser. (payload, tamamlandi(basarili)) -> devredildi mi.
     */
    @Volatile var actionBridge: ((Map<String, String>, (Boolean) -> Unit) -> Boolean)? = null

    private val chatAvatars = object : android.util.LruCache<String, Bitmap>(24) {}

    fun authorize(context: Context, userId: Long, imageHost: String? = null) {
        val prefs = context.getSharedPreferences(ACCOUNT_PREFS, Context.MODE_PRIVATE)
        // Hesap degisti: onceki hesabin mesaj birikimi/yanit kuyrugu yeni hesaba SIZMAZ.
        val previous = prefs.getLong("recipient", -1)
        if (previous > 0 && previous != userId) {
            PushStores.clearAll(context); SeenStore.clear(context); chatAvatars.evictAll()
        }
        prefs.edit().putLong("recipient", userId)
            .apply { if (!imageHost.isNullOrBlank()) putString("imageHost", imageHost.lowercase()) }.apply()
    }
    fun canDisplay(context: Context, data: Map<String, String>): Boolean {
        val user = context.getSharedPreferences(ACCOUNT_PREFS, Context.MODE_PRIVATE).getLong("recipient", -1)
        // recipientId yoksa (yeni sozlesme her yukte tasimayabilir) yerel hesap yetkiliyse cizilir; varsa eslesmeli.
        return user > 0 && (data["recipientId"]?.toLongOrNull()?.let { it == user } ?: true)
    }
    /** Bildirimi kaldirir; o sohbetin mesaj birikimi sifirlanir (bir sonraki mesaj yeni bildirim baslatir). */
    fun dismiss(context: Context, tag: String) = synchronized(renderLock) {
        ChatHistoryStore.clear(context, tag)
        val manager = context.getSystemService(NotificationManager::class.java) ?: return@synchronized
        manager.cancel(tag, 0)
        pruneSummaries(manager)
    }
    /** Cikis/hesap silme: bildirimler, mesaj birikimi, gorulmus kimlikler ve bekleyen yanitlar silinir. */
    fun clear(context: Context) = synchronized(renderLock) {
        context.getSharedPreferences(ACCOUNT_PREFS, Context.MODE_PRIVATE).edit().remove("recipient").apply()
        cache.evictAll()
        chatAvatars.evictAll()
        PushStores.clearAll(context)
        SeenStore.clear(context)
        ReplyDispatcher.cancelAll(context.applicationContext)
        context.getSystemService(NotificationManager::class.java)?.cancelAll()
    }

    /** Sunucu kurali (docs/changes/push.md): yalniz https + PUBLIC_WEB_URL ana makinesi ya da bingol.edu.tr alt alanlari. */
    fun imageHostAllowed(context: Context, host: String?): Boolean {
        val h = host?.lowercase() ?: return false
        if (h == "bingol.edu.tr" || h.endsWith(".bingol.edu.tr")) return true
        val own = context.getSharedPreferences(ACCOUNT_PREFS, Context.MODE_PRIVATE).getString("imageHost", null)
        return own != null && own == h
    }

    fun style(data: Map<String, String>): String = PushSpec.style(data)

    private fun payloadFor(data: Map<String, String>, action: String, tag: String, extra: Map<String, String> = emptyMap()): String {
        val safe = data.filterKeys { it != "replyText" }
        val json = JSONObject(safe).put("notificationAction", action).put("notificationTag", tag)
            .put("actionId", UUID.randomUUID().toString())
        extra.forEach { (k, v) -> json.put(k, v) }
        return json.toString()
    }

    private fun openIntent(context: Context, payload: String, tag: String, action: String): PendingIntent {
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            this.data = Uri.parse("bukampus://notification/" + Uri.encode(tag) + "/" + action)
            putExtra(EXTRA_PAYLOAD, payload)
            putExtra(EXTRA_SIGNATURE, LocalReminderStore.sign(context, payload))
        }
        return PendingIntent.getActivity(context, (tag + action).hashCode(), open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun tap(context: Context, data: Map<String, String>, action: String, tag: String): PendingIntent =
        openIntent(context, payloadFor(data, action, tag), tag, action)

    private fun ackIntent(context: Context, tag: String): PendingIntent {
        val intent = Intent(context, RichPushActionReceiver::class.java).putExtra("kind", "ack").putExtra("tag", tag)
        return PendingIntent.getBroadcast(context, (tag + "ack").hashCode(), intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    /** Bildirim kaydirilip kapatilinca (deleteIntent) o sohbetin birikimi sifirlanir. */
    private fun goneIntent(context: Context, tag: String): PendingIntent {
        val intent = Intent(context, RichPushActionReceiver::class.java).putExtra("kind", "gone").putExtra("tag", tag)
        return PendingIntent.getBroadcast(context, (tag + "gone").hashCode(), intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun replyIntent(context: Context, data: Map<String, String>, tag: String): PendingIntent {
        val safe = data.filterKeys { it != "replyText" }
        val intent = Intent(context, RichPushActionReceiver::class.java).putExtra("kind", "reply").putExtra("tag", tag)
            .putExtra("payload", JSONObject(safe).toString())
        // RemoteInput sonucu bu niyete islenir: API 31+ FLAG_MUTABLE zorunlu (bilesen acik/sabit, baska uygulamaya gitmez).
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(context, (tag + "reply").hashCode(), intent, flags)
    }

    private fun actionIntent(context: Context, data: Map<String, String>, action: ActionSpec, tag: String): PendingIntent =
        if (action.id == "ack") ackIntent(context, tag) else tap(context, data, action.id, tag)

    private class Art(val avatar: Bitmap?, val thumb: Bitmap?, val photo: Bitmap?)

    private fun dp(context: Context, v: Int) = (v * context.resources.displayMetrics.density + 0.5f).toInt()

    private fun span(text: String, color: Int, bold: Boolean): SpannableStringBuilder =
        SpannableStringBuilder(text).apply {
            setSpan(ForegroundColorSpan(color), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            // Kalın yazı kullanılmıyor (kullanıcı kararı): `bold` bayrağı yok sayılır.
        }

    private fun views(context: Context, data: Map<String, String>, plan: PushRenderPlan, tag: String,
                      expanded: Boolean, art: Art): RemoteViews {
        val view = RemoteViews(context.packageName, if (expanded) R.layout.push_expanded else R.layout.push_compact)
        val count = plan.count
        view.setTextViewText(R.id.push_title, plan.title)
        view.setTextViewText(R.id.push_body, plan.body)
        art.avatar?.let { view.setImageViewBitmap(R.id.push_avatar, it) }
        if (count > 1 && plan.chat) {
            val label = when (PushSpec.lang(data)) { "en" -> "$count new messages"; "ar" -> "$count رسائل جديدة"; else -> "$count yeni mesaj" }
            view.setViewVisibility(R.id.push_count, View.VISIBLE)
            view.setTextViewText(R.id.push_count, label)
        }
        if (!expanded) return view

        val brand = context.getColor(R.color.push_brand)
        val header = SpannableStringBuilder().append(span("BU Kampüs", brand, true))
        header.append(span("  ·  " + plan.source, context.getColor(R.color.push_muted), false))
        if (plan.critical) { view.setViewVisibility(R.id.push_critical, View.VISIBLE) }
        plan.headerFlag?.let { header.append(span("  ·  $it", brand, true)) }
        view.setTextViewText(R.id.push_section, header)
        plan.headerChip?.let {
            view.setViewVisibility(R.id.push_header_chip, View.VISIBLE); view.setTextViewText(R.id.push_header_chip, it)
        }
        plan.pill?.let {
            view.setViewVisibility(R.id.push_badge, View.VISIBLE); view.setTextViewText(R.id.push_badge, it)
            view.setInt(R.id.push_badge, "setBackgroundResource", PushArt.pillRes(plan.pillTone))
            view.setTextColor(R.id.push_badge, PushArt.toneFg(context, plan.pillTone))
        }
        plan.note?.let { note ->
            val sb = SpannableStringBuilder()
            sb.append(span(note.newTime, context.getColor(R.color.push_navy), true))
            val old = SpannableStringBuilder("  (${note.oldLabel}: ${note.oldTime})")
            old.setSpan(StrikethroughSpan(), 2, old.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            sb.append(old)
            view.setViewVisibility(R.id.push_note, View.VISIBLE); view.setTextViewText(R.id.push_note, sb)
        }
        if (art.thumb != null) {
            view.setViewVisibility(R.id.push_thumb, View.VISIBLE); view.setImageViewBitmap(R.id.push_thumb, art.thumb)
        }
        if (art.photo != null) {
            view.setViewVisibility(R.id.push_image, View.VISIBLE); view.setImageViewBitmap(R.id.push_image, art.photo)
            view.setInt(R.id.push_body, "setMaxLines", 2)
        }
        val chips = plan.chips
        if (chips.isNotEmpty()) {
            view.setViewVisibility(R.id.push_chips, View.VISIBLE)
            for ((index, id) in listOf(R.id.push_chip_one, R.id.push_chip_two).withIndex()) {
                val chip = chips.getOrNull(index) ?: continue
                view.setViewVisibility(id, View.VISIBLE); view.setTextViewText(id, chip.text)
                view.setInt(id, "setBackgroundResource", PushArt.pillRes(chip.tone))
                view.setTextColor(id, PushArt.toneFg(context, chip.tone))
            }
        }
        // Sohbet dugmeleri sistem Notification.Action olarak (gercek satir ici yanit); digerleri kartin pastel hapi.
        val actions = if (plan.systemActions) emptyList() else plan.actions.take(2)
        if (actions.isEmpty()) view.setViewVisibility(R.id.push_actions, View.GONE)
        for ((index, id) in listOf(R.id.push_action_one, R.id.push_action_two).withIndex()) {
            val action = actions.getOrNull(index) ?: continue
            view.setViewVisibility(id, View.VISIBLE)
            view.setTextViewText(id, action.label)
            view.setOnClickPendingIntent(id, actionIntent(context, data, action, tag))
        }
        return view
    }

    /** Avatar kaynagi: kisi gorseli (+ kose rozeti/sayac) ya da kategori ikon karosu; sohbette gorsel yoksa null (BU markasi). */
    private fun avatarBitmap(context: Context, plan: PushRenderPlan, person: Bitmap?): Bitmap? {
        val px = dp(context, 44)
        if (person != null) {
            val base = PushArt.circle(person, px)
            return PushArt.withBadge(context, base, plan.cornerBadge, if (plan.chat) plan.count else 1)
        }
        val tile = plan.tile ?: return null
        return PushArt.tile(context, tile, px)
    }

    private fun chatActions(context: Context, data: Map<String, String>, plan: PushRenderPlan): List<NotificationCompat.Action> =
        plan.actions.take(3).map { spec ->
            val builder = NotificationCompat.Action.Builder(IconCompat.createWithResource(context, R.drawable.ic_stat_bu), spec.label,
                if (spec.id == "reply") replyIntent(context, data, plan.tag) else actionIntent(context, data, spec, plan.tag))
            if (spec.id == "reply") {
                builder.addRemoteInput(CompatRemoteInput.Builder(KEY_REPLY).setLabel(spec.label).build())
                builder.setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
                // Ekran acmadan gonderilir; kilitliyken platform kilit acma ister (cihaz kurali).
                builder.setShowsUserInterface(false)
                builder.setAllowGeneratedReplies(true)
            }
            builder.build()
        }

    private fun label(data: Map<String, String>, tr: String, en: String, ar: String): String = when (PushSpec.lang(data)) {
        "en" -> en
        "ar" -> ar
        else -> tr
    }

    /** Kilit ekraninda gosterilecek genel kart (publicVersion): icerik yok, yalniz genel metin. */
    private fun publicNotification(context: Context, channel: String, text: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
        return builder.setSmallIcon(R.drawable.ic_stat_bu).setColor(Channels.ACCENT).setContentTitle("BÜ Kampüs")
            .setContentText(text).build()
    }

    private fun publicCompat(context: Context, channel: String, text: String): Notification =
        NotificationCompat.Builder(context, channel).setSmallIcon(R.drawable.ic_stat_bu).setColor(Channels.ACCENT)
            .setContentTitle("BÜ Kampüs").setContentText(text).build()

    /**
     * Karti cizer. Uygulama kapaliyken BuMessagingService (FCM) icinden, Flutter/Dart ACILMADAN cagrilir: once metinli kart
     * hemen yayinlanir (teslim medya indirmesine BAGLI degil); gorsel (avatar/kucuk resim) varsa awaitMedia ile sinirli sure
     * (<= ~3 sn) beklenir ve kart gorselle yenilenir. Indirme basarisizsa kart gorselsiz ama tam metinle kalir.
     * Sohbet mesajlari gercek MessagingStyle (showChat); diger turler ozel kart (RemoteViews). Ayni olay kimligi (nid/messageId)
     * ikinci kez cizilmez. Hata firlatabilir: cagiran showPlain ile yedekler.
     */
    fun show(context: Context, data: Map<String, String>, awaitMedia: Boolean = false) {
        if (data["title"].isNullOrBlank() && data["body"].isNullOrBlank()) return
        Channels.ensure(context)
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return
        val fallbackTag = UUID.randomUUID().toString()
        val provisional = PushRenderPlan.of(data, 1, System.currentTimeMillis(), fallbackTag)
        val tag = provisional.tag
        val message = data["messageId"]
        val eventId = (data["nid"] ?: message)?.takeIf { it.isNotBlank() }
        // Tekrar teslim / kapatilmis bildirimin ayni kimlikle yeniden gelmesi: bir kez gosterilir (kalici, sinirli kayit).
        if (eventId != null && !SeenStore.firstTime(context, provisional.style + ":" + eventId)) return
        if (provisional.chat) { showChat(context, manager, data, tag, awaitMedia); return }
        val count = 1
        val now = System.currentTimeMillis()
        val plan = PushRenderPlan.of(data, count, now, tag)
        val renderId = UUID.randomUUID().toString()
        val open = tap(context, data, "open", tag)
        val lock = PushPrivacy.lock(plan.style, false, PushSpec.lang(data), count)
        fun publish(person: Bitmap?, thumb: Bitmap?, photo: Bitmap?, quiet: Boolean) = synchronized(renderLock) {
            val art = Art(avatarBitmap(context, plan, person), thumb, photo)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, plan.channel) else Notification.Builder(context)
            builder.setSmallIcon(R.drawable.ic_stat_bu).setContentTitle(plan.title).setContentText(plan.body)
                .setColor(Channels.ACCENT).setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(quiet)
                // Guvenlik/hesap kartlari kilit ekraninda gizli (VISIBILITY_PRIVATE + genel metin); digerleri acik.
                .setVisibility(lock.visibility).setNumber(count).setGroup(plan.group)
                .setStyle(Notification.DecoratedCustomViewStyle())
                .setCustomContentView(views(context, data, plan, tag, false, art))
                .setCustomBigContentView(views(context, data, plan, tag, true, art))
                .setCustomHeadsUpContentView(views(context, data, plan, tag, false, art))
                .addExtras(android.os.Bundle().apply { putString("bu.messageId", message); putInt("bu.count", count); putString("bu.renderId", renderId) })
            lock.publicText?.let { builder.setPublicVersion(publicNotification(context, plan.channel, it)) }
            if (Build.VERSION.SDK_INT >= 26) builder.setGroupAlertBehavior(Notification.GROUP_ALERT_ALL)
            manager.notify(tag, 0, builder.build())
            postSummary(context, manager, plan.channel, plan.group, tag, PushSpec.lang(data))
        }
        publish(null, null, null, false)
        if (!plan.wantsAvatar && !plan.wantsImage) return
        // Medya isi bir iscide calisir: burada firlayan HICBIR hata (OOM dahil) yakalanmadan birakilamaz, aksi halde surec olur.
        // Metinli kart zaten yayinda; gorsel basarisizsa kart gorselsiz kalir (gerekirse duz kartla degistirilir).
        val job = Runnable {
            try {
                val person = bitmap(context, data["senderAvatarUrl"], 128)
                val picture = bitmap(context, data["imageUrl"], 512)
                val photo = if (plan.wideImage && picture != null) PushArt.roundedCrop(picture, dp(context, 320), dp(context, 107), dp(context, 12).toFloat()) else null
                val thumb = if (!plan.wideImage && picture != null) PushArt.roundedCrop(picture, dp(context, 56), dp(context, 56), dp(context, 12).toFloat()) else null
                synchronized(renderLock) {
                    val current = manager.activeNotifications.firstOrNull { it.tag == tag }?.notification
                    // Kapatilmis karti diriltmez, ayni etiketteki daha yeni bildirimin yerine gecmez.
                    if ((person != null || photo != null || thumb != null) && current?.extras?.getString("bu.renderId") == renderId) {
                        try { publish(person, thumb, photo, true) } catch (error: Throwable) {
                            android.util.Log.w("RichPush", "Media publish failed: " + error.javaClass.simpleName)
                            try { showPlain(context, data) } catch (_: Throwable) { }
                        }
                    }
                }
            } catch (error: Throwable) {
                android.util.Log.w("RichPush", "Media job failed: " + error.javaClass.simpleName)
            }
        }
        runMedia(job, awaitMedia)
    }

    private fun runMedia(job: Runnable, awaitMedia: Boolean) {
        if (awaitMedia) {
            // Servis yasadigi surece (onMessageReceived donene dek) sinirli bekleme: surec dondurulmeden gorsel yetisir.
            try { mediaWorker.submit(job).get(3, java.util.concurrent.TimeUnit.SECONDS) } catch (_: Throwable) { }
        } else mediaWorker.execute(job)
    }

    // ---- Sohbet: gercek MessagingStyle ----

    /**
     * Sohbet mesaji: ayni sohbetin (etiket = conv:<id>) pes pese mesajlari TEK bildirimde birikir (son 8, kalici sinirli depo),
     * ayni mesaj kimligi ikinci kez eklenmez. Bildirim tepsiden kalkmissa (kapatildi/dokunuldu) birikim sifirlanir.
     * Once metin bildirimi yayinlanir, avatar/fotograf indirilince ayni bildirim guncellenir (teslim medyaya bagli degil).
     */
    private fun showChat(context: Context, manager: NotificationManager, data: Map<String, String>, tag: String, awaitMedia: Boolean) {
        val now = System.currentTimeMillis()
        val active = try { manager.activeNotifications.any { it.tag == tag } } catch (_: Throwable) { true }
        val sender = data["senderName"]?.takeIf { it.isNotBlank() } ?: data["title"].orEmpty()
        val message = ChatMsg(
            id = data["messageId"]?.takeIf { it.isNotBlank() } ?: ("t:" + UUID.randomUUID()),
            senderKey = data["senderId"]?.takeIf { it.isNotBlank() } ?: sender, senderName = sender,
            text = data["body"].orEmpty(), atMs = now
        )
        val state = ChatHistoryStore.record(context, tag, message, reset = !active, nowMs = now) ?: return
        val renderId = UUID.randomUUID().toString()
        val wantsAvatar = !data["senderAvatarUrl"].isNullOrBlank()
        val wantsImage = !data["imageUrl"].isNullOrBlank()
        synchronized(renderLock) { notifyChat(context, manager, data, tag, state, null, false, ChatStatus.NORMAL, renderId) }
        if (!wantsAvatar && !wantsImage) return
        val job = Runnable {
            try {
                val avatar = bitmap(context, data["senderAvatarUrl"], 128)
                val picture = bitmap(context, data["imageUrl"], 512)
                avatar?.let { chatAvatars.put(message.senderKey, it) }
                if (avatar == null && picture == null) return@Runnable
                synchronized(renderLock) {
                    val current = manager.activeNotifications.firstOrNull { it.tag == tag }?.notification
                    if (current?.extras?.getString("bu.renderId") != renderId) return@synchronized
                    val latest = ChatHistoryStore.snapshot(context, tag) ?: return@synchronized
                    try { notifyChat(context, manager, data, tag, latest, picture, true, ChatStatus.NORMAL, renderId) } catch (error: Throwable) {
                        android.util.Log.w("RichPush", "Chat media publish failed: " + error.javaClass.simpleName)
                    }
                }
            } catch (error: Throwable) {
                android.util.Log.w("RichPush", "Chat media job failed: " + error.javaClass.simpleName)
            }
        }
        runMedia(job, awaitMedia)
    }

    private fun notifyChat(context: Context, manager: NotificationManager, data: Map<String, String>, tag: String, state: ChatState,
                           picture: Bitmap?, quiet: Boolean, status: ChatStatus, renderId: String) {
        val count = maxOf(state.total, data["count"]?.toIntOrNull() ?: 1, 1)
        val plan = PushRenderPlan.of(data, count, System.currentTimeMillis(), tag)
        manager.notify(tag, 0, buildChat(context, data, plan, tag, state, picture, quiet, status, renderId))
        postSummary(context, manager, plan.channel, plan.group, tag, PushSpec.lang(data))
    }

    private fun buildChat(context: Context, data: Map<String, String>, plan: PushRenderPlan, tag: String, state: ChatState,
                          picture: Bitmap?, quiet: Boolean, status: ChatStatus, renderId: String): Notification {
        val lang = PushSpec.lang(data)
        val group = data["conversationType"] == "GROUP" || plan.style == "CHAT_GROUP"
        val conversationTitle = (data["conversationTitle"]?.takeIf { it.isNotBlank() } ?: data["title"]).orEmpty()
        val last = state.messages.lastOrNull { !it.self } ?: state.messages.lastOrNull()
        val lock = PushPrivacy.lock(plan.style, PushPrivacy.hideRequested(data, PushPrefs.hidePreview(context)), lang, plan.count)
        val builder = NotificationCompat.Builder(context, plan.channel)
            .setSmallIcon(R.drawable.ic_stat_bu).setColor(Channels.ACCENT).setContentIntent(tap(context, data, "open", tag))
            .setAutoCancel(true).setOnlyAlertOnce(quiet).setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setNumber(plan.count).setGroup(plan.group).setVisibility(lock.visibility)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_ALL)
            .setDeleteIntent(goneIntent(context, tag))
            .addExtras(android.os.Bundle().apply {
                putString("bu.messageId", data["messageId"]); putInt("bu.count", plan.count); putString("bu.renderId", renderId)
            })
        last?.let { builder.setWhen(it.atMs).setShowWhen(true) }
        val avatarPx = dp(context, 48)
        val lastAvatar = last?.let { chatAvatars.get(it.senderKey) }
        if (!group && lastAvatar != null) builder.setLargeIcon(PushArt.circle(lastAvatar, avatarPx))
        if (picture != null && state.messages.size == 1 && last != null) {
            // Ilk/tek mesaj fotograf ya da video kapagi: genis onizleme (BigPicture). Sonraki mesajlar MessagingStyle'a doner.
            builder.setContentTitle(conversationTitle.ifEmpty { last.senderName }).setContentText(last.text)
                .setStyle(NotificationCompat.BigPictureStyle().bigPicture(picture).setSummaryText(last.text))
        } else {
            val me = Person.Builder().setName(label(data, "Sen", "You", "أنت")).setKey("bu.self").build()
            val style = NotificationCompat.MessagingStyle(me)
            if (group) style.setConversationTitle(conversationTitle).setGroupConversation(true)
            else style.setGroupConversation(false)
            for (m in state.messages) {
                val person: Person? = if (m.self) null else {
                    val pb = Person.Builder().setName(m.senderName.ifEmpty { conversationTitle }).setKey(m.senderKey)
                    chatAvatars.get(m.senderKey)?.let { pb.setIcon(IconCompat.createWithBitmap(PushArt.circle(it, avatarPx))) }
                    pb.build()
                }
                style.addMessage(NotificationCompat.MessagingStyle.Message(m.text, m.atMs, person))
            }
            builder.setStyle(style).setContentTitle(conversationTitle.ifEmpty { last?.senderName.orEmpty() }).setContentText(last?.text.orEmpty())
        }
        when (status) {
            ChatStatus.SENDING -> builder.setProgress(0, 0, true).setSubText(label(data, "Gönderiliyor…", "Sending…", "جارٍ الإرسال…"))
            ChatStatus.RETRYING -> builder.setSubText(label(data, "Gönderilemedi, yeniden denenecek", "Not sent, will retry", "لم يُرسل، ستتم إعادة المحاولة"))
            ChatStatus.NORMAL -> Unit
        }
        chatActions(context, data, plan).forEach { builder.addAction(it) }
        lock.publicText?.let { builder.setPublicVersion(publicCompat(context, plan.channel, it)) }
        return builder.build()
    }

    /**
     * Yanit gonderim durumu: kullanicinin yaniti sohbete eklenir ("Sen: ...") ve bildirim "Gonderiliyor"/"yeniden denenecek"
     * olarak yenilenir (sessiz). Kullanici bu arada bildirimi kapattiysa yeniden diriltilmez (yalniz yeniden deneme durumunda).
     */
    fun showChatState(context: Context, data: Map<String, String>, tag: String, status: ChatStatus, entry: ReplyEntry?) {
        synchronized(renderLock) {
            try {
                Channels.ensure(context)
                val manager = context.getSystemService(NotificationManager::class.java) ?: return
                val now = System.currentTimeMillis()
                val active = try { manager.activeNotifications.any { it.tag == tag } } catch (_: Throwable) { true }
                if (status == ChatStatus.RETRYING && !active) return
                var state = ChatHistoryStore.snapshot(context, tag)
                if (state == null) {
                    val sender = data["senderName"]?.takeIf { it.isNotBlank() } ?: data["title"].orEmpty()
                    val original = ChatMsg(data["messageId"]?.takeIf { it.isNotBlank() } ?: ("t:" + UUID.randomUUID()),
                        data["senderId"]?.takeIf { it.isNotBlank() } ?: sender, sender, data["body"].orEmpty(), now)
                    state = ChatHistoryStore.record(context, tag, original, reset = true, nowMs = now)
                }
                if (entry != null) {
                    val own = ChatMsg("r:" + entry.clientId, "bu.self", "", entry.text, now, self = true)
                    state = ChatHistoryStore.record(context, tag, own, reset = false, nowMs = now) ?: state
                }
                val current = state ?: return
                notifyChat(context, manager, data, tag, current, null, true, status, UUID.randomUUID().toString())
            } catch (error: Throwable) {
                android.util.Log.w("RichPush", "Chat state failed: " + error.javaClass.simpleName)
            }
        }
    }

    /** Bos/bozuk yanit: ilerleme halkasini temizlemek icin mevcut bildirimi yeniden yayinlar. */
    fun refresh(context: Context, tag: String) {
        try {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            manager.activeNotifications.firstOrNull { it.tag == tag }?.let { manager.notify(tag, 0, it.notification) }
        } catch (_: Throwable) { }
    }

    /**
     * Zengin cizim hata verirse bile bildirim KAYBOLMASIN: duz baslik/govde karti (kanal + dokunus niyeti; gorsel/cip/aksiyon yok).
     * Guvenlik/hesap turlerinde kilit ekraninda icerik yine gizlidir. Kendisi de hata verirse cagiran yakalar.
     */
    fun showPlain(context: Context, data: Map<String, String>) {
        val title = data["title"].orEmpty()
        val body = data["body"].orEmpty()
        if (title.isBlank() && body.isBlank()) return
        Channels.ensure(context)
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return
        val style = PushSpec.style(data)
        val channel = PushRenderPlan.channelFor(data, style)
        val tag = data["tag"] ?: data["collapseKey"] ?: data["messageId"]?.let { "message:$it" } ?: UUID.randomUUID().toString()
        val lock = PushPrivacy.lock(style, PushPrivacy.hideRequested(data, PushPrefs.hidePreview(context)), PushSpec.lang(data))
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_stat_bu).setColor(Channels.ACCENT).setContentTitle(title).setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body)).setAutoCancel(true).setVisibility(lock.visibility)
            .setContentIntent(tap(context, data, "open", tag))
        lock.publicText?.let { builder.setPublicVersion(publicNotification(context, channel, it)) }
        manager.notify(tag, 0, builder.build())
    }

    /** Ayni kanalda >= 2 bildirim varsa tek ozet (setGroupSummary) yayinlanir; sistem ozetin altinda yigar. */
    private fun postSummary(context: Context, manager: NotificationManager, channel: String, group: String, newTag: String, lang: String) {
        try {
            val active = manager.activeNotifications
            val children = active.filter { it.notification.group == group && (it.notification.flags and Notification.FLAG_GROUP_SUMMARY) == 0 }
            val total = children.size + if (children.any { it.tag == newTag }) 0 else 1
            if (total < 2) return
            val summaryTag = "summary:$group"
            val open = openIntent(context, JSONObject().put("notificationAction", "open").put("notificationTag", summaryTag)
                .put("actionId", UUID.randomUUID().toString()).toString(), summaryTag, "open")
            val label = "BÜ Kampüs"
            val text = if (channel == "chat") when (lang) {
                "en" -> "New messages in $total chats"
                "ar" -> "رسائل جديدة في $total محادثات"
                else -> "$total sohbette yeni mesaj"
            } else when (lang) {
                "en" -> "$total notifications"
                "ar" -> "$total إشعارات"
                else -> "$total bildirim"
            }
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
            builder.setSmallIcon(R.drawable.ic_stat_bu).setColor(Channels.ACCENT).setContentTitle(label)
                .setContentText(text)
                .setContentIntent(open).setAutoCancel(true).setGroup(group).setGroupSummary(true)
                .setStyle(Notification.InboxStyle().setSummaryText(label))
            // Guvenlik ozeti kilit ekraninda icerik gostermez; sohbet ozeti yalniz sayi icerir (onizleme degil).
            if (channel == "security") builder.setVisibility(Notification.VISIBILITY_PRIVATE)
            if (Build.VERSION.SDK_INT >= 26) builder.setGroupAlertBehavior(Notification.GROUP_ALERT_CHILDREN)
            manager.notify(summaryTag, 0, builder.build())
        } catch (_: Exception) { }
    }

    /** Alt bildirimi kalmayan ozetleri kaldirir (sistem bazen birakir). */
    private fun pruneSummaries(manager: NotificationManager) {
        try {
            val active = manager.activeNotifications
            active.filter { (it.notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0 && it.tag?.startsWith("summary:") == true }.forEach { summary ->
                val group = summary.notification.group
                if (active.none { it.notification.group == group && (it.notification.flags and Notification.FLAG_GROUP_SUMMARY) == 0 }) manager.cancel(summary.tag, 0)
            }
        } catch (_: Exception) { }
    }

    /**
     * Satir ici yanit: metin RemoteInput'tan alinir ve KALICI kuyruga yazilir (ReplyDispatcher): canli Flutter motoru varsa ekran
     * acilmadan Dart'a, yoksa basliksiz Dart motoruyla (JobScheduler) gonderilir; ag hatasinda ustel geri cekilmeyle yeniden denenir.
     * Sabit clientId ile sunucuda tekildir. Kesin basarisizlikta "dokunarak gonder" bildirimine duser (replyFailedFor).
     */
    fun reply(context: Context, intent: Intent, tag: String, pending: BroadcastReceiver.PendingResult) {
        try {
            val app = context.applicationContext
            val text = CompatRemoteInput.getResultsFromIntent(intent)?.getCharSequence(KEY_REPLY)?.toString()?.trim().orEmpty()
            val data = runCatching {
                val o = JSONObject(intent.getStringExtra("payload").orEmpty())
                o.keys().asSequence().associateWith { o.optString(it) }
            }.getOrNull()
            if (data == null || text.isEmpty() || text.length > ReplyQueueLogic.MAX_TEXT) {
                refresh(app, tag)
                pending.finish(); return
            }
            ReplyDispatcher.submit(app, data, text, tag, pending)
        } catch (error: Throwable) {
            android.util.Log.w("RichPush", "Reply failed: " + error.javaClass.simpleName)
            try { pending.finish() } catch (_: Throwable) { }
        }
    }

    /** Kuyruk kesin basarisiz: AYNI clientId ile "dokunarak gonder" bildirimi (sunucuda tekil, cift mesaj olmaz). */
    fun replyFailedFor(context: Context, data: Map<String, String>, entry: ReplyEntry) {
        val payload = data + mapOf("notificationAction" to "reply", "notificationTag" to entry.tag, "actionId" to entry.clientId,
            "replyText" to entry.text)
        replyFailed(context, data, entry.tag, payload)
    }

    private fun replyFailed(context: Context, data: Map<String, String>, tag: String, payload: Map<String, String>) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        Channels.ensure(context)
        val channel = data["channelId"]?.takeIf { it in PushRenderPlan.CHANNELS } ?: "chat"
        val json = JSONObject(payload).toString()
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
        val failed = when (PushSpec.lang(data)) {
            "en" -> "Reply not sent. Tap to send it from the app."
            "ar" -> "لم يتم إرسال الرد. اضغط لإرساله من التطبيق."
            else -> "Yanıt gönderilemedi. Uygulamadan göndermek için dokunun."
        }
        builder.setSmallIcon(R.drawable.ic_stat_bu).setColor(Channels.ACCENT).setContentTitle(data["title"]).setContentText(failed)
            .setStyle(Notification.BigTextStyle().bigText(failed))
            .setContentIntent(openIntent(context, json, tag, "reply")).setAutoCancel(true).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
        manager.notify(tag, 0, builder.build())
    }

    /** Signed HTTPS thumbnails only, bounded I/O and decoded pixels; no authorization tokens are stored here. */
    private fun bitmap(context: Context, raw: String?, maxSide: Int): Bitmap? {
        if (raw.isNullOrBlank() || !raw.startsWith("https://")) return null
        val url = runCatching { URL(raw) }.getOrNull() ?: return null
        if (!imageHostAllowed(context, url.host)) return null
        cache.get(raw)?.let { return it }
        return runCatching {
            val connection = url.openConnection() as HttpURLConnection
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
                val options = BitmapFactory.Options().apply { inSampleSize = maxOf(1, maxOf(bounds.outWidth, bounds.outHeight) / maxSide) }
                val image = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return null
                cache.put(raw, image); image
            } finally { connection.disconnect() }
        }.getOrNull()
    }
}
