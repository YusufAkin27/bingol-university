package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.dto.MessagingDtos.PresenceView;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.privacy.Audience;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.profile.privacy.ProfilePrivacyRepository;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.messaging.simp.user.SimpUserRegistry;

/**
 * T-025 / T-028: cevrimici durum gizliligi. Ortak konusma yoksa 404; engel iliskisi, ONLY_ME ayari ya da karsilik
 * gormemis birebir konusmada sabit "cevrimdisi" (200): engellenen taraf engellendigini, yabanci presence'i izleyemez.
 */
@SuppressWarnings("unchecked")
class PresencePrivacyTest {

    private static final Long VIEWER = 1L;
    private static final Long TARGET = 2L;

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final ProfilePrivacyRepository privacy = mock(ProfilePrivacyRepository.class);
    private final PresenceService presence = new PresenceService(redis, mock(SimpUserRegistry.class), members, blocks);

    @BeforeEach
    void setUp() {
        presence.setPrivacy(privacy);
        when(redis.opsForValue()).thenReturn(ops);
        when(redis.hasKey("presence:2")).thenReturn(true); // hedef gercekten cevrimici
        when(members.shareConversation(VIEWER, TARGET)).thenReturn(true);
        when(privacy.findById(TARGET)).thenReturn(Optional.empty());
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
    }

    @Test
    void sharedConversationShowsRealStatusByDefault() {
        PresenceView v = presence.view(VIEWER, TARGET);

        assertTrue(v.online());
    }

    @Test
    void noSharedConversationIs404() {
        when(members.shareConversation(VIEWER, TARGET)).thenReturn(false);

        ApiException e = assertThrows(ApiException.class, () -> presence.view(VIEWER, TARGET));
        assertEquals("USER_NOT_FOUND", e.code());
        assertEquals(404, e.status().value());
    }

    @Test
    void blockInEitherDirectionReturnsConstantOfflineNot404() {
        when(blocks.isBlocked(VIEWER, TARGET)).thenReturn(true);

        PresenceView v = presence.view(VIEWER, TARGET);

        assertFalse(v.online());
        assertNull(v.lastSeenAt());
        // engelli ile engelsiz yanit AYNI bicimde: ayirt edilebilir fark yok (yalniz gercek "cevrimici" gizlenir)
        when(blocks.isBlocked(VIEWER, TARGET)).thenReturn(false);
        when(redis.hasKey("presence:2")).thenReturn(false);
        when(ops.get("lastseen:2")).thenReturn(null);
        PresenceView plain = presence.view(VIEWER, TARGET);
        assertEquals(v, plain);
    }

    @Test
    void onlyMeAudienceHidesPresence() {
        ProfilePrivacy p = ProfilePrivacy.defaults(TARGET);
        p.setPresenceAudience(Audience.ONLY_ME);
        when(privacy.findById(TARGET)).thenReturn(Optional.of(p));

        PresenceView v = presence.view(VIEWER, TARGET);

        assertFalse(v.online());
        assertNull(v.lastSeenAt());
    }

    @Test
    void everyoneAndSharedContextAudiencesShowStatusToConversationPartners() {
        ProfilePrivacy p = ProfilePrivacy.defaults(TARGET);
        assertEquals(Audience.SHARED_CONTEXT, p.getPresenceAudience()); // guvenli varsayilan
        when(privacy.findById(TARGET)).thenReturn(Optional.of(p));
        assertTrue(presence.view(VIEWER, TARGET).online());

        p.setPresenceAudience(Audience.EVERYONE);
        assertTrue(presence.view(VIEWER, TARGET).online());
    }

    @Test
    void ownStatusIsAlwaysVisible() {
        when(redis.hasKey("presence:1")).thenReturn(true);
        ProfilePrivacy p = ProfilePrivacy.defaults(VIEWER);
        p.setPresenceAudience(Audience.ONLY_ME);

        assertTrue(presence.view(VIEWER, VIEWER).online());
    }

    @Test
    void unsolicitedDirectOnlyRelationHidesStatusUntilTargetSpoke() {
        // SQL yolu: ortak baglam sorgusu 0 (hedef birebirde hic yazmadi) ama konusma ortak -> sabit cevrimdisi
        org.springframework.jdbc.core.JdbcTemplate jdbc = mock(org.springframework.jdbc.core.JdbcTemplate.class);
        when(jdbc.queryForObject(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.eq(Integer.class),
                org.mockito.ArgumentMatchers.<Object>any(), org.mockito.ArgumentMatchers.<Object>any(),
                org.mockito.ArgumentMatchers.<Object>any())).thenReturn(0);
        presence.setJdbc(jdbc);

        PresenceView v = presence.view(VIEWER, TARGET);

        assertFalse(v.online());
        assertNull(v.lastSeenAt());

        // hedef yazdiysa (sorgu 1) gercek durum
        when(jdbc.queryForObject(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.eq(Integer.class),
                org.mockito.ArgumentMatchers.<Object>any(), org.mockito.ArgumentMatchers.<Object>any(),
                org.mockito.ArgumentMatchers.<Object>any())).thenReturn(1);
        assertTrue(presence.view(VIEWER, TARGET).online());
    }

    @Test
    void bulkVisibilityDropsBlockedOnlyMeAndStrangersAndFeedsOnlineFlag() {
        Long a = 3L;
        Long b = 4L;
        Long c = 5L;
        when(members.shareConversation(VIEWER, TARGET)).thenReturn(true);
        when(members.shareConversation(VIEWER, a)).thenReturn(true);
        when(members.shareConversation(VIEWER, b)).thenReturn(true);
        when(members.shareConversation(VIEWER, c)).thenReturn(false); // yabanci
        when(blocks.hiddenFrom(VIEWER)).thenReturn(Set.of(a));
        ProfilePrivacy onlyMe = ProfilePrivacy.defaults(b);
        onlyMe.setPresenceAudience(Audience.ONLY_ME);
        when(privacy.findByUserIdIn(anyCollection())).thenReturn(List.of(onlyMe));

        Set<Long> visible = presence.visibleAmong(VIEWER, List.of(TARGET, a, b, c));

        assertEquals(Set.of(TARGET), visible);
        when(ops.multiGet(any())).thenReturn(List.of("1"));
        assertEquals(Set.of(TARGET), presence.onlineVisibleTo(VIEWER, List.of(TARGET, a, b, c)));
    }
}
