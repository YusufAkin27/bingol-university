package edu.bingol.bu_kampus

/**
 * Bir bildirim kartinin tum cizim kararlari TEK, android/Flutter bagimsiz modelde. `FirebaseMessagingService`
 * (uygulama kapaliyken, Dart acilmadan) bu plani uretir; RemoteViews yalniz plani cizer. Birim testi: PushRenderPlanTest.
 * Kural: veri yoksa oge yok (uydurma yok); aksiyonun gercek islevi olmali (PushSpec.actions).
 */
data class PushRenderPlan(
    val style: String,
    val chat: Boolean,
    val channel: String,
    val group: String,
    val tag: String,
    val title: String,
    val body: String,
    val count: Int,
    val source: String,
    val critical: Boolean,
    val headerFlag: String?,
    val headerChip: String?,
    val pill: String?,
    val pillTone: Tone,
    val note: NoteSpec?,
    val chips: List<ChipSpec>,
    /** Sohbet: sistem Notification.Action (gercek satir ici yanit); digerleri kartin icinde hap dugmesi. */
    val systemActions: Boolean,
    val actions: List<ActionSpec>,
    val tile: IconSpec?,
    val cornerBadge: Glyph?,
    val wideImage: Boolean,
    val wantsAvatar: Boolean,
    val wantsImage: Boolean
) {
    companion object {
        val CHANNELS = setOf("chat", "event", "announcement", "social", "poll", "academic")

        fun of(data: Map<String, String>, count: Int, nowMs: Long, fallbackTag: String): PushRenderPlan {
            val style = PushSpec.style(data)
            val chat = PushSpec.isChat(style)
            val channel = data["channelId"]?.takeIf { it in CHANNELS } ?: "announcement"
            val badge = PushSpec.titlePill(data, style, nowMs)
            val tag = data["tag"] ?: data["collapseKey"] ?: data["messageId"]?.let { "message:$it" } ?: fallbackTag
            return PushRenderPlan(
                style = style, chat = chat, channel = channel, group = "bu.$channel", tag = tag,
                title = data["title"].orEmpty(), body = data["body"].orEmpty(), count = count,
                source = PushSpec.source(data, style),
                critical = PushSpec.isCritical(data),
                headerFlag = badge.flag,
                headerChip = PushSpec.headerChip(data, style, nowMs),
                pill = badge.pill, pillTone = badge.pillTone,
                note = PushSpec.note(data, style),
                chips = PushSpec.chips(data, style, nowMs),
                systemActions = chat,
                actions = PushSpec.actions(data, style, count, nowMs),
                tile = PushSpec.tile(style),
                cornerBadge = PushSpec.cornerBadge(style, count),
                wideImage = PushSpec.wideImage(style),
                wantsAvatar = !data["senderAvatarUrl"].isNullOrBlank(),
                wantsImage = !data["imageUrl"].isNullOrBlank()
            )
        }
    }
}
