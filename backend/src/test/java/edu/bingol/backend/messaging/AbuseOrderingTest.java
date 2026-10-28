package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.messaging.ws.PresenceService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;

/** Mesaj gonderme/okuma/yaziyor: kaba kullanici siniri DB sorgularindan ONCE calisir; tekrarli clientId de sayilir. */
class AbuseOrderingTest {

    private static final Long ME = 1L;
    private static final Long CONV = 10L;

    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final ChatEventBus bus = mock(ChatEventBus.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final MessageService service = new MessageService(convs, members, messages, users,
            mock(BlockService.class), limiter, bus, mock(PresenceService.class), mock(NotificationService.class),
            mock(ReportService.class), mock(PlatformTransactionManager.class), codec,
            new MessageViewAssembler(messages, mock(MessageReactionRepository.class), codec), false);

    @Test
    void sendOverTheCoarseLimitFailsBeforeAnyRepositoryLookup() {
        doThrow(new RateLimitedException(30)).when(limiter).check(startsWith("msg:all:"), anyInt(), any());

        assertThrows(RateLimitedException.class, () -> service.send(ME, CONV, "merhaba", "cid-1", null, List.of()));

        verifyNoInteractions(members, users, messages, convs);
    }

    @Test
    void duplicateClientIdReplayPassesTheCoarseLimiterBeforeTheDuplicateLookup() {
        // Ayni clientId ile tekrar: eskiden DB'den erken donup HICBIR sinira takilmiyordu
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME))
                .thenReturn(java.util.Optional.of(ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER)));
        edu.bingol.backend.user.User u = new edu.bingol.backend.user.User();
        u.setId(ME);
        when(users.findById(ME)).thenReturn(java.util.Optional.of(u));
        when(messages.findByConversationIdAndSenderIdAndClientId(CONV, ME, "cid-1"))
                .thenReturn(java.util.Optional.of(new Message()));
        try {
            service.send(ME, CONV, "merhaba", "cid-1", null, List.of());
        } catch (RuntimeException e) {
            // sahte kodek/assembler ile gorunum uretimi onemsiz: sira dogrulanir
        }
        org.mockito.InOrder order = org.mockito.Mockito.inOrder(limiter, members, messages);
        order.verify(limiter).check(startsWith("msg:all:"), anyInt(), any());
        order.verify(members).findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME);
        order.verify(messages).findByConversationIdAndSenderIdAndClientId(CONV, ME, "cid-1");
    }

    @Test
    void markReadOverTheCoarseLimitIsASilentNoOpWithoutDbAccess() {
        doThrow(new RateLimitedException(5)).when(limiter).check(startsWith("read:all:"), anyInt(), any());

        service.markRead(ME, CONV, 5L);

        verifyNoInteractions(members, convs, messages, bus);
    }

    @Test
    void typingOverTheCoarseLimitIsSilentAndSkipsMembershipLookup() {
        doThrow(new RateLimitedException(2)).when(limiter).check(startsWith("typing:all:"), anyInt(), any());

        service.typing(ME, CONV);
        service.typing(ME, 999_999L); // rastgele konusma kimligiyle de DB'ye inmez

        verifyNoInteractions(members, bus);
    }
}
