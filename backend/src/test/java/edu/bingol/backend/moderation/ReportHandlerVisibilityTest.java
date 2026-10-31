package edu.bingol.backend.moderation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityPost;
import edu.bingol.backend.community.CommunityPostRepository;
import edu.bingol.backend.community.CommunityReportHandlers;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.event.EventModerationService;
import edu.bingol.backend.event.EventReportHandler;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.poll.Poll;
import edu.bingol.backend.poll.PollAccess;
import edu.bingol.backend.poll.PollReportHandler;
import edu.bingol.backend.poll.PollRepository;
import edu.bingol.backend.post.admin.PostReportHandlers;
import edu.bingol.backend.post.media.PostMediaService;
import edu.bingol.backend.profile.privacy.AvatarReportHandler;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.profile.privacy.PrivacyService;
import edu.bingol.backend.profile.privacy.ProfilePrivacy;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

/**
 * T-057: {@code ReportTargetHandler.exists(viewerId, id)} raporlayanin hedefi GOREBILDIGINI denetler; gorunmeyen hedef
 * (onay bekleyen/gizli etkinlik, ozel kulup yazisi, engelleyenin gonderisi, askidaki kullanici...) false doner.
 */
class ReportHandlerVisibilityTest {

    private static final long VIEWER = 1L;
    private static final long OWNER = 2L;

    private final BlockService blocks = mock(BlockService.class);
    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);

    @BeforeEach
    void noBlocks() {
        when(blocks.isBlocked(anyLong(), anyLong())).thenReturn(false);
        when(blocks.hasBlocked(anyLong(), anyLong())).thenReturn(false);
    }

    private Community club(long id, Community.Status st, Community.Visibility vis) {
        Community c = new Community();
        c.setId(id);
        c.setOwnerId(OWNER);
        c.setStatus(st);
        c.setVisibility(vis);
        when(communities.findById(id)).thenReturn(Optional.of(c));
        return c;
    }

    private void member(long clubId, long user, boolean active) {
        when(members.findByCommunityIdAndUserId(clubId, user)).thenReturn(Optional.of(new CommunityMember(clubId, user,
                CommunityMember.Role.MEMBER, active ? CommunityMember.Status.ACTIVE : CommunityMember.Status.PENDING)));
    }

    // ---- COMMUNITY ----

    @Test
    void communityMustBeActiveAndNotBlocked() {
        var h = new CommunityReportHandlers.CommunityHandler(communities, blocks);
        club(5, Community.Status.PENDING_REVIEW, Community.Visibility.PUBLIC);
        assertFalse(h.exists(VIEWER, 5L), "onay bekleyen kulup olmayanla ayni");
        club(6, Community.Status.REJECTED, Community.Visibility.PUBLIC);
        assertFalse(h.exists(VIEWER, 6L));
        club(7, Community.Status.ACTIVE, Community.Visibility.PRIVATE);
        assertTrue(h.exists(VIEWER, 7L), "ozel kulubun kendisi de raporlanabilir (ad/kapak herkese gorunur)");
        when(blocks.isBlocked(VIEWER, OWNER)).thenReturn(true);
        assertFalse(h.exists(VIEWER, 7L), "sahibiyle engel iliskisi");
        assertFalse(h.exists(VIEWER, 999L), "olmayan kulup");
    }

    // ---- POST / ANNOUNCEMENT ----

    private CommunityPost post(long id, long clubId, boolean announcement, boolean deleted) {
        CommunityPost p = new CommunityPost();
        p.setId(id);
        p.setCommunityId(clubId);
        p.setAuthorId(OWNER);
        p.setAnnouncement(announcement);
        p.setDeleted(deleted);
        return p;
    }

    @Test
    void privateClubPostRequiresActiveMembership() {
        CommunityPostRepository posts = mock(CommunityPostRepository.class);
        var h = new CommunityReportHandlers.PostHandler(posts, communities, members, blocks);
        club(8, Community.Status.ACTIVE, Community.Visibility.PRIVATE);
        when(posts.findById(50L)).thenReturn(Optional.of(post(50L, 8, false, false)));
        assertFalse(h.exists(VIEWER, 50L), "uye olmayan ozel kulup yazisini goremez");
        member(8, VIEWER, false);
        assertFalse(h.exists(VIEWER, 50L), "bekleyen uye de goremez");
        member(8, VIEWER, true);
        assertTrue(h.exists(VIEWER, 50L));

        club(9, Community.Status.ACTIVE, Community.Visibility.PUBLIC);
        when(posts.findById(51L)).thenReturn(Optional.of(post(51L, 9, false, false)));
        assertTrue(h.exists(VIEWER, 51L), "herkese acik kulup yazisi");
        when(posts.findById(52L)).thenReturn(Optional.of(post(52L, 9, false, true)));
        assertFalse(h.exists(VIEWER, 52L), "silinmis yazi");
        when(blocks.isBlocked(VIEWER, OWNER)).thenReturn(true);
        assertFalse(h.exists(VIEWER, 51L), "yazar engel iliskisinde");
    }

    @Test
    void hiddenByAdminPostIsInvisible() {
        CommunityPostRepository posts = mock(CommunityPostRepository.class);
        var h = new CommunityReportHandlers.PostHandler(posts, communities, members, blocks);
        club(9, Community.Status.ACTIVE, Community.Visibility.PUBLIC);
        CommunityPost p = post(53L, 9, false, false);
        p.setHiddenAt(java.time.Instant.now());
        when(posts.findById(53L)).thenReturn(Optional.of(p));
        assertFalse(h.exists(VIEWER, 53L));
    }

    @Test
    void announcementTypeOnlyMatchesAnnouncements() {
        CommunityPostRepository posts = mock(CommunityPostRepository.class);
        var h = new CommunityReportHandlers.AnnouncementHandler(posts, communities, members, blocks);
        club(9, Community.Status.ACTIVE, Community.Visibility.PUBLIC);
        when(posts.findById(60L)).thenReturn(Optional.of(post(60L, 9, true, false)));
        when(posts.findById(61L)).thenReturn(Optional.of(post(61L, 9, false, false)));
        assertEquals(ReportTargetType.ANNOUNCEMENT, h.type());
        assertTrue(h.exists(VIEWER, 60L));
        assertFalse(h.exists(VIEWER, 61L), "duyuru olmayan yazi ANNOUNCEMENT olarak raporlanamaz");
        assertEquals(Optional.of(OWNER), h.ownerId(60L));
        assertEquals(Optional.empty(), h.ownerId(61L));
    }

    // ---- EVENT ----

    private UserEvent event(long id, UserEvent.Status st, Long clubId, UserEventRepository events) {
        UserEvent e = new UserEvent();
        e.setId(id);
        e.setStatus(st);
        e.setCommunityId(clubId);
        e.setCreatedBy(OWNER);
        when(events.findById(id)).thenReturn(Optional.of(e));
        return e;
    }

    @Test
    void eventMustBePublishedAndClubVisible() {
        UserEventRepository events = mock(UserEventRepository.class);
        var h = new EventReportHandler(events, mock(EventModerationService.class), communities, members, blocks);
        club(20, Community.Status.ACTIVE, Community.Visibility.PRIVATE);
        club(21, Community.Status.ACTIVE, Community.Visibility.PUBLIC);
        club(22, Community.Status.HIDDEN, Community.Visibility.PUBLIC);
        for (UserEvent.Status st : List.of(UserEvent.Status.PENDING_REVIEW, UserEvent.Status.REJECTED,
                UserEvent.Status.CANCELLED, UserEvent.Status.HIDDEN)) {
            event(100L + st.ordinal(), st, 21L, events);
            assertFalse(h.exists(VIEWER, 100L + st.ordinal()), st + " etkinlik olmayanla ayni");
        }
        event(110L, UserEvent.Status.ACTIVE, 21L, events);
        assertTrue(h.exists(VIEWER, 110L));
        event(111L, UserEvent.Status.ACTIVE, 20L, events);
        assertFalse(h.exists(VIEWER, 111L), "ozel kulup etkinligi, uye degil");
        member(20, VIEWER, true);
        assertTrue(h.exists(VIEWER, 111L));
        event(112L, UserEvent.Status.ACTIVE, 22L, events);
        assertFalse(h.exists(VIEWER, 112L), "gizli kulubun etkinligi");
        when(blocks.isBlocked(VIEWER, OWNER)).thenReturn(true);
        assertFalse(h.exists(VIEWER, 110L), "olusturanla engel iliskisi");
    }

    // ---- USER / USER_AVATAR ----

    private User user(long id, UserStatus st, String avatar) {
        User u = new User();
        u.setId(id);
        u.setStatus(st);
        u.setAvatarUrl(avatar);
        return u;
    }

    @Test
    void userMustBeActiveAndNotHaveBlockedTheReporter() {
        UserRepository users = mock(UserRepository.class);
        var h = new UserReportHandler(users, mock(UserModerationService.class), blocks);
        when(users.findById(OWNER)).thenReturn(Optional.of(user(OWNER, UserStatus.ACTIVE, null)));
        assertTrue(h.exists(VIEWER, OWNER));
        when(blocks.hasBlocked(OWNER, VIEWER)).thenReturn(true);
        assertFalse(h.exists(VIEWER, OWNER), "hedef raporlayani engellemis");
        when(blocks.hasBlocked(OWNER, VIEWER)).thenReturn(false);
        when(blocks.hasBlocked(VIEWER, OWNER)).thenReturn(true);
        assertTrue(h.exists(VIEWER, OWNER), "kendi engelledigini raporlayabilir (engelle + raporla)");
        when(users.findById(3L)).thenReturn(Optional.of(user(3L, UserStatus.SUSPENDED, null)));
        when(users.findById(4L)).thenReturn(Optional.of(user(4L, UserStatus.DELETED, null)));
        assertFalse(h.exists(VIEWER, 3L));
        assertFalse(h.exists(VIEWER, 4L));
        assertFalse(h.exists(VIEWER, 5L));
    }

    @Test
    void avatarHonoursPrivacyAndModerationHide() {
        UserRepository users = mock(UserRepository.class);
        PrivacyService privacy = mock(PrivacyService.class);
        AvatarVisibility visibility = mock(AvatarVisibility.class);
        var h = new AvatarReportHandler(users, privacy);
        h.setVisibility(visibility, blocks);
        when(users.findById(OWNER)).thenReturn(Optional.of(user(OWNER, UserStatus.ACTIVE, "/files/a.jpg")));
        ProfilePrivacy pp = new ProfilePrivacy();
        when(privacy.get(OWNER)).thenReturn(pp);
        Map<AvatarVisibility.Field, Set<Long>> visible = new EnumMap<>(AvatarVisibility.Field.class);
        visible.put(AvatarVisibility.Field.AVATAR, Set.of(OWNER));
        when(visibility.visibleOwners(anyLong(), anyList(), anyList())).thenReturn(visible);
        assertTrue(h.exists(VIEWER, OWNER));

        visible.put(AvatarVisibility.Field.AVATAR, Set.of());
        assertFalse(h.exists(VIEWER, OWNER), "ONLY_ME avatar raporlayana gorunmez");

        visible.put(AvatarVisibility.Field.AVATAR, Set.of(OWNER));
        pp.setAvatarHidden(true);
        assertFalse(h.exists(VIEWER, OWNER), "moderasyonla gizlenmis avatar");
        pp.setAvatarHidden(false);
        when(blocks.hasBlocked(OWNER, VIEWER)).thenReturn(true);
        assertFalse(h.exists(VIEWER, OWNER));
        when(users.findById(OWNER)).thenReturn(Optional.of(user(OWNER, UserStatus.ACTIVE, null)));
        when(blocks.hasBlocked(OWNER, VIEWER)).thenReturn(false);
        assertFalse(h.exists(VIEWER, OWNER), "avatari olmayan hesap");
    }

    // ---- POLL ----

    @Test
    void pollDraftCancelledOrOutsideAudienceIsInvisible() {
        PollRepository polls = mock(PollRepository.class);
        PollAccess access = mock(PollAccess.class);
        UserRepository users = mock(UserRepository.class);
        var h = new PollReportHandler(polls, access, users, null, null, null);
        Poll draft = poll(1L, Poll.Status.DRAFT);
        Poll cancelled = poll(2L, Poll.Status.CANCELLED);
        Poll open = poll(3L, Poll.Status.OPEN);
        when(polls.findById(1L)).thenReturn(Optional.of(draft));
        when(polls.findById(2L)).thenReturn(Optional.of(cancelled));
        when(polls.findById(3L)).thenReturn(Optional.of(open));
        when(access.memberCommunityIds(VIEWER)).thenReturn(Set.of());
        when(users.findById(VIEWER)).thenReturn(Optional.of(user(VIEWER, UserStatus.ACTIVE, null)));
        when(access.canView(any(Poll.class), any(Actor.class), any(), any())).thenReturn(true);
        assertFalse(h.exists(VIEWER, 1L), "taslak");
        assertFalse(h.exists(VIEWER, 2L), "iptal");
        assertTrue(h.exists(VIEWER, 3L));
        when(access.canView(any(Poll.class), any(Actor.class), any(), any())).thenReturn(false);
        assertFalse(h.exists(VIEWER, 3L), "uye/kitle disi");
        assertFalse(h.exists(VIEWER, 99L), "olmayan");
    }

    private static Poll poll(long id, Poll.Status st) {
        Poll p = new Poll();
        p.setId(id);
        p.setStatus(st);
        p.setCreatedBy(OWNER);
        return p;
    }

    // ---- SQL tabanli handler'lar (H2) ----

    private JdbcTemplate h2(String name) {
        JdbcTemplate jdbc = new JdbcTemplate(new DriverManagerDataSource(
                "jdbc:h2:mem:" + name + ";DB_CLOSE_DELAY=-1;MODE=PostgreSQL", "sa", ""));
        jdbc.execute("CREATE TABLE IF NOT EXISTS app_user (id BIGINT PRIMARY KEY, status VARCHAR(16))");
        jdbc.execute("CREATE TABLE IF NOT EXISTS post (id BIGINT PRIMARY KEY, author_id BIGINT, deleted_at TIMESTAMP, "
                + "hidden_at TIMESTAMP, hidden_reason VARCHAR(100))");
        jdbc.execute("CREATE TABLE IF NOT EXISTS conversation (id BIGINT PRIMARY KEY, type VARCHAR(10), created_by BIGINT, "
                + "closed_at TIMESTAMP, closed_reason VARCHAR(300))");
        jdbc.execute("CREATE TABLE IF NOT EXISTS conversation_member (id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, "
                + "conversation_id BIGINT, user_id BIGINT, left_at TIMESTAMP)");
        jdbc.update("DELETE FROM app_user");
        jdbc.update("DELETE FROM post");
        jdbc.update("DELETE FROM conversation");
        jdbc.update("DELETE FROM conversation_member");
        return jdbc;
    }

    @Test
    void feedPostFollowsPostServiceVisibilityRules() {
        JdbcTemplate jdbc = h2("rv_feed");
        jdbc.update("INSERT INTO app_user VALUES (2, 'ACTIVE'), (3, 'SUSPENDED')");
        jdbc.update("INSERT INTO post (id, author_id) VALUES (10, 2)");
        jdbc.update("INSERT INTO post (id, author_id, hidden_at) VALUES (11, 2, CURRENT_TIMESTAMP)");
        jdbc.update("INSERT INTO post (id, author_id, deleted_at) VALUES (12, 2, CURRENT_TIMESTAMP)");
        jdbc.update("INSERT INTO post (id, author_id) VALUES (13, 3)");
        var h = new PostReportHandlers.FeedPostHandler(jdbc, mock(PostMediaService.class), blocks);
        assertTrue(h.exists(VIEWER, 10L));
        assertFalse(h.exists(VIEWER, 11L), "gizli gonderi");
        assertFalse(h.exists(VIEWER, 12L), "silinmis gonderi");
        assertFalse(h.exists(VIEWER, 13L), "askidaki yazarin gonderisi");
        assertFalse(h.exists(VIEWER, 14L), "olmayan gonderi");
        when(blocks.isBlocked(VIEWER, 2L)).thenReturn(true);
        assertFalse(h.exists(VIEWER, 10L), "engelleyenin gonderisi");
        assertTrue(h.exists(11L), "admin akisi (itiraz/geri alma) icin gizli gonderi 'var' kalir");
    }

    @Test
    void groupConversationOnlyReportableByActiveMemberAndHideClosesIt() {
        JdbcTemplate jdbc = h2("rv_conv");
        jdbc.update("INSERT INTO conversation VALUES (1, 'GROUP', 2, NULL, NULL), (2, 'DIRECT', 2, NULL, NULL)");
        jdbc.update("INSERT INTO conversation_member (conversation_id, user_id, left_at) VALUES (1, 1, NULL), (1, 5, CURRENT_TIMESTAMP), (2, 1, NULL)");
        var h = new ConversationReportHandler(jdbc);
        assertEquals(ReportTargetType.CONVERSATION, h.type());
        assertTrue(h.exists(1L, 1L), "aktif uye");
        assertFalse(h.exists(9L, 1L), "uye olmayan");
        assertFalse(h.exists(5L, 1L), "ayrilmis uye");
        assertFalse(h.exists(1L, 2L), "bireysel sohbet bu turle raporlanamaz");
        assertEquals(Optional.of(2L), h.ownerId(1L));
        assertEquals(Optional.empty(), h.ownerId(2L));

        h.hide(1L);
        Integer closed = jdbc.queryForObject("SELECT COUNT(*) FROM conversation WHERE id = 1 AND closed_at IS NOT NULL", Integer.class);
        assertEquals(1, closed);
        h.hide(1L); // idempotent
    }
}
