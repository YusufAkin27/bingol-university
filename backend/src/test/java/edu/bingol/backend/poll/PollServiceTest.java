package edu.bingol.backend.poll;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.menu.MenuDay;
import edu.bingol.backend.menu.MenuRepository;
import edu.bingol.backend.poll.PollDtos.Audience;
import edu.bingol.backend.poll.PollDtos.CreateRequest;
import edu.bingol.backend.poll.PollDtos.PollPage;
import edu.bingol.backend.poll.PollDtos.PollView;
import edu.bingol.backend.poll.PollDtos.UpdateRequest;
import edu.bingol.backend.poll.PollDtos.VoteRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Anket ve oylama: kurallar, yetki, kapanis, yaris, gizli oy, menu puanlama, gorunurluk, kapsam suzgeci, kulup secimi. */
@SpringBootTest
class PollServiceTest {

    @Autowired PollService service;
    @Autowired PollVoteService voteService;
    @Autowired PollMenuService menuService;
    @Autowired PollAdminService adminService;
    @Autowired PollCloseJob closeJob;
    @Autowired PollNotifier notifier;
    @Autowired PollRepository polls;
    @Autowired PollOptionRepository options;
    @Autowired PollBallotRepository ballots;
    @Autowired PollVoteRepository votes;
    @Autowired UserRepository users;
    @Autowired CommunityRepository communities;
    @Autowired CommunityMemberRepository members;
    @Autowired MenuRepository menus;
    @Autowired JdbcTemplate jdbc;
    @Autowired List<DataExporter> exporters;

    // ---------- yardimcilar ----------

    private User user() {
        return user(null, null, null);
    }

    private User user(String faculty, String department, String grade) {
        User u = new User();
        u.setEmail("p" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Anket Kullanici");
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

    private Community club(User owner) {
        Community c = new Community();
        c.setName("Kulup " + UUID.randomUUID().toString().substring(0, 6));
        c.setSlug("kulup-" + UUID.randomUUID());
        c.setStatus(Community.Status.ACTIVE);
        c.setOwnerId(owner.getId());
        c = communities.saveAndFlush(c);
        members.saveAndFlush(new CommunityMember(c.getId(), owner.getId(), CommunityMember.Role.OWNER, CommunityMember.Status.ACTIVE));
        return c;
    }

    private void join(Community c, User u, CommunityMember.Role role) {
        members.saveAndFlush(new CommunityMember(c.getId(), u.getId(), role, CommunityMember.Status.ACTIVE));
    }

    /** Degistirilebilir istek kurucusu. */
    private static class R {
        String title = "Anket";
        String type = "SINGLE";
        String scope = "GLOBAL";
        Long communityId;
        LocalDate menuDate;
        List<String> options = List.of("A", "B", "C");
        Integer max;
        Boolean anonymous;
        Boolean change;
        Boolean notify;
        Boolean draft;
        String show;
        String opens;
        String closes = OffsetDateTime.now().plusDays(2).toString();
        Audience audience;

        CreateRequest b() {
            return new CreateRequest(title, "Aciklama", type, scope, communityId, menuDate, options, max, anonymous, change,
                    show, notify, opens, closes, audience, draft);
        }
    }

    private PollView create(Actor a, R r) {
        return service.create(a, r.b());
    }

    private static VoteRequest pick(Long... ids) {
        return new VoteRequest(List.of(ids), null);
    }

    private static ApiException fails(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    private static Long optionId(PollView v, int index) {
        return v.options().get(index).id();
    }

    private static int count(PollView v, int optionIndex) {
        Long id = v.options().get(optionIndex).id();
        return v.results().stream().filter(r -> r.optionId().equals(id)).findFirst().orElseThrow().count();
    }

    // ---------- olusturma ve dogrulama ----------

    @Test
    void onlyAdminCreatesGlobalPollsAndValidationIsEnforced() {
        User admin = user();
        User plain = user();
        assertEquals("POLL_FORBIDDEN", fails(() -> create(member(plain), new R())).code());

        PollView v = create(admin(admin), new R());
        assertEquals("OPEN", v.status());
        assertEquals("OPEN", v.state());
        assertEquals(3, v.options().size());
        assertEquals(1, v.maxChoices());
        assertTrue(v.allowChangeVote());
        assertFalse(v.anonymous());
        assertEquals("ALWAYS", v.showResults());
        assertEquals(admin.getId(), v.createdBy().id());

        R few = new R();
        few.options = List.of("tek");
        assertEquals("POLL_INVALID", fails(() -> create(admin(admin), few)).code());
        R many = new R();
        many.options = java.util.stream.IntStream.rangeClosed(1, 13).mapToObj(i -> "S" + i).toList();
        assertEquals("POLL_INVALID", fails(() -> create(admin(admin), many)).code());
        R dup = new R();
        dup.options = List.of("Ayni", "ayni");
        assertEquals("POLL_INVALID", fails(() -> create(admin(admin), dup)).code());
        R longOpt = new R();
        longOpt.options = List.of("x".repeat(101), "b");
        assertEquals("POLL_INVALID", fails(() -> create(admin(admin), longOpt)).code());
        R title = new R();
        title.title = "t".repeat(151);
        assertEquals("POLL_INVALID", fails(() -> create(admin(admin), title)).code());
        R past = new R();
        past.closes = OffsetDateTime.now().minusHours(1).toString();
        assertEquals("POLL_INVALID", fails(() -> create(admin(admin), past)).code());
        R badMax = new R();
        badMax.type = "MULTI";
        badMax.max = 4;
        assertEquals("POLL_INVALID", fails(() -> create(admin(admin), badMax)).code());
        R badType = new R();
        badType.type = "NOPE";
        assertEquals("POLL_INVALID", fails(() -> create(admin(admin), badType)).code());
    }

    // ---------- oy kurallari ----------

    @Test
    void singleChoiceVoteIsIdempotentChangeableAndRetractable() {
        User creator = user();
        User voter = user();
        PollView p = create(admin(creator), new R());
        Actor a = member(voter);

        PollView v1 = voteService.vote(a, p.id(), pick(optionId(p, 0)));
        assertEquals(1, count(v1, 0));
        assertEquals(1, v1.totalVotes());
        assertEquals(List.of(optionId(p, 0)), v1.myVote().optionIds());

        PollView again = voteService.vote(a, p.id(), pick(optionId(p, 0))); // idempotent
        assertEquals(1, count(again, 0));
        assertEquals(1, again.totalVotes());

        PollView changed = voteService.vote(a, p.id(), pick(optionId(p, 2)));
        assertEquals(0, count(changed, 0));
        assertEquals(1, count(changed, 2));
        assertEquals(1, changed.totalVotes());

        PollView retracted = voteService.retract(a, p.id());
        assertNull(retracted.myVote());
        assertEquals(0, retracted.totalVotes());
        assertEquals(0, count(retracted, 2));
        assertNull(voteService.retract(a, p.id()).myVote()); // idempotent
    }

    @Test
    void changeNotAllowedGives409AlreadyVotedButSameVoteStaysIdempotent() {
        User creator = user();
        User voter = user();
        R r = new R();
        r.change = false;
        PollView p = create(admin(creator), r);
        Actor a = member(voter);
        voteService.vote(a, p.id(), pick(optionId(p, 0)));

        voteService.vote(a, p.id(), pick(optionId(p, 0))); // ayni oy: sorun yok
        assertEquals("POLL_ALREADY_VOTED", fails(() -> voteService.vote(a, p.id(), pick(optionId(p, 1)))).code());
        assertEquals("POLL_ALREADY_VOTED", fails(() -> voteService.retract(a, p.id())).code());
        assertEquals("ALREADY_VOTED", service.get(a, p.id()).voteBlockedReason());
    }

    @Test
    void invalidSelectionsAreRejected() {
        User creator = user();
        User voter = user();
        PollView single = create(admin(creator), new R());
        PollView other = create(admin(creator), new R());
        Actor a = member(voter);

        assertEquals("POLL_INVALID_VOTE", fails(() -> voteService.vote(a, single.id(), pick(optionId(single, 0), optionId(single, 1)))).code());
        assertEquals("POLL_INVALID_VOTE", fails(() -> voteService.vote(a, single.id(), pick(optionId(other, 0)))).code());
        assertEquals("POLL_INVALID_VOTE", fails(() -> voteService.vote(a, single.id(), pick())).code());
        assertEquals("POLL_INVALID_VOTE", fails(() -> voteService.vote(a, single.id(), new VoteRequest(null, null))).code());
        assertEquals("POLL_INVALID_VOTE", fails(() -> voteService.vote(a, single.id(), pick(optionId(single, 0), optionId(single, 0)))).code());
        assertEquals("POLL_NOT_FOUND", fails(() -> voteService.vote(a, 999999L, pick(1L))).code());
    }

    @Test
    void multiChoiceHonoursMaxChoices() {
        User creator = user();
        User v1 = user();
        User v2 = user();
        R r = new R();
        r.type = "MULTI";
        r.max = 2;
        PollView p = create(admin(creator), r);

        assertEquals(2, p.maxChoices());
        assertEquals("POLL_INVALID_VOTE", fails(() -> voteService.vote(member(v1), p.id(), pick(optionId(p, 0), optionId(p, 1), optionId(p, 2)))).code());
        voteService.vote(member(v1), p.id(), pick(optionId(p, 0), optionId(p, 1)));
        PollView after = voteService.vote(member(v2), p.id(), pick(optionId(p, 1)));
        assertEquals(1, count(after, 0));
        assertEquals(2, count(after, 1));
        assertEquals(2, after.totalVotes()); // oy veren kisi sayisi
        assertEquals(100.0, after.results().get(1).percent());

        PollView changed = voteService.vote(member(v1), p.id(), pick(optionId(p, 2)));
        assertEquals(0, count(changed, 0));
        assertEquals(1, count(changed, 1));
        assertEquals(1, count(changed, 2));
    }

    @Test
    void ratingPollAveragesStarsAndRejectsOutOfRange() {
        User creator = user();
        R r = new R();
        r.type = "RATING";
        r.options = null;
        PollView p = create(admin(creator), r);
        assertEquals(5, p.options().size());

        User a = user();
        User b = user();
        assertEquals("POLL_INVALID_VOTE", fails(() -> voteService.vote(member(a), p.id(), new VoteRequest(null, 6))).code());
        assertEquals("POLL_INVALID_VOTE", fails(() -> voteService.vote(member(a), p.id(), new VoteRequest(null, 0))).code());
        voteService.vote(member(a), p.id(), new VoteRequest(null, 4));
        PollView v = voteService.vote(member(b), p.id(), new VoteRequest(null, 2));

        assertEquals(3.0, v.average());
        assertEquals(2, v.ratingCount());
        assertEquals(2, v.myVote().rating());
        PollView changed = voteService.vote(member(b), p.id(), new VoteRequest(null, 5));
        assertEquals(4.5, changed.average());
    }

    @Test
    void rankedPollComputesFirstChoiceCountsAndBordaScores() {
        User creator = user();
        R r = new R();
        r.type = "RANKED";
        PollView p = create(admin(creator), r);
        assertEquals(3, p.maxChoices());
        User a = user();
        User b = user();

        voteService.vote(member(a), p.id(), pick(optionId(p, 0), optionId(p, 1), optionId(p, 2)));
        PollView v = voteService.vote(member(b), p.id(), pick(optionId(p, 1), optionId(p, 0), optionId(p, 2)));

        assertEquals(1, count(v, 0));
        assertEquals(1, count(v, 1));
        assertEquals(0, count(v, 2));
        assertEquals(5, v.results().get(0).score());
        assertEquals(5, v.results().get(1).score());
        assertEquals(2, v.results().get(2).score());
        assertEquals(List.of(optionId(p, 1), optionId(p, 0), optionId(p, 2)), v.myVote().optionIds()); // sira korunur

        PollView changed = voteService.vote(member(b), p.id(), pick(optionId(p, 2), optionId(p, 1), optionId(p, 0)));
        assertEquals(1, count(changed, 0));
        assertEquals(0, count(changed, 1));
        assertEquals(1, count(changed, 2));
        assertEquals(3 + 1, changed.results().get(0).score()); // a:3 b:1
    }

    // ---------- sonuc gorunurlugu ----------

    @Test
    void resultVisibilityRulesAreApplied() {
        User creator = user();
        User voter = user();
        User other = user();
        R afterVote = new R();
        afterVote.show = "AFTER_VOTE";
        PollView p = create(admin(creator), afterVote);

        PollView before = service.get(member(voter), p.id());
        assertFalse(before.resultsVisible());
        assertNull(before.results());
        assertNull(before.totalVotes());
        assertNull(before.turnout());

        PollView voted = voteService.vote(member(voter), p.id(), pick(optionId(p, 0)));
        assertTrue(voted.resultsVisible());
        assertFalse(service.get(member(other), p.id()).resultsVisible());
        assertTrue(adminService.get(admin(creator), p.id()).resultsVisible()); // yonetici ucu her zaman

        R afterClose = new R();
        afterClose.show = "AFTER_CLOSE";
        PollView c = create(admin(creator), afterClose);
        PollView cv = voteService.vote(member(voter), c.id(), pick(optionId(c, 0)));
        assertFalse(cv.resultsVisible());
        assertNotNull(cv.myVote());
        service.close(admin(creator), c.id());
        PollView closed = service.get(member(other), c.id());
        assertTrue(closed.resultsVisible());
        assertEquals(1, closed.totalVotes());
        assertEquals("CLOSED", closed.state());
    }

    // ---------- kapanis, zamanlama, taslak ----------

    @Test
    void expiredPollRejectsVotesBeforeAndAfterTheCloseJob() {
        User creator = user();
        User voter = user();
        PollView p = create(admin(creator), new R());
        Poll row = polls.findById(p.id()).orElseThrow();
        row.setClosesAt(Instant.now().minus(Duration.ofMinutes(1)));
        polls.saveAndFlush(row);

        assertEquals("POLL_CLOSED", fails(() -> voteService.vote(member(voter), p.id(), pick(optionId(p, 0)))).code());
        assertEquals("CLOSED", service.get(member(voter), p.id()).state());
        assertEquals("OPEN", polls.findById(p.id()).orElseThrow().getStatus().name()); // isleyici henuz calismadi

        assertTrue(closeJob.runOnce() >= 1);
        Poll closed = polls.findById(p.id()).orElseThrow();
        assertEquals(Poll.Status.CLOSED, closed.getStatus());
        assertNotNull(closed.getClosedAt());
        assertEquals("POLL_CLOSED", fails(() -> voteService.vote(member(voter), p.id(), pick(optionId(p, 0)))).code());
    }

    @Test
    void scheduledPollIsNotOpenYetAndDraftIsHiddenFromOthers() {
        User creator = user();
        User other = user();
        R later = new R();
        later.opens = OffsetDateTime.now().plusHours(3).toString();
        PollView scheduled = create(admin(creator), later);
        assertEquals("SCHEDULED", scheduled.state());
        assertEquals("POLL_NOT_OPEN", fails(() -> voteService.vote(member(other), scheduled.id(), pick(optionId(scheduled, 0)))).code());
        assertFalse(ids(service.list(member(other), "open", null, 50)).contains(scheduled.id()));
        assertTrue(ids(service.list(member(creator), "mine", null, 50)).contains(scheduled.id()));

        R draft = new R();
        draft.draft = true;
        PollView d = create(admin(creator), draft);
        assertEquals("DRAFT", d.status());
        assertEquals("POLL_NOT_FOUND", fails(() -> service.get(member(other), d.id())).code());
        assertEquals("POLL_NOT_FOUND", fails(() -> voteService.vote(member(other), d.id(), pick(optionId(d, 0)))).code());
        assertEquals("POLL_NOT_OPEN", fails(() -> voteService.vote(admin(creator), d.id(), pick(optionId(d, 0)))).code());

        PollView published = service.update(admin(creator), d.id(), new UpdateRequest(null, null, null, null, null, null, null,
                null, null, null, null, null, false));
        assertEquals("OPEN", published.status());
        assertEquals(1, voteService.vote(member(other), d.id(), pick(optionId(d, 0))).totalVotes());
    }

    @Test
    void closedPollsAppearInClosedScopeAndCancelledOnesStopVoting() {
        User creator = user();
        User voter = user();
        PollView p = create(admin(creator), new R());
        service.close(admin(creator), p.id());
        assertTrue(ids(service.list(member(voter), "closed", null, 50)).contains(p.id()));
        assertFalse(ids(service.list(member(voter), "open", null, 50)).contains(p.id()));
        assertEquals("POLL_CLOSED", fails(() -> voteService.vote(member(voter), p.id(), pick(optionId(p, 0)))).code());
        service.close(admin(creator), p.id()); // idempotent

        PollView q = create(admin(creator), new R());
        service.cancel(q.id());
        assertEquals("CANCELLED", service.get(member(voter), q.id()).state());
        assertEquals("POLL_CLOSED", fails(() -> voteService.vote(member(voter), q.id(), pick(optionId(q, 0)))).code());
    }

    // ---------- guncelleme / silme ----------

    @Test
    void votedPollLocksStructureButAllowsTitleAndExtendingClose() {
        User creator = user();
        User voter = user();
        PollView p = create(admin(creator), new R());
        voteService.vote(member(voter), p.id(), pick(optionId(p, 0)));

        ApiException locked = fails(() -> service.update(admin(creator), p.id(), new UpdateRequest(null, null, null,
                List.of("X", "Y"), null, null, null, null, null, null, null, null, null)));
        assertEquals("POLL_LOCKED", locked.code());
        assertEquals("POLL_LOCKED", fails(() -> service.update(admin(creator), p.id(), new UpdateRequest(null, null, null, null,
                null, true, null, null, null, null, null, null, null))).code());

        PollView ok = service.update(admin(creator), p.id(), new UpdateRequest("Yeni baslik", null, null, null, null, null, null,
                "AFTER_CLOSE", null, null, OffsetDateTime.now().plusDays(5).toString(), null, null));
        assertEquals("Yeni baslik", ok.title());
        assertEquals("AFTER_CLOSE", ok.showResults());
        assertEquals(1, options.findByPollIdOrderByPositionAsc(p.id()).stream().mapToInt(PollOption::getVoteCount).sum());
        assertEquals("POLL_FORBIDDEN", fails(() -> service.update(member(voter), p.id(), new UpdateRequest("Hack", null, null,
                null, null, null, null, null, null, null, null, null, null))).code());
    }

    @Test
    void optionsCanBeReplacedWhileNoVotesExist() {
        User creator = user();
        PollView p = create(admin(creator), new R());
        PollView v = service.update(admin(creator), p.id(), new UpdateRequest(null, null, null, List.of("Evet", "Hayir"), null,
                null, null, null, null, null, null, null, null));
        assertEquals(2, v.options().size());
        assertEquals("Evet", v.options().get(0).text());
    }

    @Test
    void deleteRemovesPollOptionsBallotsAndVotes() {
        User creator = user();
        User voter = user();
        PollView p = create(admin(creator), new R());
        voteService.vote(member(voter), p.id(), pick(optionId(p, 1)));

        assertEquals("POLL_FORBIDDEN", fails(() -> service.delete(member(voter), p.id())).code());
        service.delete(admin(creator), p.id());

        assertTrue(polls.findById(p.id()).isEmpty());
        assertTrue(options.findByPollIdOrderByPositionAsc(p.id()).isEmpty());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM poll_vote WHERE poll_id = ?", Integer.class, p.id()));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM poll_ballot WHERE poll_id = ?", Integer.class, p.id()));
        assertEquals("POLL_NOT_FOUND", fails(() -> service.get(member(voter), p.id())).code());
    }

    // ---------- kulup secimi (kapsam) ----------

    @Test
    void clubElectionIsAnonymousMembersOnlyAndManagedByClubAdmins() {
        User owner = user();
        User plain = user();
        User outsider = user();
        Community c = club(owner);
        join(c, plain, CommunityMember.Role.MEMBER);

        R election = new R();
        election.scope = "COMMUNITY";
        election.communityId = c.getId();
        election.title = "Baskan secimi";
        election.options = List.of("Aday 1", "Aday 2");
        election.show = "AFTER_CLOSE";
        assertEquals("POLL_FORBIDDEN", fails(() -> create(member(plain), election)).code()); // duz uye olusturamaz
        PollView p = create(member(owner), election);

        assertTrue(p.anonymous()); // kulup anketinde varsayilan gizli oy
        assertEquals(c.getId(), p.communityId());
        assertNotNull(p.communityName());
        assertTrue(service.get(member(owner), p.id()).canManage());
        assertFalse(service.get(member(plain), p.id()).canManage());

        PollView voted = voteService.vote(member(plain), p.id(), pick(optionId(p, 0)));
        assertTrue(voted.canVote()); // degistirebilir
        assertEquals("POLL_NOT_ELIGIBLE", fails(() -> voteService.vote(member(outsider), p.id(), pick(optionId(p, 0)))).code());
        assertEquals("POLL_NOT_FOUND", fails(() -> service.get(member(outsider), p.id())).code());
        assertEquals("POLL_NOT_ELIGIBLE", fails(() -> service.list(member(outsider), "community:" + c.getId(), null, 20)).code());

        assertTrue(ids(service.list(member(plain), "open", null, 50)).contains(p.id()));
        assertFalse(ids(service.list(member(outsider), "open", null, 50)).contains(p.id()));
        assertTrue(ids(service.list(member(plain), "community:" + c.getId(), null, 50)).contains(p.id()));

        // sonuc kapaninca; katilim orani uye sayisina gore
        service.close(member(owner), p.id());
        PollView result = service.get(member(plain), p.id());
        assertTrue(result.resultsVisible());
        assertEquals(1, result.turnout().voted());
        assertEquals(2, result.turnout().eligible());
        assertEquals(50.0, result.turnout().percent());

        // sonradan uye olan eski anketi gorur ama kapali oldugu icin oy veremez
        assertEquals("POLL_CLOSED", fails(() -> voteService.vote(member(plain), p.id(), pick(optionId(p, 1)))).code());
    }

    @Test
    void clubAdminRoleManagesAndOutsiderCannotCreateForClub() {
        User owner = user();
        User clubAdmin = user();
        User outsider = user();
        Community c = club(owner);
        join(c, clubAdmin, CommunityMember.Role.ADMIN);
        R r = new R();
        r.scope = "COMMUNITY";
        r.communityId = c.getId();

        assertNotNull(create(member(clubAdmin), r).id());
        assertEquals("POLL_FORBIDDEN", fails(() -> create(member(outsider), r)).code());
        R missing = new R();
        missing.scope = "COMMUNITY";
        assertEquals("POLL_INVALID", fails(() -> create(member(owner), missing)).code());
        R unknown = new R();
        unknown.scope = "COMMUNITY";
        unknown.communityId = 987654L;
        assertEquals("POLL_NOT_FOUND", fails(() -> create(member(owner), unknown)).code());
    }

    // ---------- hedef kitle ----------

    @Test
    void audienceFiltersListsAndVotesCaseInsensitively() {
        User creator = user();
        User match = user("Muhendislik", "Bilgisayar Muhendisligi", "2");
        User other = user("Fen", "Matematik", "1");
        User noProfile = user();
        R r = new R();
        r.audience = new Audience(null, "bilgisayar muhendisligi", null);
        PollView p = create(admin(creator), r);
        assertEquals("bilgisayar muhendisligi", p.audience().department());

        assertTrue(service.get(member(match), p.id()).canVote());
        PollView blocked = service.get(member(other), p.id());
        assertFalse(blocked.canVote());
        assertEquals("NOT_ELIGIBLE", blocked.voteBlockedReason());
        assertEquals("POLL_NOT_ELIGIBLE", fails(() -> voteService.vote(member(other), p.id(), pick(optionId(p, 0)))).code());
        assertEquals("POLL_NOT_ELIGIBLE", fails(() -> voteService.vote(member(noProfile), p.id(), pick(optionId(p, 0)))).code());
        assertTrue(ids(service.list(member(match), "open", null, 50)).contains(p.id()));
        assertFalse(ids(service.list(member(other), "open", null, 50)).contains(p.id()));
        assertEquals(1, voteService.vote(member(match), p.id(), pick(optionId(p, 0))).totalVotes());
    }

    // ---------- yemek menusu ----------

    @Test
    void todaysMenuPollIsCreatedOnceFromTheMenuAndRatesWithStars() {
        LocalDate today = LocalDate.now(PollAccess.ZONE);
        menus.findByMenuDate(today).ifPresent(menus::delete);
        polls.findByMenuDate(today).ifPresent(p -> service.delete(new Actor(1L, true), p.getId()));
        User voter = user();
        User voter2 = user();
        assertTrue(menuService.today(member(voter)).isEmpty()); // yemek listesi yok -> 204

        MenuDay day = new MenuDay();
        day.setMenuDate(today);
        day.setItems("Mercimek corbasi\nPilav\nAyran");
        menus.saveAndFlush(day);

        PollView p = menuService.today(member(voter)).orElseThrow();
        assertEquals("MENU", p.scope());
        assertEquals("RATING", p.type());
        assertEquals(5, p.options().size());
        assertEquals(List.of("Mercimek corbasi", "Pilav", "Ayran"), p.menuItems());
        assertEquals(today, p.menuDate());
        assertNull(p.createdBy());
        assertEquals(p.id(), menuService.today(member(voter2)).orElseThrow().id()); // gun basina tek anket
        assertEquals(1, polls.findAll().stream().filter(x -> today.equals(x.getMenuDate())).count());

        voteService.vote(member(voter), p.id(), new VoteRequest(null, 5));
        PollView v = voteService.vote(member(voter2), p.id(), new VoteRequest(null, 3));
        assertEquals(4.0, v.average());
        assertEquals(2, v.ratingCount());

        // gunluk anket bos listeden yonetici tarafindan da ayni gun icin yeniden olusturulamaz
        R again = new R();
        again.scope = "MENU";
        again.type = "RATING";
        again.options = null;
        assertEquals("POLL_MENU_EXISTS", fails(() -> create(new Actor(voter.getId(), true), again)).code());

        // diger testlere artik birakma: bugunun menusu ve anketi silinir
        service.delete(new Actor(1L, true), p.id());
        menus.delete(menus.findByMenuDate(today).orElseThrow());
    }

    // ---------- yaris guvenligi ----------

    @Test
    void concurrentVotesFromManyUsersAreAllCountedExactlyOnce() throws Exception {
        User creator = user();
        PollView p = create(admin(creator), new R());
        int n = 8;
        List<User> voters = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            voters.add(user());
        }
        runParallel(n, i -> voteService.vote(member(voters.get(i)), p.id(), pick(optionId(p, i % 3))));

        Poll row = polls.findById(p.id()).orElseThrow();
        assertEquals(n, row.getVoterCount());
        assertEquals(n, options.findByPollIdOrderByPositionAsc(p.id()).stream().mapToInt(PollOption::getVoteCount).sum());
        assertEquals(n, jdbc.queryForObject("SELECT COUNT(*) FROM poll_ballot WHERE poll_id = ?", Integer.class, p.id()));
    }

    @Test
    void sameUserVotingConcurrentlyNeverDoubleCounts() throws Exception {
        User creator = user();
        User voter = user();
        PollView p = create(admin(creator), new R());
        runParallel(8, i -> voteService.vote(member(voter), p.id(), pick(optionId(p, i % 3))));

        Poll row = polls.findById(p.id()).orElseThrow();
        assertEquals(1, row.getVoterCount());
        assertEquals(1, options.findByPollIdOrderByPositionAsc(p.id()).stream().mapToInt(PollOption::getVoteCount).sum());
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM poll_vote WHERE poll_id = ?", Integer.class, p.id()));
        assertEquals(1, ballots.findAll().stream().filter(b -> b.getPollId().equals(p.id())).count());
    }

    private void runParallel(int n, java.util.function.IntConsumer task) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<?>> fs = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            int idx = i;
            fs.add(pool.submit(() -> {
                go.await();
                task.accept(idx);
                return null;
            }));
        }
        go.countDown();
        for (Future<?> f : fs) {
            f.get(30, TimeUnit.SECONDS);
        }
        pool.shutdown();
    }

    // ---------- gizli oy ve KVKK ----------

    @Test
    void anonymousVoteIsNeverExposedToOthersOrAdminsAndOnlyInOwnExport() {
        User creator = user();
        User voter = user();
        User other = user();
        R r = new R();
        r.anonymous = true;
        PollView p = create(admin(creator), r);
        voteService.vote(member(voter), p.id(), pick(optionId(p, 1)));

        // baskasi kendi gorunumunde oy gormez
        assertNull(service.get(member(other), p.id()).myVote());
        // yonetici gorunumu yalniz toplam; olusturan kimligi disinda kullanici kimligi tasimaz
        String adminJson = adminService.get(admin(creator), p.id()).toString();
        assertFalse(adminJson.contains("userId=" + voter.getId()));
        String csv = adminService.csv(p.id());
        assertFalse(csv.contains(String.valueOf(voter.getId())) && csv.contains("user"));
        assertTrue(csv.startsWith("optionId,text,count,percent,score"));

        // kullanicinin kendi dosyasinda secimi gorunur
        DataExporter polls = exporters.stream().filter(e -> "polls".equals(e.section())).findFirst().orElseThrow();
        @SuppressWarnings("unchecked")
        Map<String, Object> mine = (Map<String, Object>) polls.export(voter.getId());
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> voted = (List<Map<String, Object>>) mine.get("votes");
        assertEquals(1, voted.size());
        assertEquals("B", voted.get(0).get("optionText"));
        @SuppressWarnings("unchecked")
        Map<String, Object> others = (Map<String, Object>) polls.export(other.getId());
        assertTrue(((List<?>) others.get("votes")).isEmpty());
    }

    @Test
    void accountDeletionAnonymizesVotesButKeepsCounters() throws Exception {
        User creator = user();
        User voter = user();
        User stays = user();
        PollView p = create(admin(creator), new R());
        voteService.vote(member(voter), p.id(), pick(optionId(p, 0)));
        voteService.vote(member(stays), p.id(), pick(optionId(p, 0)));

        // AccountDataPurger'in anket ifadeleri (H2'de diger tablolarin tumu yok: yalniz poll satirlari calistirilir)
        for (String field : new String[] {"DELETES", "SCRUBS"}) {
            java.lang.reflect.Field f = edu.bingol.backend.profile.AccountDataPurger.class.getDeclaredField(field);
            f.setAccessible(true);
            @SuppressWarnings("unchecked")
            List<String> sqls = (List<String>) f.get(null);
            sqls.stream().filter(s -> s.contains("poll")).forEach(s -> jdbc.update(s, voter.getId()));
        }

        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM poll_vote WHERE user_id = ?", Integer.class, voter.getId()));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM poll_ballot WHERE user_id = ?", Integer.class, voter.getId()));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM poll_vote WHERE poll_id = ? AND user_id IS NULL", Integer.class, p.id()));
        PollView after = service.get(member(stays), p.id());
        assertEquals(2, after.totalVotes()); // sayaclar korunur
        assertEquals(2, count(after, 0));
        assertEquals(1, ballots.findAll().stream().filter(b -> b.getPollId().equals(p.id())).count());

        // olusturan silinince createdBy bosalir
        jdbc.update("UPDATE poll SET created_by = NULL WHERE created_by = ?", creator.getId());
        assertNull(service.get(member(stays), p.id()).createdBy());
    }

    // ---------- listeleme, yonetici, CSV ----------

    @Test
    void listPaginatesWithCursorWithoutDuplicates() {
        User creator = user();
        User viewer = user();
        for (int i = 0; i < 5; i++) {
            R r = new R();
            r.title = "Sayfa " + i;
            create(admin(creator), r);
        }
        Set<Long> seen = new HashSet<>();
        Long cursor = null;
        int pages = 0;
        do {
            PollPage page = service.list(member(viewer), "open", cursor, 2);
            for (PollView v : page.items()) {
                assertTrue(seen.add(v.id()), "tekrar eden kayit");
            }
            cursor = page.nextCursor();
            pages++;
        } while (cursor != null && pages < 100);
        assertTrue(seen.size() >= 5);
        assertEquals("POLL_SCOPE_INVALID", fails(() -> service.list(member(viewer), "bilinmeyen", null, 10)).code());
        assertEquals("POLL_SCOPE_INVALID", fails(() -> service.list(member(viewer), "community:abc", null, 10)).code());
    }

    @Test
    void mineListsPollsICreatedAndPollsIVotedIn() {
        User creator = user();
        User voter = user();
        PollView p = create(admin(creator), new R());
        assertFalse(ids(service.list(member(voter), "mine", null, 50)).contains(p.id()));
        voteService.vote(member(voter), p.id(), pick(optionId(p, 0)));
        assertTrue(ids(service.list(member(voter), "mine", null, 50)).contains(p.id()));
        assertTrue(ids(service.list(member(creator), "mine", null, 50)).contains(p.id()));
    }

    @Test
    void adminListStatsBulkAndCsvEscaping() {
        User creator = user();
        User voter = user();
        R r = new R();
        r.options = List.of("=HYPERLINK(1)", "Normal, virgullu");
        r.title = "Admin " + UUID.randomUUID();
        PollView p = create(admin(creator), r);
        voteService.vote(member(voter), p.id(), pick(optionId(p, 0)));

        var page = adminService.list("OPEN", "GLOBAL", r.title.substring(0, 12), 0, 10);
        assertTrue(page.items().stream().anyMatch(x -> x.id().equals(p.id()) && x.totalVotes() == 1));
        assertTrue(adminService.stats().total() >= 1);
        assertTrue(adminService.stats().totalVotes() >= 1);

        String csv = adminService.csv(p.id());
        assertTrue(csv.contains("'=HYPERLINK(1)"), "formul etkisizlestirilmeli");
        assertTrue(csv.contains("\"Normal, virgullu\""));

        PollView q = create(admin(creator), new R());
        var res = adminService.bulk(admin(creator), List.of(p.id(), q.id(), 424242L), "CLOSE");
        assertEquals(2, res.done());
        assertEquals(1, res.skipped());
        assertEquals("CLOSED", polls.findById(q.id()).orElseThrow().getStatus().name());
        assertEquals("POLL_INVALID", fails(() -> adminService.bulk(admin(creator), List.of(1L), "NUKE")).code());
        assertEquals("POLL_NOT_FOUND", fails(() -> adminService.csvFor(member(voter), 424242L)).code());
        assertEquals("POLL_NOT_FOUND", fails(() -> adminService.csvFor(member(voter), p.id())).code()); // yonetici degil
    }

    // ---------- bildirimler ----------

    @Test
    void openedNotificationGoesOnlyToClubMembersAndOnlyOnce() throws Exception {
        User owner = user();
        User memberUser = user();
        User outsider = user();
        Community c = club(owner);
        join(c, memberUser, CommunityMember.Role.MEMBER);
        R r = new R();
        r.scope = "COMMUNITY";
        r.communityId = c.getId();
        r.notify = true;
        PollView p = create(member(owner), r);

        for (int i = 0; i < 60 && polls.findById(p.id()).orElseThrow().getOpenedNotifiedAt() == null; i++) {
            Thread.sleep(100);
        }
        assertNotNull(polls.findById(p.id()).orElseThrow().getOpenedNotifiedAt());
        for (int i = 0; i < 60 && notificationCount(memberUser) < 1; i++) {
            Thread.sleep(100);
        }
        assertEquals(1, notificationCount(memberUser));
        assertEquals(0, notificationCount(outsider));
        assertFalse(notifier.notifyOpened(p.id())); // ikinci gonderim yok

        R quiet = new R();
        quiet.scope = "COMMUNITY";
        quiet.communityId = c.getId();
        PollView q = create(member(owner), quiet); // notify=false
        Thread.sleep(300);
        assertNull(polls.findById(q.id()).orElseThrow().getOpenedNotifiedAt());
        assertFalse(notifier.notifyOpened(q.id()));
    }

    private int notificationCount(User u) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM notification WHERE user_id = ?", Integer.class, u.getId());
        return n == null ? 0 : n;
    }

    @Test
    void closingSoonReminderSkipsUsersWhoAlreadyVoted() throws Exception {
        User owner = user();
        User voted = user();
        User pending = user();
        Community c = club(owner);
        join(c, voted, CommunityMember.Role.MEMBER);
        join(c, pending, CommunityMember.Role.MEMBER);
        R r = new R();
        r.scope = "COMMUNITY";
        r.communityId = c.getId();
        r.notify = true;
        r.closes = OffsetDateTime.now().plusHours(20).toString();
        PollView p = create(member(owner), r);
        // once "acildi" bildirimi (asenkron) iki uyeye de ulassin
        for (int i = 0; i < 80 && (polls.findById(p.id()).orElseThrow().getOpenedNotifiedAt() == null
                || notificationCount(voted) < 1 || notificationCount(pending) < 1); i++) {
            Thread.sleep(100);
        }
        voteService.vote(member(voted), p.id(), pick(optionId(p, 0)));
        int before = notificationCount(voted);
        int beforePending = notificationCount(pending);

        jdbc.update("UPDATE poll SET closing_notified_at = NULL WHERE id = ?", p.id());
        assertTrue(notifier.notifyClosingSoon(polls.findById(p.id()).orElseThrow()));

        assertEquals(before, notificationCount(voted)); // oy vermis olana hatirlatma yok
        assertEquals(beforePending + 1, notificationCount(pending));
        assertFalse(notifier.notifyClosingSoon(polls.findById(p.id()).orElseThrow())); // bir kez
    }

    private static List<Long> ids(PollPage page) {
        return page.items().stream().map(PollView::id).toList();
    }
}
