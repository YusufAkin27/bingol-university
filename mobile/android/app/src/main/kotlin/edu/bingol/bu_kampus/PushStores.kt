package edu.bingol.bu_kampus

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Bildirim durumunun kalici (uygulama ozel SharedPreferences) katmani. Mantik saf siniflardadir (ChatHistory.kt,
 * ReplyQueueLogic.kt); burasi yalniz JSON <-> depo. Bozuk kayit sessizce atilir (cokme yok). Mesaj METNI log'a YAZILMAZ.
 * Yedekleme kapali (allowBackup=false); cikista/hesap degisiminde [PushStores.clearAll] hepsini siler.
 */
object PushStores {
    fun clearAll(c: Context) {
        ChatHistoryStore.clearAll(c)
        ReplyStore.clear(c)
    }
}

/** Bildirim gizlilik tercihi (Dart `bu_kampus/notif_settings.setHidePreview`). Varsayilan KAPALI = onizleme gorunur. */
object PushPrefs {
    private const val PREFS = "bu_push_account"
    const val KEY_HIDE_PREVIEW = "bu.pref.hide_preview"

    fun hidePreview(c: Context): Boolean =
        c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_HIDE_PREVIEW, false)

    fun setHidePreview(c: Context, value: Boolean) {
        c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_HIDE_PREVIEW, value).apply()
    }
}

/** Sohbet basina (anahtar = bildirim etiketi) mesaj birikimi. */
object ChatHistoryStore {
    private const val PREFS = "bu_chat_history"
    private const val KEY = "all"
    private val lock = Any()

    private fun prefs(c: Context) = c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun toJson(s: ChatState): JSONObject {
        val arr = JSONArray()
        s.messages.forEach { m ->
            arr.put(JSONObject().put("i", m.id).put("k", m.senderKey).put("n", m.senderName).put("x", m.text)
                .put("a", m.atMs).put("s", m.self))
        }
        return JSONObject().put("t", s.total).put("u", s.updatedMs).put("m", arr)
    }

    private fun fromJson(o: JSONObject): ChatState {
        val arr = o.optJSONArray("m") ?: JSONArray()
        val list = ArrayList<ChatMsg>()
        for (i in 0 until arr.length()) {
            val m = arr.optJSONObject(i) ?: continue
            val id = m.optString("i")
            if (id.isEmpty()) continue
            list.add(ChatMsg(id, m.optString("k"), m.optString("n"), m.optString("x"), m.optLong("a"), m.optBoolean("s")))
        }
        return ChatState(o.optInt("t"), list, o.optLong("u"))
    }

    private fun loadAll(c: Context): Map<String, ChatState> {
        val raw = prefs(c).getString(KEY, null) ?: return emptyMap()
        return try {
            val o = JSONObject(raw)
            val out = LinkedHashMap<String, ChatState>()
            for (k in o.keys()) out[k] = fromJson(o.getJSONObject(k))
            out
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun saveAll(c: Context, all: Map<String, ChatState>) {
        val o = JSONObject()
        all.forEach { (k, v) -> o.put(k, toJson(v)) }
        prefs(c).edit().putString(KEY, o.toString()).apply()
    }

    /** Mesaji kaydeder. Doner: yeni durum; ayni mesaj kimligi zaten varsa (tekrar teslim) null. */
    fun record(c: Context, key: String, msg: ChatMsg, reset: Boolean, nowMs: Long = System.currentTimeMillis()): ChatState? =
        synchronized(lock) {
            val all = LinkedHashMap(loadAll(c))
            val (state, added) = ChatHistoryLogic.record(all[key], msg, nowMs, reset)
            if (!added) return@synchronized null
            all[key] = state
            saveAll(c, ChatHistoryLogic.prune(all, nowMs))
            state
        }

    fun snapshot(c: Context, key: String): ChatState? = synchronized(lock) { loadAll(c)[key] }

    fun clear(c: Context, key: String) = synchronized(lock) {
        val all = LinkedHashMap(loadAll(c))
        if (all.remove(key) != null) saveAll(c, all)
    }

    fun clearAll(c: Context) = synchronized(lock) { prefs(c).edit().remove(KEY).apply() }
}

/** Gorulmus olay kimlikleri (kapatilmis bildirimin ayni kimlikle yeniden cizilmesini engeller). */
object SeenStore {
    private const val PREFS = "bu_push_seen"
    private const val KEY = "ids"
    private val lock = Any()

    /** true: kimlik ilk kez goruldu (kaydedildi); false: daha once islendi. Bos kimlik her zaman true. */
    fun firstTime(c: Context, id: String): Boolean = synchronized(lock) {
        if (id.isEmpty()) return@synchronized true
        val p = c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val list = (p.getString(KEY, "") ?: "").split('\n').filter { it.isNotEmpty() }
        val (next, fresh) = SeenIds.add(list, id)
        if (fresh) p.edit().putString(KEY, next.joinToString("\n")).apply()
        fresh
    }

    fun clear(c: Context) = synchronized(lock) {
        c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }
}

/** Kalici yanit kuyrugu. */
object ReplyStore {
    private const val PREFS = "bu_reply_queue"
    private const val KEY = "q"
    private val lock = Any()

    private fun prefs(c: Context) = c.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun load(c: Context): List<ReplyEntry> {
        val raw = prefs(c).getString(KEY, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            val out = ArrayList<ReplyEntry>()
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val id = o.optString("c")
                if (id.isEmpty()) continue
                out.add(ReplyEntry(
                    clientId = id, tag = o.optString("g"), conversationId = o.optString("v"),
                    replyToMessageId = o.optString("r").ifEmpty { null }, text = o.optString("x"),
                    recipientId = o.optString("u").ifEmpty { null }, dataJson = o.optString("d"),
                    createdMs = o.optLong("t"), attempts = o.optInt("n"), nextAtMs = o.optLong("w"),
                    state = if (o.optString("s") == "F") ReplyState.FAILED else ReplyState.PENDING
                ))
            }
            out
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun save(c: Context, list: List<ReplyEntry>) {
        val arr = JSONArray()
        list.forEach { e ->
            arr.put(JSONObject().put("c", e.clientId).put("g", e.tag).put("v", e.conversationId)
                .put("r", e.replyToMessageId ?: "").put("x", e.text).put("u", e.recipientId ?: "").put("d", e.dataJson)
                .put("t", e.createdMs).put("n", e.attempts).put("w", e.nextAtMs)
                .put("s", if (e.state == ReplyState.FAILED) "F" else "P"))
        }
        prefs(c).edit().putString(KEY, arr.toString()).apply()
    }

    fun snapshot(c: Context): List<ReplyEntry> = synchronized(lock) { load(c) }

    /** Okuma-degistirme-yazma tek kilit altinda; yeni listeyi dondurur. */
    fun mutate(c: Context, change: (List<ReplyEntry>) -> List<ReplyEntry>): List<ReplyEntry> = synchronized(lock) {
        val next = change(load(c))
        save(c, next)
        next
    }

    fun clear(c: Context) = synchronized(lock) { prefs(c).edit().remove(KEY).apply() }
}
