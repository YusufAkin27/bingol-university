package edu.bingol.backend.poll;

import edu.bingol.backend.academic.AudienceKey;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.user.User;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Anket gorunurluk, yonetim ve oy uygunlugu kararlarinin tek yeri. */
@Component
public class PollAccess {

    public static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final long COUNT_TTL_MS = 60_000;

    private final CommunityMemberRepository members;
    private final ClubPermissions clubPermissions;
    private final JdbcTemplate jdbc;
    private final CommunityRepository communities;
    private final Map<String, long[]> countCache = new ConcurrentHashMap<>();

    public PollAccess(CommunityMemberRepository members, ClubPermissions clubPermissions, JdbcTemplate jdbc,
                      CommunityRepository communities) {
        this.members = members;
        this.clubPermissions = clubPermissions;
        this.jdbc = jdbc;
        this.communities = communities;
    }

    /**
     * Kullanicinin aktif uyesi oldugu YAYINDAKI (ACTIVE) kulup kimlikleri. T-047: silinen / yayindan kalkan kulubun
     * anketi uyeye gorunmez ve oylanamaz (sistemde uyelik satirlari silme sonrasi da kalabilir).
     */
    public Set<Long> memberCommunityIds(Long userId) {
        Set<Long> ids = new HashSet<>();
        for (CommunityMember m : members.mine(userId, CommunityMember.Status.ACTIVE, Long.MAX_VALUE, PageRequest.of(0, 1000))) {
            ids.add(m.getCommunityId());
        }
        if (ids.isEmpty()) {
            return ids;
        }
        Set<Long> live = new HashSet<>();
        for (Community c : communities.findAllById(ids)) {
            if (c.getStatus() == Community.Status.ACTIVE) {
                live.add(c.getId());
            }
        }
        return live;
    }

    /** Sorgulara bos koleksiyon verilmesin diye yer tutucu eklenmis liste. */
    public static List<Long> idsOrSentinel(Set<Long> ids) {
        List<Long> l = new ArrayList<>(ids);
        if (l.isEmpty()) {
            l.add(-1L);
        }
        return l;
    }

    /** Hedef alan kisitsiz (bos) ya da kullanici degeriyle AYNI anahtar (T-042: Turkce I/i/ı/İ ailesi tek kural). */
    private static boolean keyMatch(String want, String have) {
        String w = AudienceKey.of(want);
        return w == null || w.equals(AudienceKey.of(have));
    }

    private static boolean gradeMatch(String want, String have) {
        return want == null || want.isBlank()
                || (have != null && want.strip().equalsIgnoreCase(have.strip()));
    }

    /** Hedef kitle (fakulte/bolum/sinif) kullanicinin profiliyle eslesiyor mu; bos alan kisitsiz. */
    public boolean audienceMatches(Poll p, User u) {
        if (!p.hasAudience()) {
            return true;
        }
        return u != null && keyMatch(p.getAudienceFaculty(), u.getFaculty())
                && keyMatch(p.getAudienceDepartment(), u.getDepartment()) && gradeMatch(p.getAudienceGrade(), u.getGrade());
    }

    public boolean isActiveMember(Long communityId, Long userId) {
        return communityId != null && members.findByCommunityIdAndUserId(communityId, userId)
                .filter(CommunityMember::isActive).isPresent();
    }

    /** Kulup yoneticisi (rol ADMIN/OWNER) ya da icerik yonetme izni olan sistem yoneticisi (T-040). */
    public boolean isClubManager(Long communityId, Actor a) {
        if (a.systemAdmin(PermissionMatrix.CONTENT_WRITE)) {
            return true;
        }
        return communityId != null && clubPermissions.standingOfUser(communityId, a.id())
                .map(s -> s.role() == CommunityMember.Role.ADMIN || s.role() == CommunityMember.Role.OWNER).orElse(false);
    }

    /** Duzenleme/kapatma/silme: sistem yoneticisi, kulup yoneticisi ya da (kulupteyse hala uye olan) olusturan. */
    public boolean canManage(Poll p, Actor a) {
        if (a.systemAdmin(PermissionMatrix.CONTENT_WRITE)) {
            return true;
        }
        if (p.getScope() == Poll.Scope.COMMUNITY) {
            return isClubManager(p.getCommunityId(), a)
                    || (a.id().equals(p.getCreatedBy()) && isActiveMember(p.getCommunityId(), a.id()));
        }
        return a.id().equals(p.getCreatedBy());
    }

    /**
     * Gorebilir mi: taslak yalniz yonetene, kulup anketi yalniz (yayindaki kulubun) uyelerine/yonetene, hedef kitleli
     * anket yalniz kitleye uyana ya da yonetene (T-046: yalniz listede degil ID ile de ayni kural). {@code me} null ise
     * kitle kisiti olan anket yalniz yonetene/okuma izinli sistem yoneticisine gorunur.
     */
    public boolean canView(Poll p, Actor a, Set<Long> memberCids, User me) {
        if (canManage(p, a)) {
            return true;
        }
        if (p.getStatus() == Poll.Status.DRAFT) {
            return false;
        }
        boolean sysRead = a.systemAdmin(PermissionMatrix.CONTENT_READ);
        if (p.getScope() == Poll.Scope.COMMUNITY && !sysRead && !memberCids.contains(p.getCommunityId())) {
            return false;
        }
        return sysRead || audienceMatches(p, me);
    }

    /** Oy vermeye uygun mu (uyelik + hedef kitle). */
    public boolean eligible(Poll p, User u, Set<Long> memberCids) {
        if (u == null || !u.isActive()) {
            return false;
        }
        if (p.getScope() == Poll.Scope.COMMUNITY && !memberCids.contains(p.getCommunityId())) {
            return false;
        }
        return audienceMatches(p, u);
    }

    /** Oy hakkina sahip kisi sayisi; hesaplanamiyorsa null. 60 sn onbellekli. */
    public Integer eligibleCount(Poll p) {
        if (p.getScope() == Poll.Scope.COMMUNITY) {
            if (p.hasAudience()) {
                return null;
            }
            return (int) members.countByCommunityIdAndStatus(p.getCommunityId(), CommunityMember.Status.ACTIVE);
        }
        String key = String.valueOf(p.getAudienceFaculty()) + '|' + p.getAudienceDepartment() + '|' + p.getAudienceGrade();
        long now = Instant.now().toEpochMilli();
        long[] c = countCache.get(key);
        if (c != null && now - c[1] < COUNT_TTL_MS) {
            return (int) c[0];
        }
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM app_user WHERE status = 'ACTIVE'");
        List<Object> args = new ArrayList<>();
        audienceClauses(p, sql, args);
        Integer n = jdbc.queryForObject(sql.toString(), Integer.class, args.toArray());
        int v = n == null ? 0 : n;
        if (countCache.size() > 200) {
            countCache.clear();
        }
        countCache.put(key, new long[] {v, now});
        return v;
    }

    /** Hedef kitleye uyan aktif kullanici kimlikleri (bildirim alicilari; GLOBAL/MENU). */
    public List<Long> audienceUserIds(Poll p) {
        StringBuilder sql = new StringBuilder("SELECT id FROM app_user WHERE status = 'ACTIVE'");
        List<Object> args = new ArrayList<>();
        audienceClauses(p, sql, args);
        return jdbc.queryForList(sql.toString(), Long.class, args.toArray());
    }

    /** Hedef kitle kosullari: Java {@link AudienceKey#of} ile ayni normalize (SQL: translate/lower), tek yer. */
    private static void audienceClauses(Poll p, StringBuilder sql, List<Object> args) {
        String fac = AudienceKey.of(p.getAudienceFaculty());
        if (fac != null) {
            sql.append(" AND ").append(AudienceKey.sql("faculty")).append(" = ?");
            args.add(fac);
        }
        String dep = AudienceKey.of(p.getAudienceDepartment());
        if (dep != null) {
            sql.append(" AND ").append(AudienceKey.sql("department")).append(" = ?");
            args.add(dep);
        }
        if (p.getAudienceGrade() != null && !p.getAudienceGrade().isBlank()) {
            sql.append(" AND upper(trim(grade)) = ?");
            args.add(p.getAudienceGrade().strip().toUpperCase(Locale.ROOT));
        }
    }

    /** Aktif uyelerin kimlikleri (bildirim alicilari; COMMUNITY). */
    public List<Long> communityUserIds(Long communityId) {
        return members.userIdsByStatus(communityId, CommunityMember.Status.ACTIVE, PageRequest.of(0, 100_000));
    }

    /** Ankette oy kullanmis kullanicilar (yalniz "kapanisa 24 saat" bildiriminde oy vermemisleri ayiklamak icin; disari verilmez). */
    public Set<Long> voterIds(Long pollId) {
        return new HashSet<>(jdbc.queryForList("SELECT user_id FROM poll_ballot WHERE poll_id = ?", Long.class, pollId));
    }
}
