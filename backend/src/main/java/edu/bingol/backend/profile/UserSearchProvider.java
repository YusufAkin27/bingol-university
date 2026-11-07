package edu.bingol.backend.profile;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.search.SearchHit;
import edu.bingol.backend.search.SearchProvider;
import edu.bingol.backend.search.SearchType;
import java.time.Duration;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * Genel arama: kisi (kullanici) turu. Gizlilik/engel/askiya alma suzgeci {@link ProfileService#search} ile BIREBIR
 * aynidir (engel iliskisi, askidaki ve silinmis hesaplar, kendisi donmez). Sonuca e-posta, takipci sayisi vb. KONMAZ:
 * yalniz ad, bolum ve avatar. Dizin taramasina karsi ayri gunluk kota (asilinca tur sessizce bos doner).
 */
@Component
public class UserSearchProvider implements SearchProvider {

    static final int DAILY_QUOTA = 1500;

    private final ProfileService profiles;
    private final RateLimiter limiter;

    public UserSearchProvider(ProfileService profiles, RateLimiter limiter) {
        this.profiles = profiles;
        this.limiter = limiter;
    }

    @Override
    public SearchType type() {
        return SearchType.USER;
    }

    @Override
    public List<SearchHit> search(String q, int limit) {
        return search(q, limit, 0);
    }

    @Override
    public List<SearchHit> search(String q, int limit, int offset) {
        Long viewer = CurrentUser.idOrNull();
        if (viewer == null) {
            return List.of();
        }
        limiter.check("gsearch-user-day:user:" + viewer, DAILY_QUOTA, Duration.ofDays(1));
        // ProfileService en fazla 20 satir / 200 offset verir; fazlasi kendi icinde kirpilir
        return profiles.search(viewer, q, limit, (long) offset).items().stream().map(UserSearchProvider::hit).toList();
    }

    static SearchHit hit(PublicProfile p) {
        String dept = p.department() != null && !p.department().isBlank() ? p.department() : p.faculty();
        return new SearchHit(SearchType.USER, p.id(), p.displayName(), dept, p.avatarUrl(), null);
    }
}
