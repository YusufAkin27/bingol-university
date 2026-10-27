package edu.bingol.backend.messaging;

import edu.bingol.backend.messaging.dto.MessagingDtos;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReactionCount;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReplyPreview;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import edu.bingol.backend.messaging.media.AttachmentView;
import edu.bingol.backend.messaging.media.MessageAttachmentService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * Mesaj gorunumlerini toplu zenginlestirir (yanit onizlemesi + tepki sayaclari): sayfa basina sabit sayida sorgu.
 * Onizleme cozulmus kisa metindir; yalnizca ayni konusmanin ve gorunur (katilma oncesi olmayan) mesajlari kullanilir.
 */
@Component
public class MessageViewAssembler {

    public static final int PREVIEW_LENGTH = 100;

    private final MessageRepository messages;
    private final MessageReactionRepository reactions;
    private final MessageCodec codec;

    /** T8: gorsel ekleri (setter enjeksiyonu: yapici imzasi degismesin; yoksa eksiz). */
    private MessageAttachmentService attachments;

    /** Makbuz durumu (setter enjeksiyonu; yoksa durum null). */
    private ReceiptService receipts;

    @Autowired(required = false)
    void setReceipts(ReceiptService receipts) {
        this.receipts = receipts;
    }

    @Autowired(required = false)
    void setAttachments(MessageAttachmentService attachments) {
        this.attachments = attachments;
    }

    public MessageViewAssembler(MessageRepository messages, MessageReactionRepository reactions, MessageCodec codec) {
        this.messages = messages;
        this.reactions = reactions;
        this.codec = codec;
    }

    /**
     * @param opened          govde cozulmus mesajlar
     * @param blockedSenders  goruntuleyenle engel iliskisi olan gondericiler (kendi mesaji haric tutulur)
     * @param since           grupta uyenin katilma zamani (oncesindeki yanit hedefi gosterilmez); yoksa null
     */
    public List<MessageView> assemble(Long viewerId, List<Message> opened, Set<Long> blockedSenders, Instant since) {
        if (opened.isEmpty()) {
            return List.of();
        }
        List<Long> ids = opened.stream().map(Message::getId).toList();
        Map<Long, List<ReactionCount>> counts = new HashMap<>();
        for (Object[] row : reactions.counts(ids)) {
            counts.computeIfAbsent((Long) row[0], k -> new ArrayList<>())
                    .add(new ReactionCount((String) row[1], ((Number) row[2]).longValue()));
        }
        Map<Long, String> mine = reactions.mine(viewerId, ids).stream()
                .collect(Collectors.toMap(MessageReaction::getMessageId, MessageReaction::getEmoji, (a, b) -> a));

        Set<Long> parentIds = new LinkedHashSet<>();
        opened.forEach(m -> {
            if (m.getReplyToMessageId() != null && !m.isDeleted()) {
                parentIds.add(m.getReplyToMessageId());
            }
        });
        Map<Long, Message> parents = parentIds.isEmpty() ? Map.of()
                : messages.findAllById(parentIds).stream().collect(Collectors.toMap(Message::getId, Function.identity()));
        codec.openAll(new ArrayList<>(parents.values()));

        Map<Long, List<AttachmentView>> att = attachments == null ? Map.of() : attachments.viewsFor(viewerId, ids);
        Map<Long, String> status = receipts == null ? Map.of() : receipts.statuses(viewerId, opened, null, null);
        List<MessageView> out = new ArrayList<>(opened.size());
        for (Message m : opened) {
            boolean blocked = blockedSenders.contains(m.getSenderId()) && !m.getSenderId().equals(viewerId);
            MessageView v = MessageView.of(m, blocked);
            ReplyPreview preview = null;
            if (m.getReplyToMessageId() != null && !m.isDeleted()) {
                preview = preview(parents.get(m.getReplyToMessageId()), m.getConversationId(), viewerId, blockedSenders, since,
                        m.getReplyToMessageId());
            }
            out.add(v.withExtras(blocked ? null : preview, blocked || m.isDeleted() ? List.of()
                    : counts.getOrDefault(m.getId(), List.of()), mine.get(m.getId())).withAttachments(blocked ? null : att.get(m.getId()))
                    .withStatus(status.get(m.getId())));
        }
        return out;
    }

    private static ReplyPreview preview(Message p, Long conversationId, Long viewerId, Set<Long> blockedSenders,
                                        Instant since, Long requestedId) {
        // Baska konusmanin ya da katilma oncesi mesaj: icerik sizdirilmaz
        if (p == null || !p.getConversationId().equals(conversationId)
                || (since != null && p.getCreatedAt().isBefore(since))) {
            return new ReplyPreview(requestedId, null, null, false);
        }
        if (p.isHidden() || p.isDeleted()) {
            return new ReplyPreview(p.getId(), p.getSenderId(),
                    p.isDeleted() ? MessagingDtos.DELETED_TEXT : MessagingDtos.REMOVED_TEXT, true);
        }
        if (blockedSenders.contains(p.getSenderId()) && !p.getSenderId().equals(viewerId)) {
            return new ReplyPreview(p.getId(), p.getSenderId(), MessagingDtos.BLOCKED_TEXT, false);
        }
        String body = p.getBody();
        return new ReplyPreview(p.getId(), p.getSenderId(), body == null ? MessagingDtos.UNREADABLE_TEXT : truncate(body), false);
    }

    static String truncate(String s) {
        if (s.codePointCount(0, s.length()) <= PREVIEW_LENGTH) {
            return s;
        }
        return s.substring(0, s.offsetByCodePoints(0, PREVIEW_LENGTH)) + "…";
    }
}
