package edu.bingol.backend.profile.privacy;

import edu.bingol.backend.profile.privacy.PrivacyDtos.UpdatePrivacyRequest;
import java.time.Instant;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PrivacyService {

    private final ProfilePrivacyRepository repo;

    public PrivacyService(ProfilePrivacyRepository repo) {
        this.repo = repo;
    }

    public ProfilePrivacy get(Long userId) {
        return repo.findById(userId).orElseGet(() -> ProfilePrivacy.defaults(userId));
    }

    @Transactional
    public ProfilePrivacy update(Long userId, UpdatePrivacyRequest r) {
        ProfilePrivacy p = get(userId);
        if (r.avatar() != null) {
            p.setAvatarAudience(r.avatar());
        }
        if (r.bio() != null) {
            p.setBioAudience(r.bio());
        }
        if (r.department() != null) {
            p.setDepartmentAudience(r.department());
        }
        if (r.faculty() != null) {
            p.setFacultyAudience(r.faculty());
        }
        if (r.classYear() != null) {
            p.setClassYearAudience(r.classYear());
        }
        p.setUpdatedAt(Instant.now());
        return repo.save(p);
    }

    /** Moderasyon bayragi (USER_AVATAR "gizle"); kullanici ayarlarina dokunmaz. */
    @Transactional
    public void setAvatarHidden(Long userId, boolean hidden) {
        ProfilePrivacy p = get(userId);
        p.setAvatarHidden(hidden);
        p.setUpdatedAt(Instant.now());
        repo.save(p);
    }

    /** Hesap silme: ayar satiri da silinir (KVKK). */
    @Transactional
    public void purge(Long userId) {
        repo.deleteById(userId);
    }
}
