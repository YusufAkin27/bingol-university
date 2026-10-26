package edu.bingol.backend.profile.privacy;

import java.util.Collection;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import org.springframework.stereotype.Service;

/**
 * Profil alanlarinin (avatar dahil) bakan x sahip iliskisine gore gorunurlugunun TEK karar noktasi.
 * Diger moduller (sohbet, topluluk, etkinlik) avatar dondurmeden once {@link #filterAvatars} /
 * {@link #avatarFor} cagirir; ayrinti: docs/PROFILE_PRIVACY.md.
 */
@Service
public class AvatarVisibility {

    /** Gizlilik ayari olan alanlar. */
    public enum Field {
        AVATAR(ProfilePrivacy::getAvatarAudience),
        BIO(ProfilePrivacy::getBioAudience),
        DEPARTMENT(ProfilePrivacy::getDepartmentAudience),
        FACULTY(ProfilePrivacy::getFacultyAudience),
        CLASS_YEAR(ProfilePrivacy::getClassYearAudience);

        private final Function<ProfilePrivacy, Audience> getter;

        Field(Function<ProfilePrivacy, Audience> getter) {
            this.getter = getter;
        }

        Audience of(ProfilePrivacy p) {
            return getter.apply(p);
        }
    }

    private final ProfilePrivacyRepository privacy;
    private final SharedContextRepository shared;

    public AvatarVisibility(ProfilePrivacyRepository privacy, SharedContextRepository shared) {
        this.privacy = privacy;
        this.shared = shared;
    }

    /** Saf karar kurali (test matrisi bunu dogrudan dener). */
    public static boolean allowed(Audience audience, boolean isOwner, boolean sharedContext) {
        if (isOwner) {
            return true;
        }
        return switch (audience) {
            case EVERYONE -> true;
            case SHARED_CONTEXT -> sharedContext;
            case ONLY_ME -> false;
        };
    }

    /**
     * Her alan icin: owners icinden bakanin gorebildikleri. Tek ayar sorgusu + (gerekirse) tek ortak-baglam
     * sorgusu. Ayar satiri olmayan sahip = EVERYONE.
     */
    public Map<Field, Set<Long>> visibleOwners(Long viewerId, Collection<Long> owners, Collection<Field> fields) {
        Map<Field, Set<Long>> out = new EnumMap<>(Field.class);
        fields.forEach(f -> out.put(f, new HashSet<>()));
        Set<Long> distinct = new HashSet<>(owners);
        if (distinct.isEmpty()) {
            return out;
        }
        Map<Long, ProfilePrivacy> byOwner = new HashMap<>();
        privacy.findByUserIdIn(distinct).forEach(p -> byOwner.put(p.getUserId(), p));

        // Ortak baglam sorgusu yalnizca bir alani SHARED_CONTEXT olan (ve kendisi olmayan) sahipler icin calisir
        Set<Long> needShared = new HashSet<>();
        for (Long o : distinct) {
            ProfilePrivacy p = byOwner.get(o);
            if (p != null && !o.equals(viewerId) && fields.stream().anyMatch(f -> f.of(p) == Audience.SHARED_CONTEXT)) {
                needShared.add(o);
            }
        }
        Set<Long> sharedOk = needShared.isEmpty() ? Set.of() : shared.sharedWith(viewerId, needShared);

        for (Long o : distinct) {
            boolean owner = o.equals(viewerId);
            ProfilePrivacy p = byOwner.get(o);
            for (Field f : fields) {
                boolean ok;
                if (p == null) {
                    ok = true;
                } else if (f == Field.AVATAR && p.isAvatarHidden() && !owner) {
                    ok = false;
                } else {
                    ok = allowed(f.of(p), owner, sharedOk.contains(o));
                }
                if (ok) {
                    out.get(f).add(o);
                }
            }
        }
        return out;
    }

    public Set<Long> visibleOwners(Long viewerId, Collection<Long> owners, Field field) {
        return visibleOwners(viewerId, owners, Set.of(field)).get(field);
    }

    public boolean canSee(Long viewerId, Long ownerId, Field field) {
        return visibleOwners(viewerId, Set.of(ownerId), field).contains(ownerId);
    }

    /** Tek avatar: gorunmuyorsa null. */
    public String avatarFor(Long viewerId, Long ownerId, String avatarUrl) {
        return avatarUrl == null || !canSee(viewerId, ownerId, Field.AVATAR) ? null : avatarUrl;
    }

    /** Toplu: sahip id -> avatarUrl; gorunmeyenlerin degeri null olur (anahtar korunur). */
    public Map<Long, String> filterAvatars(Long viewerId, Map<Long, String> ownerToUrl) {
        Set<Long> ok = visibleOwners(viewerId, ownerToUrl.keySet(), Field.AVATAR);
        Map<Long, String> out = new HashMap<>();
        ownerToUrl.forEach((o, url) -> out.put(o, ok.contains(o) ? url : null));
        return out;
    }
}
