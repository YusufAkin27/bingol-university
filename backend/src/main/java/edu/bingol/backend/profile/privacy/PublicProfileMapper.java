package edu.bingol.backend.profile.privacy;

import edu.bingol.backend.profile.dto.ProfileDtos.PublicProfile;
import edu.bingol.backend.profile.privacy.AvatarVisibility.Field;
import edu.bingol.backend.user.User;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/** Baskasinin profilini alan bazli gizlilik ayarlarina gore olusturur (PublicProfile.of yerine). */
@Component
public class PublicProfileMapper {

    private static final Set<Field> ALL = EnumSet.allOf(Field.class);

    private final AvatarVisibility visibility;

    /** Golge engel: engel iliskisi olanlar icin bos profil (setter enjeksiyonu; yoksa uygulanmaz). */
    private edu.bingol.backend.moderation.BlockService blocks;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setBlocks(edu.bingol.backend.moderation.BlockService blocks) {
        this.blocks = blocks;
    }

    public PublicProfileMapper(AvatarVisibility visibility) {
        this.visibility = visibility;
    }

    public PublicProfile map(Long viewerId, User u) {
        return mapAll(viewerId, List.of(u)).get(0);
    }

    public List<PublicProfile> mapAll(Long viewerId, List<User> users) {
        Map<Field, Set<Long>> vis = visibility.visibleOwners(viewerId, users.stream().map(User::getId).toList(), ALL);
        Set<Long> related = blocks == null ? Set.of() : blocks.hiddenFrom(viewerId);
        return users.stream().map(u -> {
            Long id = u.getId();
            if (related.contains(id)) {
                return new PublicProfile(id, u.getDisplayName(), null, null, null, null, null, null);
            }
            return new PublicProfile(id, u.getDisplayName(),
                    vis.get(Field.FACULTY).contains(id) ? u.getFaculty() : null,
                    vis.get(Field.DEPARTMENT).contains(id) ? u.getDepartment() : null,
                    vis.get(Field.CLASS_YEAR).contains(id) ? u.getClassYear() : null,
                    vis.get(Field.BIO).contains(id) ? u.getBio() : null,
                    vis.get(Field.AVATAR).contains(id) ? u.getAvatarUrl() : null,
                    u.isShowEmail() ? u.getEmail() : null);
        }).toList();
    }
}
