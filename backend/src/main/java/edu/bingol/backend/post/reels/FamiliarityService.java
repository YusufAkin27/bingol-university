package edu.bingol.backend.post.reels;

import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Keşfet sıralaması için "bu yazarı ne kadar tanıyorum" bonusu: karşılıklı takip, birebir sohbet, ortak kulüp,
 * tanıdığımın tanıdığı, aynı bölüm/fakülte. Saf hesap {@link #bonus}; hata olursa bonus 0 (sıralama bozulmaz).
 */
@Service
public class FamiliarityService {

    private static final Logger log = LoggerFactory.getLogger(FamiliarityService.class);

    private final FamiliarityRepository repo;
    private final FamiliarityProperties props;

    public FamiliarityService(FamiliarityRepository repo, FamiliarityProperties props) {
        this.repo = repo;
        this.props = props;
    }

    /** Tek yazarın sinyalleri. */
    public record Signals(boolean followsMe, boolean directMessage, int sharedClubs, int friendsOfFriends,
                          boolean sameDepartment, boolean sameFaculty) {
        static final Signals NONE = new Signals(false, false, 0, 0, false, false);
    }

    /** Saf bonus: ağırlıklı toplam, {@code maxBonus} ile sınırlı. */
    public static double bonus(FamiliarityProperties p, Signals s) {
        double b = 0;
        if (s.followsMe()) {
            b += p.mutualWeight();
        }
        if (s.directMessage()) {
            b += p.directMessageWeight();
        }
        b += p.sharedClubWeight() * Math.min(Math.max(s.sharedClubs(), 0), 3) / 3.0;
        b += p.friendOfFriendWeight() * Math.min(Math.max(s.friendsOfFriends(), 0), 5) / 5.0;
        if (s.sameDepartment()) {
            b += p.sameDepartmentWeight();
        } else if (s.sameFaculty()) {
            b += p.sameFacultyWeight();
        }
        return Math.min(Math.max(b, 0), Math.max(p.maxBonus(), 0));
    }

    /** Aday yazarlar için (yazar -> bonus). Kapalıysa ya da hata olursa boş harita. */
    public Map<Long, Double> bonuses(Long viewer, Collection<Long> authors) {
        Map<Long, Double> out = new HashMap<>();
        if (!props.enabled() || viewer == null || authors.isEmpty()) {
            return out;
        }
        try {
            List<Long> ids = authors.stream().filter(a -> !a.equals(viewer)).distinct().toList();
            if (ids.isEmpty()) {
                return out;
            }
            Set<Long> followsMe = new HashSet<>(repo.followingMe(viewer, ids));
            Set<Long> dm = new HashSet<>(repo.directContacts(viewer, ids));
            Map<Long, Integer> clubs = toMap(repo.sharedClubCounts(viewer, ids));
            Map<Long, Integer> fof = toMap(repo.friendOfFriendCounts(viewer, ids));
            Set<Long> dept = new HashSet<>(repo.sameDepartment(viewer, ids));
            Set<Long> fac = new HashSet<>(repo.sameFaculty(viewer, ids));
            for (Long a : ids) {
                Signals s = new Signals(followsMe.contains(a), dm.contains(a), clubs.getOrDefault(a, 0),
                        fof.getOrDefault(a, 0), dept.contains(a), fac.contains(a));
                if (!s.equals(Signals.NONE)) {
                    out.put(a, bonus(props, s));
                }
            }
        } catch (RuntimeException e) {
            log.warn("Kesfet tanisiklik sinyalleri okunamadi (bonus yok sayildi): {}", e.toString());
            out.clear();
        }
        return out;
    }

    private static Map<Long, Integer> toMap(List<Object[]> rows) {
        Map<Long, Integer> m = new HashMap<>();
        for (Object[] r : rows) {
            m.put(((Number) r[0]).longValue(), ((Number) r[1]).intValue());
        }
        return m;
    }
}
