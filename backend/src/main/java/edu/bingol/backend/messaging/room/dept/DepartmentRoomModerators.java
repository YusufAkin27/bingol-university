package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.messaging.room.RoomModerationAuthorizer;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserRepository;
import org.springframework.stereotype.Component;

/** Bolum odasi: grup yoneticisi sistem yoneticisidir (ADMIN; FULL ya da MODERATOR profili, bos profil = FULL). */
@Component
class DepartmentRoomModerators implements RoomModerationAuthorizer {

    private final UserRepository users;

    DepartmentRoomModerators(UserRepository users) {
        this.users = users;
    }

    @Override
    public RoomKind kind() {
        return RoomKind.DEPARTMENT;
    }

    @Override
    public boolean canModerate(Long refId, Long userId) {
        return users.findById(userId)
                .filter(u -> u.isActive() && u.getRole() == Role.ADMIN)
                .map(u -> u.getAdminProfile() == null || u.getAdminProfile() == AdminProfile.FULL
                        || u.getAdminProfile() == AdminProfile.MODERATOR)
                .orElse(false);
    }
}
