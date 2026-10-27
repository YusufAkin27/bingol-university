package edu.bingol.backend.poll;

import edu.bingol.backend.community.Actor;
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
    private final Map<String, long[]> countCache = new ConcurrentHashMap<>();

    public PollAccess(CommunityMemberRepository members, ClubPermissions clubPermissions, JdbcTemplate jdbc) {
        this.members = members;
        this.clubPermissions = clubPermissions;
        this.jdbc = jdbc;
    }

    /** Kullanicinin aktif uyesi oldugu kulup kimlikleri. */
    public Set<Long> memberCommunityIds(Long userId) {
        Set<Long> ids = new HashSet<>();
        for (CommunityMember m : members.mine(userId, CommunityMember.Status.ACTIVE, Long.MAX_VALUE, PageRequest.of(0, 1000))) {
            ids.add(m.getCommunityId());
        }
        return ids;
    }

    /** Sorgulara bos koleksiyon verilmesin diye yer tutucu eklenmis liste. */
    public static List<Long> idsOrSentinel(Set<Long> ids) {
        List<Long> l = new ArrayList<>(ids);
        if (l.isEmpty()) {
            l.add(-1L);
        }
        return l;
    }

    private static boolean ci(String want, String have) {
        return want == null || (have != null && want.trim().equalsIgnoreCase(have.trim()));
    }

    /** Hedef kitle (fakulte/bolum/sinif) kullanicinin profiliyle eslesiyor mu; bos alan kisitsiz. */
    public boolean audienceMatches(Poll p, User u) {
        if (!p.hasAudience()) {
            return true;
        }
        return u != null && ci(p.getAudienceFaculty(), u.getFaculty()) && ci(p.getAudienceDepartment(), u.getDepartment())
                && ci(p.getAudienceGrade(), u.getGrade());
    }

    public boolean isActiveMember(Long communityId, Long userId) {
        return communityId != null && members.findByCommunityIdAndUserId(communityId, userId)
                .filter(CommunityMember::isActive).isPresent();
    }

    /** Kulup yoneticisi (rol ADMIN/OWNER) ya da sistem yoneticisi. */
    public boolean isClubManager(Long communityId, Actor a) {
        if (a.admin()) {
            return true;
        }
        return communityId != null && clubPermissions.standingOfUser(communityId, a.id())
                .map(s -> s.role() == CommunityMember.Role.ADMIN || s.role() == CommunityMember.Role.OWNER).orElse(false);
    }

    /** Duzenleme/kapatma/silme: sistem yoneticisi, kulup yoneticisi ya da (kulupteyse hala uye olan) olusturan. */
    public boolean canManage(Poll p, Actor a) {
        if (a.admin()) {
            return true;
        }
        if (p.getScope() == Poll.Scope.COMMUNITY) {
            return isClubManager(p.getCommunityId(), a)
                    || (a.id().equals(p.getCreatedBy()) && isActiveMember(p.getCommunityId(), a.id()));
        }
        return a.id().equals(p.getCreatedBy());
    }

    /** Gorebilir mi: taslak yalniz yonetene, kulup anketi yalniz uyelere/yonetene. */
    public boolean canView(Poll p, Actor a, Set<Long> memberCids) {
        if (p.getStatus() == Poll.Status.DRAFT) {
            return canManage(p, a);
        }
        if (p.getScope() == Poll.Scope.COMMUNITY) {
            return a.admin() || memberCids.contains(p.getCommunityId()) || canManage(p, a);
        }
        return true;
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
        if (p.getAudienceFaculty() != null) {
            sql.append(" AND LOWER(faculty) = ?");
            args.add(p.getAudienceFaculty().trim().toLowerCase(Locale.ROOT));
        }
        if (p.getAudienceDepartment() != null) {
            sql.append(" AND LOWER(department) = ?");
            args.add(p.getAudienceDepartment().trim().toLowerCase(Locale.ROOT));
        }
        if (p.getAudienceGrade() != null) {
            sql.append(" AND LOWER(grade) = ?");
            args.add(p.getAudienceGrade().trim().toLowerCase(Locale.ROOT));
        }
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
        if (p.getAudienceFaculty() != null) {
            sql.append(" AND LOWER(faculty) = ?");
            args.add(p.getAudienceFaculty().trim().toLowerCase(Locale.ROOT));
        }
        if (p.getAudienceDepartment() != null) {
            sql.append(" AND LOWER(department) = ?");
            args.add(p.getAudienceDepartment().trim().toLowerCase(Locale.ROOT));
        }
        if (p.getAudienceGrade() != null) {
            sql.append(" AND LOWER(grade) = ?");
            args.add(p.getAudienceGrade().trim().toLowerCase(Locale.ROOT));
        }
        return jdbc.queryForList(sql.toString(), Long.class, args.toArray());
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
