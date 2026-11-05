package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Sender-only receipt details and paginated replies in a direct conversation. */
@RestController
@RequestMapping("/api/messages")
public class MessageInfoController {
    private final MessageRepository messages;
    private final ConversationRepository conversations;
    private final ConversationMemberRepository members;
    private final MessageCodec codec;
    private final MessageViewAssembler assembler;
    private final ReceiptService receipts;
    private final RateLimiter limiter;

    public MessageInfoController(MessageRepository messages, ConversationRepository conversations,
            ConversationMemberRepository members, MessageCodec codec, MessageViewAssembler assembler,
            ReceiptService receipts, RateLimiter limiter) {
        this.messages = messages;
        this.conversations = conversations;
        this.members = members;
        this.codec = codec;
        this.assembler = assembler;
        this.receipts = receipts;
        this.limiter = limiter;
    }

    public record MessageInfo(MessageView message, String sentAt, String deliveredAt, String readAt,
                              String status, CursorPage<MessageView> replies) {}

    @GetMapping("/{id}/info")
    public MessageInfo info(@PathVariable Long id, @RequestParam(required = false) Long before,
                            @RequestParam(defaultValue = "20") int size) {
        Long user = CurrentUser.id();
        limiter.check("msg:info:" + user, 60, Duration.ofMinutes(1));
        return details(user, id, before, size);
    }

    MessageInfo details(Long user, Long id, Long before, int size) {
        Message message = messages.findById(id).orElseThrow(MessageInfoController::notFound);
        Long cid = message.getConversationId();
        ConversationMember member = members.findByConversationIdAndUserIdAndLeftAtIsNull(cid, user)
                .orElseThrow(MessageInfoController::notFound);
        Conversation conversation = conversations.findById(cid).orElseThrow(MessageInfoController::notFound);
        if (!message.getSenderId().equals(user) || message.isDeleted() || !member.isAccepted()
                || conversation.getType() != Conversation.Type.DIRECT || id <= member.getClearedUpToMessageId()) {
            throw notFound();
        }
        int limit = CursorPage.clampSize(size);
        List<Message> rows = messages.repliesTo(cid, id, user, member.getClearedUpToMessageId(), before,
                PageRequest.of(0, limit + 1));
        List<Message> page = rows.subList(0, Math.min(limit, rows.size()));
        codec.openAll(page);
        Map<Long, MessageView> views = new HashMap<>();
        assembler.assemble(user, page, Set.of(), null).forEach(v -> views.put(v.id(), v));
        codec.openAll(List.of(message));
        MessageView view = assembler.assemble(user, List.of(message), Set.of(), null).get(0);
        String status = receipts.statuses(user, List.of(message), null, Map.of(cid, true)).getOrDefault(id, "SENT");
        // Zaman damgasi yalniz durum onu destekliyorsa doner (golge engel / engel / askidaki alici: durum SENT kalir,
        // kayitli bir zaman olsa bile gonderene sizmaz). Kayit yoksa null: istemci "kayit bulunmuyor" yazar.
        boolean delivered = !message.isSuppressed() && ("DELIVERED".equals(status) || "READ".equals(status));
        boolean read = !message.isSuppressed() && "READ".equals(status);
        return new MessageInfo(view, message.getCreatedAt().toString(),
                delivered && message.getDeliveredAt() != null ? message.getDeliveredAt().toString() : null,
                read && message.getReadAt() != null ? message.getReadAt().toString() : null, status,
                CursorPage.of(rows, limit, Message::getId, m -> views.get(m.getId())));
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "MESSAGE_NOT_FOUND", "Mesaj bulunamadı.");
    }
}
