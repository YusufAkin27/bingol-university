package edu.bingol.backend.messaging;

import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import java.time.Instant;
import java.util.Optional;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/** MESSAGE hedefi: "gizle" = yumusak silme (`hiddenAt`); API icerik yerine "Bu mesaj kaldırıldı" doner. */
@Component
public class MessageReportHandler implements ReportTargetHandler {

    private final MessageRepository messages;
    private final ConversationMemberRepository members;

    public MessageReportHandler(MessageRepository messages, ConversationMemberRepository members) {
        this.messages = messages;
        this.members = members;
    }

    @Override
    public ReportTargetType type() {
        return ReportTargetType.MESSAGE;
    }

    @Override
    public boolean exists(Long targetId) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof Long uid
                && auth.getAuthorities().stream().noneMatch(g -> g.getAuthority().equals("ROLE_ADMIN"))) {
            // Sade kullanici yalniz uyesi oldugu sohbetin, kendisine ULASMIS mesajini raporlayabilir (varlik yoklamasi
            // ve golge engelli [suppressed] mesaj sizintisi kapali). Silinmis/gizli mesaj da raporlanabilir: govde saklanir (V96).
            return messages.findById(targetId).filter(m -> !m.isSuppressed() || m.getSenderId().equals(uid))
                    .filter(m -> members.findByConversationIdAndUserIdAndLeftAtIsNull(m.getConversationId(), uid).isPresent())
                    .isPresent();
        }
        return messages.existsById(targetId);
    }

    @Override
    public Optional<Long> ownerId(Long targetId) {
        return messages.findById(targetId).map(Message::getSenderId);
    }

    @Override
    public void hide(Long targetId) {
        messages.hide(targetId, Instant.now());
    }
}
