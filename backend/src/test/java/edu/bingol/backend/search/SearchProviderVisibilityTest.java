package edu.bingol.backend.search;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunitySearchProvider;
import edu.bingol.backend.event.EventSearchProvider;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.post.admin.PostSearchProvider;
import java.lang.reflect.Field;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * B7: genel arama saglayicilari gizlilik sinirlarina uyar. Kulup/etkinlik sorgulari standart SQL oldugundan H2'de
 * calisir; gonderi aramasi PostgreSQL'e ozel (tsvector) oldugu icin yalniz SQL metni engel + gizli hesap kosullarini
 * icerdigi yapisal olarak denetlenir, davranisi scripts/smoke-posts.sh dogrular.
 */
@SpringBootTest
class SearchProviderVisibilityTest {

    @Autowired CommunityRepository communities;
    @Autowired UserEventRepository eventRepo;
    @Autowired CommunitySearchProvider communitySearch;
    @Autowired EventSearchProvider eventSearch;

    private Community club(String name, Community.Status st, Community.Visibility vis) {
        Community c = new Community();
        c.setName(name);
        c.setSlug("s-" + UUID.randomUUID().toString().substring(0, 10));
        c.setOwnerId(1L);
        c.setStatus(st);
        c.setVisibility(vis);
        c.setCategory("Spor");
        return communities.saveAndFlush(c);
    }

    private UserEvent event(String title, Long communityId, UserEvent.Status st, Instant ends) {
        UserEvent e = new UserEvent();
        e.setTitle(title);
        e.setStartsAt(ends.minus(Duration.ofHours(1)));
        e.setEndsAt(ends);
        e.setCreatedBy(1L);
        e.setStatus(st);
        e.setCommunityId(communityId);
        return eventRepo.saveAndFlush(e);
    }

    @Test
    void communitySearchHidesPrivateAndPending() {
        SecurityContextHolder.clearContext();
        String tag = "zq" + UUID.randomUUID().toString().substring(0, 6);
        club(tag + " acik", Community.Status.ACTIVE, Community.Visibility.PUBLIC);
        club(tag + " gizli", Community.Status.ACTIVE, Community.Visibility.PRIVATE);
        club(tag + " bekleyen", Community.Status.PENDING_REVIEW, Community.Visibility.PUBLIC);
        List<SearchHit> hits = communitySearch.search(tag, 20);
        assertEquals(1, hits.size());
        assertTrue(hits.get(0).title().endsWith("acik"));
    }

    @Test
    void searchTreatsPercentLiterally() {
        SecurityContextHolder.clearContext();
        String tag = "wq" + UUID.randomUUID().toString().substring(0, 6);
        club(tag + " tek", Community.Status.ACTIVE, Community.Visibility.PUBLIC);
        assertEquals(1, communitySearch.search(tag, 20).size());
        assertTrue(communitySearch.search(tag + "%", 20).isEmpty(), "yuzde isareti joker degil, literal aranir");
    }

    @Test
    void eventSearchHidesPrivateClubPendingAndFinished() {
        SecurityContextHolder.clearContext();
        String tag = "ev" + UUID.randomUUID().toString().substring(0, 6);
        Community open = club(tag + " kulup acik", Community.Status.ACTIVE, Community.Visibility.PUBLIC);
        Community priv = club(tag + " kulup gizli", Community.Status.ACTIVE, Community.Visibility.PRIVATE);
        Instant future = Instant.now().plus(Duration.ofDays(3));
        event(tag + " herkese", open.getId(), UserEvent.Status.ACTIVE, future);
        event(tag + " gizlikulup", priv.getId(), UserEvent.Status.ACTIVE, future);
        event(tag + " bekleyen", open.getId(), UserEvent.Status.PENDING_REVIEW, future);
        event(tag + " bitmis", open.getId(), UserEvent.Status.ACTIVE, Instant.now().minus(Duration.ofDays(1)));
        List<SearchHit> hits = eventSearch.search(tag, 20);
        assertEquals(1, hits.size());
        assertTrue(hits.get(0).title().endsWith("herkese"));
    }

    @Test
    void postSearchSqlFiltersBlocksAndPrivateAccounts() throws Exception {
        Field f = PostSearchProvider.class.getDeclaredField("SQL");
        f.setAccessible(true);
        String sql = (String) f.get(null);
        assertTrue(sql.contains("b.blocker_id = ? AND b.blocked_id = p.author_id"), "engel (ben engelledim)");
        assertTrue(sql.contains("b.blocker_id = p.author_id AND b.blocked_id = ?"), "engel (beni engelledi)");
        assertTrue(sql.contains("private_account = TRUE"), "gizli hesap gonderisi yalniz takipciye aranir");
        assertTrue(sql.contains("hidden_at IS NULL") && sql.contains("deleted_at IS NULL"));
    }
}
