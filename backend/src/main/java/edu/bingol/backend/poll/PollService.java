package edu.bingol.backend.poll;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.menu.MenuRepository;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.poll.PollDtos.Audience;
import edu.bingol.backend.poll.PollDtos.CreateRequest;
import edu.bingol.backend.poll.PollDtos.PollPage;
import edu.bingol.backend.poll.PollDtos.PollView;
import edu.bingol.backend.poll.PollDtos.UpdateRequest;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.function.BiFunction;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Anket olusturma, guncelleme, kapatma, silme ve listeleme kurallari. Oy verme: {@link PollVoteService}. */
@Service
public class PollService {

    static final int MIN_OPTIONS = 2;
    static final int MAX_OPTIONS = 12;
    static final int MAX_TITLE = 150;
    static final int MAX_DESCRIPTION = 1000;
    static final int MAX_OPTION_TEXT = 100;
    private static final int FETCH = 50;
    private static final int MAX_ROUNDS = 8;

    private final PollRepository polls;
    private final PollOptionRepository options;
    private final PollBallotRepository ballots;
    private final PollVoteRepository votes;
    private final PollAccess access;
    private final PollViewAssembler assembler;
    private final CommunityRepository communities;
    private final MenuRepository menus;
    private final UserRepository users;
    private final ContentGuard guard;
    private final ApplicationEventPublisher events;
    private final I18n i18n;
    private final Clock clock;

    public PollService(PollRepository polls, PollOptionRepository options, PollBallotRepository ballots,
                       PollVoteRepository votes, PollAccess access, PollViewAssembler assembler,
                       CommunityRepository communities, MenuRepository menus, UserRepository users, ContentGuard guard,
                       ApplicationEventPublisher events, I18n i18n, Clock clock) {
        this.polls = polls;
        this.options = options;
        this.ballots = ballots;
        this.votes = votes;
        this.access = access;
        this.assembler = assembler;
        this.communities = communities;
        this.menus = menus;
        this.users = users;
        this.guard = guard;
        this.events = events;
        this.i18n = i18n;
        this.clock = clock;
    }

    // ---------- okuma ----------

    @Transactional(readOnly = true)
    public PollView get(Actor actor, Long id) {
        Poll p = polls.findById(id).orElseThrow(PollService::notFound);
        if (!access.canView(p, actor, access.memberCommunityIds(actor.id()))) {
            throw notFound();
        }
        return assembler.view(p, actor, false);
    }

    @Transactional(readOnly = true)
    public PollPage list(Actor actor, String scope, Long cursor, int size) {
        int n = CursorPage.clampSize(size);
        long start = cursor == null || cursor <= 0 ? Long.MAX_VALUE : cursor;
        String s = scope == null || scope.isBlank() ? "open" : scope.trim().toLowerCase(Locale.ROOT);
        Set<Long> cids = access.memberCommunityIds(actor.id());
        List<Long> cidList = PollAccess.idsOrSentinel(cids);
        User me = users.findById(actor.id()).orElse(null);
        Instant now = clock.instant();
        BiFunction<Long, Pageable, List<Poll>> fetch;
        boolean audienceFilter = false;
        switch (s) {
            case "open" -> {
                fetch = (c, pg) -> polls.open(c, now, cidList, pg);
                audienceFilter = true;
            }
            case "closed" -> {
                fetch = (c, pg) -> polls.closed(c, now, cidList, pg);
                audienceFilter = true;
            }
            case "mine" -> fetch = (c, pg) -> polls.mine(c, actor.id(), pg);
            default -> {
                if (!s.startsWith("community:")) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "POLL_SCOPE_INVALID", "Geçersiz anket kapsamı.");
                }
                Long cid = parseId(s.substring("community:".length()));
                if (!actor.admin() && !cids.contains(cid)) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "POLL_NOT_ELIGIBLE", "Bu ankete katılma hakkınız yok.");
                }
                boolean draft = access.isClubManager(cid, actor);
                fetch = (c, pg) -> polls.ofCommunity(c, cid, draft, pg);
            }
        }
        List<Poll> accepted = new ArrayList<>();
        long c = start;
        boolean exhausted = false;
        for (int round = 0; round < MAX_ROUNDS && accepted.size() <= n && !exhausted; round++) {
            List<Poll> batch = fetch.apply(c, PageRequest.of(0, FETCH));
            exhausted = batch.size() < FETCH;
            for (Poll p : batch) {
                c = p.getId();
                boolean ok = access.canView(p, actor, cids)
                        && (!audienceFilter || access.audienceMatches(p, me) || access.canManage(p, actor));
                if (ok) {
                    accepted.add(p);
                    if (accepted.size() > n) {
                        break;
                    }
                }
            }
        }
        boolean more = accepted.size() > n;
        List<Poll> page = more ? accepted.subList(0, n) : accepted;
        Long next = more ? page.get(page.size() - 1).getId() : (exhausted ? null : c);
        long openCount = countOpen(actor, me, cidList, now);
        long total = switch (s) {
            case "open" -> openCount;
            case "closed" -> polls.countClosed(now, cidList, actor.admin(), audNorm(me == null ? null : me.getFaculty()),
                    audNorm(me == null ? null : me.getDepartment()), audNorm(me == null ? null : me.getGrade()));
            case "mine" -> polls.countMine(actor.id());
            default -> {
                Long cid = parseId(s.substring("community:".length()));
                yield polls.countOfCommunity(cid, access.isClubManager(cid, actor));
            }
        };
        return new PollPage(assembler.views(page, actor, false), next, total, openCount);
    }

    private long countOpen(Actor actor, User me, List<Long> cidList, Instant now) {
        return polls.countOpen(now, cidList, actor.admin(), audNorm(me == null ? null : me.getFaculty()),
                audNorm(me == null ? null : me.getDepartment()), audNorm(me == null ? null : me.getGrade()));
    }

    /** Hedef kitle karsilastirmasi icin kucuk harf/kirpilmis deger; bos profil alani hicbir kitleyle eslesmesin diye ayirici deger. */
    private static String audNorm(String v) {
        return v == null || v.isBlank() ? "#none#" : v.trim().toLowerCase(Locale.ROOT);
    }

    // ---------- olusturma ----------

    @Transactional
    public PollView create(Actor actor, CreateRequest r) {
        Built b = build(actor, r);
        Poll p = polls.saveAndFlush(b.poll());
        writeOptions(p.getId(), b.texts());
        if (p.getStatus() == Poll.Status.OPEN) {
            events.publishEvent(new PollPublished(p.getId()));
        }
        return assembler.view(polls.findById(p.getId()).orElseThrow(), actor, false);
    }

    /** Dogrulanmis anket nesnesi (secenekler henuz yazilmadi; saveOptions ayri). Menu anketi de buradan gecer. */
    private Built build(Actor actor, CreateRequest r) {
        Instant now = clock.instant();
        Poll.Scope scope = parseEnum(Poll.Scope.class, r.scope(), r.communityId() != null ? Poll.Scope.COMMUNITY : Poll.Scope.GLOBAL,
                "poll.invalid.scope");
        Poll.Type type = parseEnum(Poll.Type.class, r.type(), scope == Poll.Scope.MENU ? Poll.Type.RATING : Poll.Type.SINGLE,
                "poll.invalid.type");
        Poll p = new Poll();
        p.setScope(scope);
        p.setType(type);
        switch (scope) {
            case GLOBAL -> requireAdmin(actor);
            case MENU -> {
                requireAdmin(actor);
                if (type != Poll.Type.RATING) {
                    throw invalid("poll.invalid.menuType");
                }
                LocalDate day = r.menuDate() == null ? LocalDate.now(PollAccess.ZONE) : r.menuDate();
                if (menus.findByMenuDate(day).isEmpty()) {
                    throw new ApiException(HttpStatus.NOT_FOUND, "POLL_MENU_NOT_FOUND", "Bu gün için yemek listesi yok.");
                }
                if (polls.findByMenuDate(day).isPresent()) {
                    throw new ApiException(HttpStatus.CONFLICT, "POLL_MENU_EXISTS", "Bu gün için menü anketi zaten var.");
                }
                p.setMenuDate(day);
            }
            case COMMUNITY -> {
                if (r.communityId() == null) {
                    throw invalid("poll.invalid.community");
                }
                Community c = communities.findById(r.communityId()).orElse(null);
                if (c == null || c.getStatus() != Community.Status.ACTIVE) {
                    throw notFound();
                }
                if (!access.isClubManager(c.getId(), actor)) {
                    throw forbidden();
                }
                p.setCommunityId(c.getId());
            }
        }
        applyText(p, r.title(), r.description(), actor.id(), true);
        List<String> texts = type == Poll.Type.RATING ? ratingTexts() : cleanOptions(r.options(), actor.id());
        p.setMaxChoices((short) maxChoices(type, r.maxChoices(), texts.size()));
        p.setAnonymous(r.anonymous() != null ? r.anonymous() : scope == Poll.Scope.COMMUNITY);
        p.setAllowChangeVote(r.allowChangeVote() == null || r.allowChangeVote());
        p.setShowResults(parseEnum(Poll.ShowResults.class, r.showResults(), Poll.ShowResults.ALWAYS, "poll.invalid.showResults"));
        p.setNotify(Boolean.TRUE.equals(r.notifyUsers()) && scope != Poll.Scope.MENU);
        Instant opens = r.opensAt() == null || r.opensAt().isBlank() ? now : parseTime(r.opensAt());
        Instant closes = r.closesAt() == null || r.closesAt().isBlank() ? null : parseTime(r.closesAt());
        checkWindow(opens, closes, now);
        p.setOpensAt(opens);
        p.setClosesAt(closes);
        applyAudience(p, r.audience());
        p.setCreatedBy(actor.id());
        p.setStatus(Boolean.TRUE.equals(r.draft()) ? Poll.Status.DRAFT : Poll.Status.OPEN);
        p.setCreatedAt(now);
        p.setUpdatedAt(now);
        return new Built(p, texts);
    }

    private record Built(Poll poll, List<String> texts) {}

    private void writeOptions(Long pollId, List<String> texts) {
        List<PollOption> rows = new ArrayList<>();
        for (int i = 0; i < texts.size(); i++) {
            rows.add(new PollOption(pollId, i + 1, texts.get(i)));
        }
        options.saveAll(rows);
    }

    /** Otomatik menu anketi (sistem tarafindan, yetki gerekmez). Bos doner: gun icin zaten varsa. */
    @Transactional
    public Poll createMenuPoll(LocalDate day) {
        Instant open = day.atStartOfDay(PollAccess.ZONE).toInstant();
        Poll p = new Poll();
        p.setScope(Poll.Scope.MENU);
        p.setType(Poll.Type.RATING);
        p.setTitle("Bugünün menüsünü puanla");
        p.setMenuDate(day);
        p.setMaxChoices((short) 1);
        p.setAnonymous(true);
        p.setAllowChangeVote(true);
        p.setShowResults(Poll.ShowResults.ALWAYS);
        p.setOpensAt(open);
        p.setClosesAt(day.plusDays(1).atStartOfDay(PollAccess.ZONE).toInstant());
        p.setStatus(Poll.Status.OPEN);
        p = polls.saveAndFlush(p);
        writeOptions(p.getId(), ratingTexts());
        return p;
    }

    // ---------- guncelleme ----------

    @Transactional
    public PollView update(Actor actor, Long id, UpdateRequest r) {
        Poll p = polls.lockById(id).orElseThrow(PollService::notFound);
        requireManage(p, actor);
        if (p.isFinished() || p.isClosedAt(clock.instant())) {
            throw new ApiException(HttpStatus.CONFLICT, "POLL_CLOSED", "Bu anket kapalı.");
        }
        Instant now = clock.instant();
        boolean hasVotes = p.getStatus() == Poll.Status.OPEN && p.getVoterCount() > 0;
        List<PollOption> current = options.findByPollIdOrderByPositionAsc(id);
        boolean structural = false;
        if (r.title() != null || r.description() != null) {
            applyText(p, r.title() != null ? r.title() : p.getTitle(),
                    r.description() != null ? r.description() : p.getDescription(), actor.id(), false);
        }
        if (r.showResults() != null) {
            p.setShowResults(parseEnum(Poll.ShowResults.class, r.showResults(), p.getShowResults(), "poll.invalid.showResults"));
        }
        if (r.notifyUsers() != null) {
            p.setNotify(r.notifyUsers() && p.getScope() != Poll.Scope.MENU);
        }
        Poll.Type newType = r.type() == null ? p.getType() : parseEnum(Poll.Type.class, r.type(), p.getType(), "poll.invalid.type");
        if (newType != p.getType()) {
            structural = true;
        }
        List<String> newTexts = null;
        if (r.options() != null && newType != Poll.Type.RATING) {
            newTexts = cleanOptions(r.options(), actor.id());
            if (!newTexts.equals(current.stream().map(PollOption::getText).toList())) {
                structural = true;
            } else {
                newTexts = null;
            }
        } else if (newType == Poll.Type.RATING && p.getType() != Poll.Type.RATING) {
            newTexts = ratingTexts();
        } else if (newType != Poll.Type.RATING && p.getType() == Poll.Type.RATING && r.options() == null) {
            throw invalid("poll.invalid.options");
        }
        if (r.anonymous() != null && r.anonymous() != p.isAnonymous()) {
            structural = true;
        }
        if (r.allowChangeVote() != null && r.allowChangeVote() != p.isAllowChangeVote()) {
            structural = true;
        }
        int optCount = newTexts != null ? newTexts.size() : current.size();
        Integer requestedMax = r.maxChoices();
        Integer base = requestedMax != null ? requestedMax
                : (newType == p.getType() && p.getMaxChoices() <= optCount ? Integer.valueOf(p.getMaxChoices()) : null);
        int newMax = maxChoices(newType, base, optCount);
        if (newMax != p.getMaxChoices()) {
            structural = true;
        }
        Audience aud = r.audience();
        if (aud != null && !sameAudience(p, aud)) {
            structural = true;
        }
        Instant opens = p.getOpensAt();
        if (r.opensAt() != null && !r.opensAt().isBlank()) {
            opens = parseTime(r.opensAt());
            if (!opens.equals(p.getOpensAt())) {
                structural = true;
            }
        }
        Instant closes = p.getClosesAt();
        if (r.closesAt() != null) {
            closes = r.closesAt().isBlank() ? null : parseTime(r.closesAt());
        }
        if (hasVotes && structural) {
            throw new ApiException(HttpStatus.CONFLICT, "POLL_LOCKED", "Oy alınmış ankette bu alan değiştirilemez.");
        }
        checkWindow(opens, closes, now);
        if (structural) {
            p.setType(newType);
            if (newTexts != null) {
                options.deleteByPollId(id);
                writeOptions(id, newTexts);
            }
            p.setMaxChoices((short) newMax);
            if (r.anonymous() != null) {
                p.setAnonymous(r.anonymous());
            }
            if (r.allowChangeVote() != null) {
                p.setAllowChangeVote(r.allowChangeVote());
            }
            if (aud != null) {
                applyAudience(p, aud);
            }
        }
        p.setOpensAt(opens);
        p.setClosesAt(closes);
        boolean publish = p.getStatus() == Poll.Status.DRAFT && Boolean.FALSE.equals(r.draft());
        if (publish) {
            p.setStatus(Poll.Status.OPEN);
        }
        p.setUpdatedAt(now);
        polls.save(p);
        if (publish) {
            events.publishEvent(new PollPublished(p.getId()));
        }
        return assembler.view(polls.findById(id).orElseThrow(), actor, false);
    }

    // ---------- durum degisiklikleri ----------

    /** Zamanlayici: suresi dolan acik anketi kapatir (yarisa karsi kilitli, idempotent). */
    @Transactional
    public boolean autoClose(Long id) {
        Poll p = polls.lockById(id).orElse(null);
        if (p == null || p.getStatus() != Poll.Status.OPEN || !p.isExpired(clock.instant())) {
            return false;
        }
        p.setStatus(Poll.Status.CLOSED);
        p.setClosedAt(p.getClosesAt());
        p.setUpdatedAt(clock.instant());
        polls.save(p);
        return true;
    }

    @Transactional
    public PollView close(Actor actor, Long id) {
        Poll p = polls.lockById(id).orElseThrow(PollService::notFound);
        requireManage(p, actor);
        closeLocked(p);
        return assembler.view(polls.findById(id).orElseThrow(), actor, false);
    }

    /** Erken kapatma (idempotent); iptal edilmis anketi yeniden acmaz. */
    void closeLocked(Poll p) {
        if (p.getStatus() == Poll.Status.CLOSED || p.getStatus() == Poll.Status.CANCELLED) {
            return;
        }
        p.setStatus(Poll.Status.CLOSED);
        p.setClosedAt(clock.instant());
        p.setUpdatedAt(clock.instant());
        polls.save(p);
    }

    /** Yonetici: iptal (oylar kapanir, sonuclar korunur). */
    @Transactional
    public void cancel(Long id) {
        Poll p = polls.lockById(id).orElseThrow(PollService::notFound);
        if (p.getStatus() == Poll.Status.CANCELLED) {
            return;
        }
        p.setStatus(Poll.Status.CANCELLED);
        p.setClosedAt(clock.instant());
        p.setUpdatedAt(clock.instant());
        polls.save(p);
    }

    @Transactional
    public void delete(Actor actor, Long id) {
        Poll p = polls.lockById(id).orElseThrow(PollService::notFound);
        requireManage(p, actor);
        deleteLocked(p);
    }

    void deleteLocked(Poll p) {
        votes.deleteByPollId(p.getId());
        ballots.deleteByPollId(p.getId());
        options.deleteByPollId(p.getId());
        polls.delete(p);
    }

    // ---------- yardimcilar ----------

    private void requireManage(Poll p, Actor actor) {
        if (!access.canManage(p, actor)) {
            if (access.canView(p, actor, access.memberCommunityIds(actor.id()))) {
                throw forbidden();
            }
            throw notFound();
        }
    }

    private static void requireAdmin(Actor actor) {
        if (!actor.admin()) {
            throw forbidden();
        }
    }

    private void applyText(Poll p, String title, String description, Long userId, boolean create) {
        String t = title == null ? "" : title.trim();
        if (t.isEmpty() || t.length() > MAX_TITLE) {
            throw invalid("poll.invalid.title");
        }
        String d = description == null || description.isBlank() ? null : description.trim();
        if (d != null && d.length() > MAX_DESCRIPTION) {
            throw invalid("poll.invalid.description");
        }
        guard.assertChanged(ContentGuard.Entity.OTHER, "title", userId, create ? null : p.getTitle(), t);
        guard.assertChanged(ContentGuard.Entity.OTHER, "description", userId, create ? null : p.getDescription(), d);
        p.setTitle(t);
        p.setDescription(d);
    }

    /** 2..12 benzersiz, bos olmayan, en cok 100 karakterlik secenek; kufur denetimi. */
    List<String> cleanOptions(List<String> raw, Long userId) {
        if (raw == null || raw.size() < MIN_OPTIONS || raw.size() > MAX_OPTIONS) {
            throw invalid("poll.invalid.options");
        }
        List<String> out = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < raw.size(); i++) {
            String t = raw.get(i) == null ? "" : raw.get(i).trim();
            if (t.isEmpty() || t.length() > MAX_OPTION_TEXT) {
                throw invalid("poll.invalid.optionText");
            }
            if (!seen.add(t.toLowerCase(Locale.ROOT))) {
                throw invalid("poll.invalid.optionDup");
            }
            guard.assertClean(ContentGuard.Entity.OTHER, "options[" + i + "]", userId, t);
            out.add(t);
        }
        return out;
    }

    static List<String> ratingTexts() {
        return List.of("1", "2", "3", "4", "5");
    }

    /** SINGLE/RATING: 1; MULTI/RANKED: 1..secenek sayisi (varsayilan hepsi). */
    int maxChoices(Poll.Type type, Integer requested, int optionCount) {
        if (type == Poll.Type.SINGLE || type == Poll.Type.RATING) {
            return 1;
        }
        int v = requested == null ? optionCount : requested;
        if (v < 1 || v > optionCount) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POLL_INVALID", "Anket bilgileri geçersiz.", i18n.current("poll.invalid.maxChoices"));
        }
        return v;
    }

    private void checkWindow(Instant opens, Instant closes, Instant now) {
        if (closes != null && (!closes.isAfter(opens) || !closes.isAfter(now))) {
            throw invalid("poll.invalid.time");
        }
    }

    private static boolean sameAudience(Poll p, Audience a) {
        return java.util.Objects.equals(norm(a.faculty()), p.getAudienceFaculty())
                && java.util.Objects.equals(norm(a.department()), p.getAudienceDepartment())
                && java.util.Objects.equals(norm(a.grade()), p.getAudienceGrade());
    }

    private void applyAudience(Poll p, Audience a) {
        String f = a == null ? null : norm(a.faculty());
        String d = a == null ? null : norm(a.department());
        String g = a == null ? null : norm(a.grade());
        if ((f != null && f.length() > 120) || (d != null && d.length() > 120) || (g != null && g.length() > 8)) {
            throw invalid("poll.invalid.audience");
        }
        p.setAudienceFaculty(f);
        p.setAudienceDepartment(d);
        p.setAudienceGrade(g);
    }

    private static String norm(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    /** ISO ofsetli ya da ofsetsiz (Istanbul) zaman. */
    Instant parseTime(String s) {
        try {
            return OffsetDateTime.parse(s.trim()).toInstant();
        } catch (DateTimeParseException e) {
            try {
                return LocalDateTime.parse(s.trim()).atZone(PollAccess.ZONE).toInstant();
            } catch (DateTimeParseException e2) {
                throw invalid("poll.invalid.time");
            }
        }
    }

    private <E extends Enum<E>> E parseEnum(Class<E> type, String raw, E fallback, String detailKey) {
        if (raw == null || raw.isBlank()) {
            return fallback;
        }
        try {
            return Enum.valueOf(type, raw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw invalid(detailKey);
        }
    }

    private ApiException invalid(String detailKey) {
        return new ApiException(HttpStatus.BAD_REQUEST, "POLL_INVALID", "Anket bilgileri geçersiz.", i18n.current(detailKey));
    }

    static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "POLL_NOT_FOUND", "Anket bulunamadı.");
    }

    static ApiException forbidden() {
        return new ApiException(HttpStatus.FORBIDDEN, "POLL_FORBIDDEN", "Bu işlem için yetkiniz yok.");
    }

    private static Long parseId(String s) {
        try {
            return Long.parseLong(s.trim());
        } catch (NumberFormatException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "POLL_SCOPE_INVALID", "Geçersiz anket kapsamı.");
        }
    }
}
