package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationDetail;
import edu.bingol.backend.messaging.dto.MessagingDtos.UnreadSummary;
import edu.bingol.backend.moderation.BlockService;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class ConversationPrefsServiceTest {

    private static final Long ME = 1L;
    private static final Long CONV = 10L;

    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final ConversationService conversations = mock(ConversationService.class);
    private final BlockService blocks = mock(BlockService.class);
    private final ConversationPrefsService service = new ConversationPrefsService(members, messages, conversations, blocks);

    private ConversationMember mine;

    @BeforeEach
    void setUp() {
        mine = ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME)).thenReturn(Optional.of(mine));
        when(conversations.detail(ME, CONV)).thenReturn(new ConversationDetail(null, List.of()));
    }

    @Test
    void muteForDurationSetsFutureInstant() {
        service.mute(ME, CONV, 60, null);

        assertTrue(mine.isMuted());
        assertTrue(mine.getMutedUntil().isAfter(Instant.now().plus(Duration.ofMinutes(59))));
        assertTrue(mine.getMutedUntil().isBefore(Instant.now().plus(Duration.ofMinutes(61))));
        verify(members).save(mine);
    }

    @Test
    void muteForeverIsFarFuture() {
        service.mute(ME, CONV, null, true);

        assertTrue(mine.getMutedUntil().isAfter(Instant.now().plus(Duration.ofDays(365 * 50L))));
    }

    @Test
    void invalidMuteArgumentsAre400() {
        for (Object[] args : new Object[][] {{null, null}, {null, false}, {0, null}, {525_601, null}, {60, true}}) {
            ApiException e = assertThrows(ApiException.class,
                    () -> service.mute(ME, CONV, (Integer) args[0], (Boolean) args[1]));
            assertEquals(HttpStatus.BAD_REQUEST, e.status());
        }
        assertFalse(mine.isMuted());
    }

    @Test
    void unmuteClears() {
        mine.setMutedUntil(Instant.now().plusSeconds(100));

        service.unmute(ME, CONV);

        assertNull(mine.getMutedUntil());
        assertFalse(mine.isMuted());
    }

    @Test
    void expiredMuteIsNotMuted() {
        mine.setMutedUntil(Instant.now().minusSeconds(1));

        assertFalse(mine.isMuted());
    }

    @Test
    void archiveStickyAndUnarchive() {
        service.archive(ME, CONV, true);
        assertTrue(mine.getArchivedAt() != null && mine.isArchiveSticky());

        service.unarchive(ME, CONV);
        assertNull(mine.getArchivedAt());
        assertFalse(mine.isArchiveSticky());
    }

    @Test
    void nonMemberGets404() {
        ApiException e = assertThrows(ApiException.class, () -> service.mute(99L, CONV, 5, null));

        assertEquals(HttpStatus.NOT_FOUND, e.status());
        assertEquals("CONVERSATION_NOT_FOUND", e.code());
        assertThrows(ApiException.class, () -> service.archive(99L, CONV, false));
    }

    @Test
    void unreadSummarySeparatesMutedConversations() {
        ConversationMember muted = ConversationMember.of(11L, ME, ConversationMember.Role.MEMBER);
        muted.setMutedUntil(Instant.now().plusSeconds(600));
        ConversationMember quiet = ConversationMember.of(12L, ME, ConversationMember.Role.MEMBER);
        when(members.findByUserIdAndLeftAtIsNull(ME)).thenReturn(List.of(mine, muted, quiet));
        when(blocks.hiddenFrom(ME)).thenReturn(Set.of());
        when(messages.unreadCounts(eq(ME), any(), any())).thenReturn(List.<Object[]>of(new Object[] {CONV, 3L}, new Object[] {11L, 5L}));

        UnreadSummary s = service.unreadSummary(ME);

        assertEquals(3, s.total());
        assertEquals(5, s.mutedTotal());
        assertEquals(2, s.conversations().size()); // 12 numarali konusmada okunmamis yok
        assertTrue(s.conversations().stream().anyMatch(i -> i.conversationId().equals(11L) && i.muted()));
    }

    @Test
    void unreadSummaryUsesSameQueryAndBlockFilterAsConversationList() {
        when(members.findByUserIdAndLeftAtIsNull(ME)).thenReturn(List.of(mine));
        when(blocks.hiddenFrom(ME)).thenReturn(Set.of(77L));
        when(messages.unreadCounts(ME, List.of(CONV), List.of(77L)))
                .thenReturn(List.<Object[]>of(new Object[] {CONV, 2L}));

        UnreadSummary s = service.unreadSummary(ME);

        assertEquals(2, s.total());
        verify(messages).unreadCounts(ME, List.of(CONV), List.of(77L)); // engelli gonderen filtre olarak gecti
    }

    @Test
    void unreadSummaryWithoutBlocksPassesPlaceholderForNotInClause() {
        when(members.findByUserIdAndLeftAtIsNull(ME)).thenReturn(List.of(mine));
        when(blocks.hiddenFrom(ME)).thenReturn(Set.of());
        when(messages.unreadCounts(ME, List.of(CONV), List.of(-1L))).thenReturn(List.of());

        assertEquals(0, service.unreadSummary(ME).total());
        verify(messages).unreadCounts(ME, List.of(CONV), List.of(-1L));
    }

    @Test
    void mutedForeverFlagDistinguishesIndefiniteFromTimedMute() {
        service.mute(ME, CONV, null, true);
        assertTrue(mine.isMutedForever());

        service.mute(ME, CONV, 525_600, null);
        assertTrue(mine.isMuted());
        assertFalse(mine.isMutedForever());

        service.unmute(ME, CONV);
        assertFalse(mine.isMutedForever());
    }
}
