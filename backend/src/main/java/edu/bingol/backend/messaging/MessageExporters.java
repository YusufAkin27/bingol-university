package edu.bingol.backend.messaging;

import edu.bingol.backend.export.DataExporter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.PageRequest;

/** KVKK "verilerimi indir": kullanicinin kendi gonderdigi mesajlar, sifresi cozulmus olarak (en yeni 5000). */
@Configuration
public class MessageExporters {

    static final int MAX_EXPORT = 5000;

    /** KVKK: kullanicinin verdigi tepkiler (mesaj icerigi icermez) ve konusma tercihleri. */
    @Bean
    DataExporter messageReactionExporter(MessageReactionRepository reactions, MessageRepository messages,
                                         ConversationMemberRepository members) {
        return DataExporter.of("messageReactions", uid -> {
            List<MessageReaction> rows = reactions.givenBy(uid, PageRequest.of(0, MAX_EXPORT));
            Map<Long, Long> convOf = new java.util.HashMap<>();
            messages.findAllById(rows.stream().map(MessageReaction::getMessageId).toList())
                    .forEach(m -> convOf.put(m.getId(), m.getConversationId()));
            List<Map<String, Object>> out = rows.stream().map(r -> {
                Map<String, Object> e = new LinkedHashMap<>();
                e.put("messageId", r.getMessageId());
                e.put("conversationId", convOf.get(r.getMessageId()));
                e.put("emoji", r.getEmoji());
                e.put("createdAt", r.getCreatedAt().toString());
                return e;
            }).toList();
            List<Map<String, Object>> prefs = members.findByUserIdAndLeftAtIsNull(uid).stream()
                    .filter(m -> m.getMutedUntil() != null || m.getArchivedAt() != null).map(m -> {
                        Map<String, Object> e = new LinkedHashMap<>();
                        e.put("conversationId", m.getConversationId());
                        e.put("mutedUntil", m.getMutedUntil() == null ? null : m.getMutedUntil().toString());
                        e.put("archivedAt", m.getArchivedAt() == null ? null : m.getArchivedAt().toString());
                        return e;
                    }).toList();
            return Map.of("count", out.size(), "reactions", out, "conversationSettings", prefs);
        });
    }

    @Bean
    DataExporter messageExporter(MessageRepository messages, MessageCodec codec) {
        return DataExporter.of("sentMessages", uid -> {
            List<Message> rows = codec.openAll(messages.sentBy(uid, PageRequest.of(0, MAX_EXPORT)));
            List<Map<String, Object>> out = rows.stream().map(m -> {
                Map<String, Object> e = new LinkedHashMap<>();
                e.put("id", m.getId());
                e.put("conversationId", m.getConversationId());
                e.put("createdAt", m.getCreatedAt().toString());
                e.put("removed", m.isHidden() || m.isDeleted());
                e.put("deleted", m.isDeleted());
                e.put("editedAt", m.getEditedAt() == null ? null : m.getEditedAt().toString());
                e.put("replyToMessageId", m.getReplyToMessageId());
                e.put("text", m.isHidden() || m.isDeleted() ? null : m.getBody());
                return e;
            }).toList();
            return Map.of("count", out.size(), "truncated", out.size() >= MAX_EXPORT, "messages", out);
        });
    }
}
