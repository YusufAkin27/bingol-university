package edu.bingol.backend.poll;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.academic.AudienceKey;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.ClubDeletedEvent;
import edu.bingol.backend.poll.PollDtos.Audience;
import edu.bingol.backend.poll.PollDtos.CreateRequest;
import edu.bingol.backend.poll.PollDtos.PollPage;
import edu.bingol.backend.poll.PollDtos.PollView;
import edu.bingol.backend.poll.PollDtos.VoteRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * T-042 (buyuk I-nokta ile baslayan bolum/fakulte eslemesi, sayac = liste), T-046 (hedef kitle ID ile de gecerli),
 * T-047 (kulup silinince anket), T-048 (CSV sonuc gorunurlugu), T-040 (anket yonetimi izne bagli).
 */
@SpringBootTest
class PollAudienceAccessTest {

    @Autowired PollService service;
    @Autowired PollVoteService voteService;
    @Autowired PollAdminService adminService;
    @Autowired PollAccess access;
    @Autowired PollClubDeletedListener clubDeleted;
    @Autowired PollRepository polls;
    @Autowired UserRepository users;
    @Autowired CommunityRepository communities;
    @Autowired CommunityMemberRepository members;

    /** Test yalitimi: ortak H2 veritabaninda baska testlerin (AcademicServiceTest sayimlari) kullanicilariyla karismasin. */
    private final String sfx = "-" + UUID.randomUUID().toString().substring(0, 6);

    private User user(String faculty, String department, String grade) {
        faculty = faculty == null ? null : faculty + sfx;
        department = department == null ? null : department + sfx;
        User u = new User();
        u.setEmail("a" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kitle Kullanici");
        u.setEmailVerified(true);
        u.setFaculty(faculty);
        u.setDepartment(department);
        u.setGrade(grade);
        return users.saveAndFlush(u);
    }

    private static Actor member(User u) {
        return new Actor(u.getId(), false);
    }

    private static Actor admin(User u) {
        return new Actor(u.getId(), true);
    }

    private CreateRequest global(Audience aud, String show) {
        return new CreateRequest("Kitle anketi " + UUID.randomUUID().toString().substring(0, 4), "Aciklama", "SINGLE",
                "GLOBAL", null, null, List.of("A", "B"), null, null, null, show, null, null,
                OffsetDateTime.now().plusDays(2).toString(), aud, null);
    }

    private static ApiException fails(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    // ---- T-042 ----

    @Test
    void audienceKeyTreatsTurkishIFamilyAsOne() {
        for (String s : List.of("İşletme", "işletme", "IŞLETME", "ışletme", "Isletme", " İŞLETME ")) {
            assertEquals("isletme", AudienceKey.of(s), s);
        }
        assertEquals("iktisadi ve idari bilimler fakultesi", AudienceKey.of("İktisadi ve İdari Bilimler Fakültesi"));
        assertEquals("ilahiyat", AudienceKey.of("İlahiyat"));
        assertTrue(AudienceKey.same("İlahiyat", "ilahiyat"));
        assertFalse(AudienceKey.same("İlahiyat", "Iktisat"));
        assertEquals(null, AudienceKey.of("   "));
    }

    @Test
    void pollTargetedAtCapitalDottedIDepartmentReachesTheRightUsers() {
        User boss = user(null, null, null);
        // Kullanici profili katalog yazimiyla (buyuk İ); anket hedefi yonetici yazimiyla (kucuk/duz)
        User isletme = user("İktisadi ve İdari Bilimler Fakültesi", "İşletme", "2");
        User isletmeOther = user("İktisadi ve İdari Bilimler Fakültesi", "ISLETME", "2");
        User iktisat = user("İktisadi ve İdari Bilimler Fakültesi", "İktisat", "2");
        User ilahiyat = user("İlahiyat Fakültesi", "İlahiyat", "1");

        PollView p = service.create(admin(boss), global(new Audience("iktisadi ve idari bilimler fakültesi" + sfx, "işletme" + sfx, "2"), null));
        Poll poll = polls.findById(p.id()).orElseThrow();

        assertTrue(access.audienceMatches(poll, isletme));
        assertTrue(access.audienceMatches(poll, isletmeOther));
        assertFalse(access.audienceMatches(poll, iktisat));
        assertFalse(access.audienceMatches(poll, ilahiyat));
        // SQL tarafi (PG: lower/translate; burada H2) ayni kurali uygular
        List<Long> ids = access.audienceUserIds(poll);
        assertTrue(ids.contains(isletme.getId()), "SQL hedef kitle: İşletme kullanicisi kayip");
        assertTrue(ids.contains(isletmeOther.getId()));
        assertFalse(ids.contains(iktisat.getId()));
        assertFalse(ids.contains(ilahiyat.getId()));
        Integer eligible = access.eligibleCount(poll);
        assertNotNull(eligible);
        assertTrue(eligible >= 2);
    }

    @Test
    void listAndCountersAgreeForCapitalIUsers() {
        User boss = user(null, null, null);
        User ilahiyat = user("İlahiyat Fakültesi", "İlahiyat", "1");
        User other = user("Fen Fakültesi", "Matematik", "1");
        String needle = "Ilahiyat-" + UUID.randomUUID().toString().substring(0, 5);
        CreateRequest r = new CreateRequest(needle, "Aciklama", "SINGLE", "GLOBAL", null, null, List.of("A", "B"), null, null,
                null, null, null, null, OffsetDateTime.now().plusDays(2).toString(),
                new Audience(null, "ilahiyat" + sfx, null), null);
        PollView created = service.create(admin(boss), r);

        PollPage mine = service.list(member(ilahiyat), "open", null, 50);
        PollPage notMine = service.list(member(other), "open", null, 50);

        assertTrue(mine.items().stream().anyMatch(v -> v.id().equals(created.id())), "İlahiyat kullanicisinin listesinde yok");
        assertFalse(notMine.items().stream().anyMatch(v -> v.id().equals(created.id())));
        // sayac listeyle tutarli: acik sayisi, listelenen kayit sayisindan kucuk olamaz (liste <= 50 kayit)
        assertTrue(mine.openCount() >= mine.items().size() || mine.items().size() == 50,
                "sayac " + mine.openCount() + " < liste " + mine.items().size());
        assertTrue(mine.openCount() > notMine.openCount() - 0 || mine.openCount() >= 1);
    }

    @Test
    void audienceGradeMustBeCatalogValue() {
        User boss = user(null, null, null);
        ApiException e = fails(() -> service.create(admin(boss), global(new Audience(null, null, "9"), null)));
        assertEquals("POLL_INVALID", e.code());
        PollView ok = service.create(admin(boss), global(new Audience(null, null, "phd"), null));
        assertEquals("PHD", ok.audience().grade());
    }

    // ---- T-046 ----

    @Test
    void pollOutsideAudienceIsNotReachableById() {
        User boss = user(null, null, null);
        User inside = user("Fen Fakültesi", "Matematik", "1");
        User outside = user("Hukuk Fakültesi", "Hukuk", "1");
        PollView p = service.create(admin(boss), global(new Audience(null, "matematik" + sfx, null), null));

        assertEquals(p.id(), service.get(member(inside), p.id()).id());
        assertEquals("POLL_NOT_FOUND", fails(() -> service.get(member(outside), p.id())).code());
        // yonetici (olusturan) ve okuma izinli sistem yoneticisi gorur
        assertEquals(p.id(), service.get(member(boss), p.id()).id()); // admin degil ama olusturan degil -> kitle disi
    }

    // ---- T-047 ----

    @Test
    void clubDeletionCancelsOpenAndDraftPollsAndStopsVoting() {
        User owner = user(null, null, null);
        User voter = user(null, null, null);
        Community c = new Community();
        c.setName("Kulup " + UUID.randomUUID().toString().substring(0, 6));
        c.setSlug("kulup-" + UUID.randomUUID());
        c.setStatus(Community.Status.ACTIVE);
        c.setOwnerId(owner.getId());
        c = communities.saveAndFlush(c);
        members.saveAndFlush(new CommunityMember(c.getId(), owner.getId(), CommunityMember.Role.OWNER, CommunityMember.Status.ACTIVE));
        members.saveAndFlush(new CommunityMember(c.getId(), voter.getId(), CommunityMember.Role.MEMBER, CommunityMember.Status.ACTIVE));
        CreateRequest open = new CreateRequest("Kulup anketi", "A", "SINGLE", "COMMUNITY", c.getId(), null, List.of("A", "B"),
                null, null, null, null, true, null, OffsetDateTime.now().plusDays(2).toString(), null, null);
        PollView p = service.create(member(owner), open);
        assertEquals("OPEN", p.status());

        // kulup silinir (yumusak) ve olay yayinlanir
        c.setStatus(Community.Status.DELETED);
        communities.saveAndFlush(c);
        // 1) olay gelmese bile: uye artik goremez ve oylayamaz
        assertEquals("POLL_NOT_FOUND", fails(() -> service.get(member(voter), p.id())).code());
        assertTrue(fails(() -> voteService.vote(member(voter), p.id(), new VoteRequest(List.of(p.options().get(0).id()), null)))
                .status().is4xxClientError());
        // 2) olay dinleyicisi anketi iptal eder
        clubDeleted.onClubDeleted(new ClubDeletedEvent(c.getId()));
        assertEquals(Poll.Status.CANCELLED, polls.findById(p.id()).orElseThrow().getStatus());
    }

    // ---- T-048 ----

    @Test
    void csvHonoursShowResultsRule() {
        User boss = user(null, null, null);
        PollView afterClose = service.create(admin(boss), global(null, "AFTER_CLOSE"));
        PollView always = service.create(admin(boss), global(null, "ALWAYS"));

        ApiException e = fails(() -> adminService.csvFor(admin(boss), afterClose.id()));
        assertEquals("POLL_RESULTS_HIDDEN", e.code());
        assertEquals(409, e.status().value());
        assertTrue(adminService.csvFor(admin(boss), always.id()).startsWith("optionId,text,count"));
        // yonetici paneli ucu ayri kalir: kapanmadan da alir
        assertTrue(adminService.csv(afterClose.id()).startsWith("optionId,text,count"));

        service.close(admin(boss), afterClose.id());
        assertTrue(adminService.csvFor(admin(boss), afterClose.id()).startsWith("optionId,text,count"));
    }

    // ---- T-040 ----

    @Test
    void viewerProfileCannotCreateGlobalPollsButFullAndEditorCan() {
        User boss = user(null, null, null);
        Actor viewer = new Actor(boss.getId(), true, PermissionMatrix.permissionsOf(AdminProfile.VIEWER));
        Actor editor = new Actor(boss.getId(), true, PermissionMatrix.permissionsOf(AdminProfile.EDITOR));

        assertEquals("POLL_FORBIDDEN", fails(() -> service.create(viewer, global(null, null))).code());
        assertEquals("OPEN", service.create(editor, global(null, null)).status());
    }

    @Test
    void viewerProfileCannotDeleteSomeoneElsesPollButFullCan() {
        User creator = user(null, null, null);
        User adminUser = user(null, null, null);
        PollView p = service.create(admin(creator), global(null, null));
        Actor viewer = new Actor(adminUser.getId(), true, PermissionMatrix.permissionsOf(AdminProfile.VIEWER));
        Actor full = new Actor(adminUser.getId(), true, PermissionMatrix.permissionsOf(AdminProfile.FULL));

        ApiException e = fails(() -> service.delete(viewer, p.id()));
        assertTrue(e.status().is4xxClientError());
        assertTrue(polls.findById(p.id()).isPresent());
        service.delete(full, p.id());
        assertFalse(polls.findById(p.id()).isPresent());
    }
}
