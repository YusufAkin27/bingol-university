package edu.bingol.bu_kampus

/**
 * Sohbet bildirimi birikiminin SAF (android bagimsiz) mantigi. Ayni sohbetten pes pese gelen mesajlar tek bildirimde
 * (MessagingStyle) son [ChatHistoryLogic.LIMIT] mesaj olarak birikir. Birim testi: ChatHistoryTest.
 * Mesaj METNI log'a yazilmaz; kalicilik katmani (ChatHistoryStore) yalniz uygulama ozel deposuna yazar.
 */
data class ChatMsg(
    /** Sunucu mesaj kimligi (ya da kimlik yoksa uretilmis benzersiz anahtar): tekrar eklemeyi engeller. */
    val id: String,
    val senderKey: String,
    val senderName: String,
    val text: String,
    val atMs: Long,
    /** Kullanicinin kendi (satir ici yanit) mesaji. */
    val self: Boolean = false
)

/** [total]: son temizlikten beri gelen toplam mesaj sayisi (liste sinirlidir, sayac degil). */
data class ChatState(val total: Int, val messages: List<ChatMsg>, val updatedMs: Long)

object ChatHistoryLogic {
    const val LIMIT = 8
    const val MAX_CONVERSATIONS = 20
    const val MAX_TEXT = 500
    /** Bu surenin disindaki birikim bayat sayilir (bildirim zaten gitmistir): yeniden baslar. */
    const val STALE_MS = 24L * 60 * 60 * 1000

    /**
     * Mesaji ekler. Doner: (yeni durum, eklendi mi). Ayni kimlik zaten varsa (tekrar teslim) durum DEGISMEZ ve false doner.
     * [reset] true ise (tepside bildirim yok) birikim sifirdan baslar.
     */
    fun record(state: ChatState?, msg: ChatMsg, nowMs: Long, reset: Boolean = false): Pair<ChatState, Boolean> {
        val clean = msg.copy(text = msg.text.take(MAX_TEXT))
        val base = if (reset || state == null || nowMs - state.updatedMs > STALE_MS) null else state
        if (base != null && base.messages.any { it.id == clean.id }) return Pair(base, false)
        val list = ((base?.messages ?: emptyList()) + clean).takeLast(LIMIT)
        // Kendi yanitimiz "yeni mesaj" sayilmaz (okunmamis sayaci okunmus durumda kalir).
        val total = (base?.total ?: 0) + if (clean.self) 0 else 1
        return Pair(ChatState(total, list, nowMs), true)
    }

    /** Eski birikimleri atar ve sayiyi [MAX_CONVERSATIONS] ile sinirlar (en yeniler kalir). */
    fun prune(all: Map<String, ChatState>, nowMs: Long): Map<String, ChatState> =
        all.filter { nowMs - it.value.updatedMs <= STALE_MS }.entries
            .sortedByDescending { it.value.updatedMs }.take(MAX_CONVERSATIONS).associate { it.key to it.value }
}

/** Gorulmus mesaj/olay kimlikleri (kapatilan bildirimin ayni kimlikle yeniden gelmesini engeller). Sinirli, en yeni sonda. */
object SeenIds {
    const val CAP = 64

    /** Doner: (yeni liste, yeni mi). Zaten varsa liste degismez ve false doner. */
    fun add(list: List<String>, id: String): Pair<List<String>, Boolean> {
        if (id.isEmpty()) return Pair(list, true)
        if (list.contains(id)) return Pair(list, false)
        return Pair((list + id).takeLast(CAP), true)
    }
}
