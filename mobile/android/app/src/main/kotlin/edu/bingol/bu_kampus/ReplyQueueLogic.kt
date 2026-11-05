package edu.bingol.bu_kampus

/**
 * Satir ici yanit kuyrugunun SAF mantigi (android bagimsiz). Yanit kalici kuyruga yazilir; gonderim (canli Flutter motoru
 * ya da basliksiz Dart motoru) sonucuna gore silinir, ustel geri cekilmeyle yeniden denenir ya da kesin basarisiz sayilir.
 * `clientId` yanitin ilk anda uretilen sabit kimligidir: sunucu ayni clientId'yi tekil sayar, yeniden deneme cift mesaj uretmez.
 * Birim testi: ReplyQueueLogicTest.
 */
enum class ReplyState { PENDING, FAILED }

enum class ReplyOutcome { OK, RETRY, FAIL }

data class ReplyEntry(
    val clientId: String,
    val tag: String,
    val conversationId: String,
    val replyToMessageId: String?,
    val text: String,
    val recipientId: String?,
    /** Bildirimi yeniden cizmek icin kisaltilmis yuk (JSON metni; yalnizca gerekli alanlar). */
    val dataJson: String,
    val createdMs: Long,
    val attempts: Int = 0,
    val nextAtMs: Long = 0,
    val state: ReplyState = ReplyState.PENDING
)

object ReplyQueueLogic {
    const val MAX_ATTEMPTS = 5
    const val MAX_ENTRIES = 20
    /** Bu kadar eski yanit bayat: gonderilmez (ugurlu olmayan "gec kalmis" mesaj). */
    const val EXPIRE_MS = 6L * 60 * 60 * 1000
    const val MAX_TEXT = 4000

    private val BACKOFF_MS = longArrayOf(15_000, 60_000, 5 * 60_000, 30 * 60_000, 2 * 60 * 60_000)

    /** [attempt]: tamamlanan deneme sayisi (1 = ilk deneme basarisiz). Ustel/kademeli: 15 sn, 1 dk, 5 dk, 30 dk, 2 sa. */
    fun backoffMs(attempt: Int): Long = BACKOFF_MS[(attempt - 1).coerceIn(0, BACKOFF_MS.size - 1)]

    /** Bos/asiri uzun metin kuyruga alinmaz (null). Ayni clientId zaten varsa mevcut liste degismeden doner. */
    fun enqueue(list: List<ReplyEntry>, entry: ReplyEntry, nowMs: Long): List<ReplyEntry> {
        val text = entry.text.trim()
        if (text.isEmpty() || text.length > MAX_TEXT) return list
        if (list.any { it.clientId == entry.clientId }) return list
        val live = prune(list, nowMs)
        return (live + entry.copy(text = text)).takeLast(MAX_ENTRIES)
    }

    /** Suresi dolanlari atar (FAILED kayitlar da bayatlayinca silinir). */
    fun prune(list: List<ReplyEntry>, nowMs: Long): List<ReplyEntry> = list.filter { nowMs - it.createdMs <= EXPIRE_MS }

    /** Zamani gelmis, hala beklemede olanlar (en eskiden yeniye). */
    fun due(list: List<ReplyEntry>, nowMs: Long): List<ReplyEntry> =
        list.filter { it.state == ReplyState.PENDING && it.nextAtMs <= nowMs && nowMs - it.createdMs <= EXPIRE_MS }
            .sortedBy { it.createdMs }

    /** Sonraki uyanma zamani (beklemede kayit yoksa null). */
    fun nextWake(list: List<ReplyEntry>): Long? = list.filter { it.state == ReplyState.PENDING }.minOfOrNull { it.nextAtMs }

    /**
     * Deneme sonucunu isler. OK: kayit silinir. FAIL: kesin basarisiz (yeniden denenmez). RETRY: deneme sayisi artar,
     * geri cekilme uygulanir; [MAX_ATTEMPTS] dolarsa FAILED.
     */
    fun apply(list: List<ReplyEntry>, clientId: String, outcome: ReplyOutcome, nowMs: Long): List<ReplyEntry> =
        list.mapNotNull { e ->
            if (e.clientId != clientId) return@mapNotNull e
            when (outcome) {
                ReplyOutcome.OK -> null
                ReplyOutcome.FAIL -> e.copy(attempts = e.attempts + 1, state = ReplyState.FAILED)
                ReplyOutcome.RETRY -> {
                    val attempts = e.attempts + 1
                    if (attempts >= MAX_ATTEMPTS) e.copy(attempts = attempts, state = ReplyState.FAILED)
                    else e.copy(attempts = attempts, nextAtMs = nowMs + backoffMs(attempts))
                }
            }
        }
}
