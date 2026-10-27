package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.messaging.ws.PresenceService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.profanity.ProfanityFilter;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;

/** Karar: sohbet mesajlarinda uygunsuz ifade filtresi YOKTUR (sorun olursa kullanici rapor eder). */
class ProfaneMessageNotFilteredTest {

    @Test
    void messageWithProfanityFromTheListIsAcceptedAndSealedAsIs() {
        String bad = null;
        for (String l : ProfanityFilter.builtInLines("tr")) {
            if (l.matches("=[a-z]{6,10}")) {
                bad = l.substring(1);
                break;
            }
        }
        ConversationRepository convs = mock(ConversationRepository.class);
        ConversationMemberRepository members = mock(ConversationMemberRepository.class);
        MessageRepository messages = mock(MessageRepository.class);
        UserRepository users = mock(UserRepository.class);
        BlockService blocks = mock(BlockService.class);
        MessageCodec codec = mock(MessageCodec.class);
        MessageReactionRepository reactions = mock(MessageReactionRepository.class);
        MessageService service = new MessageService(convs, members, messages, users, blocks, mock(RateLimiter.class),
                mock(ChatEventBus.class), mock(PresenceService.class), mock(NotificationService.class),
                mock(ReportService.class), mock(PlatformTransactionManager.class), codec,
                new MessageViewAssembler(messages, reactions, codec), false);

        Conversation direct = new Conversation();
        direct.setId(10L);
        direct.setType(Conversation.Type.DIRECT);
        when(convs.findById(10L)).thenReturn(Optional.of(direct));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(10L, 1L))
                .thenReturn(Optional.of(ConversationMember.of(10L, 1L, ConversationMember.Role.MEMBER)));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(10L)).thenReturn(List.of(
                ConversationMember.of(10L, 1L, ConversationMember.Role.MEMBER),
                ConversationMember.of(10L, 2L, ConversationMember.Role.MEMBER)));
        User u1 = new User();
        u1.setId(1L);
        u1.setDisplayName("Ali");
        User u2 = new User();
        u2.setId(2L);
        u2.setDisplayName("Ayse");
        when(users.findById(1L)).thenReturn(Optional.of(u1));
        when(users.findById(2L)).thenReturn(Optional.of(u2));
        when(messages.saveAndFlush(any(Message.class))).thenAnswer(inv -> {
            Message m = inv.getArgument(0);
            m.setId(100L);
            return m;
        });
        org.mockito.Mockito.doAnswer(inv -> {
            ((Message) inv.getArgument(0)).setBody(inv.getArgument(1));
            return null;
        }).when(codec).seal(any(Message.class), anyString());
        when(codec.open(any(Message.class))).thenAnswer(inv -> inv.getArgument(0));
        when(codec.openAll(any())).thenAnswer(inv -> inv.getArgument(0));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());

        String text = "ulan " + bad + " " + bad;
        assertEquals(true, service.send(1L, 10L, text, "c-profane").created());
        verify(codec).seal(any(Message.class), org.mockito.ArgumentMatchers.eq(text));
    }
}
