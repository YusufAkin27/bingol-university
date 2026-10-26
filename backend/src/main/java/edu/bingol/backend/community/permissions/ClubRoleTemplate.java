package edu.bingol.backend.community.permissions;

import static edu.bingol.backend.community.permissions.ClubPermission.EDIT_INFO;
import static edu.bingol.backend.community.permissions.ClubPermission.INVITE;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_EVENTS;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_MEMBERS;
import static edu.bingol.backend.community.permissions.ClubPermission.MANAGE_POSTS;

import edu.bingol.backend.community.CommunityMember.Role;
import java.util.EnumSet;
import java.util.Optional;
import java.util.Set;

/**
 * Hazir rol sablonlari. MODERATOR sablonu, ayrintili yetkilerden onceki moderator davranisinin birebir karsiligidir
 * (mevcut veri bu yuzden degismeden calisir). MANAGE_ROLES hicbir sablonda yoktur: yalnizca sahip acikca verir.
 */
public enum ClubRoleTemplate {
    MEMBER(Role.MEMBER, EnumSet.noneOf(ClubPermission.class)),
    MODERATOR(Role.MODERATOR, EnumSet.of(MANAGE_MEMBERS, MANAGE_POSTS, MANAGE_EVENTS, EDIT_INFO, INVITE)),
    ADMIN(Role.ADMIN, EnumSet.of(MANAGE_MEMBERS, MANAGE_POSTS, MANAGE_EVENTS, EDIT_INFO, INVITE)),
    /** "Gonderi yoneticisi". */
    POST_MANAGER(Role.MEMBER, EnumSet.of(MANAGE_POSTS)),
    /** "Etkinlik sorumlusu". */
    EVENT_MANAGER(Role.MEMBER, EnumSet.of(MANAGE_EVENTS)),
    /** "Uye yoneticisi". */
    MEMBER_MANAGER(Role.MEMBER, EnumSet.of(MANAGE_MEMBERS, INVITE));

    private final Role role;
    private final Set<ClubPermission> permissions;

    ClubRoleTemplate(Role role, Set<ClubPermission> permissions) {
        this.role = role;
        this.permissions = permissions;
    }

    public Role role() {
        return role;
    }

    public Set<ClubPermission> permissions() {
        return EnumSet.copyOf(permissions);
    }

    /** Rolun grant kaydi olmayan uyedeki varsayilan yetkileri. */
    public static Set<ClubPermission> defaultsFor(Role role) {
        return switch (role) {
            case OWNER -> ClubPermission.all();
            case ADMIN -> ADMIN.permissions();
            case MODERATOR -> MODERATOR.permissions();
            case MEMBER -> EnumSet.noneOf(ClubPermission.class);
        };
    }

    public static Optional<ClubRoleTemplate> parse(String s) {
        try {
            return s == null ? Optional.empty() : Optional.of(valueOf(s.trim().toUpperCase()));
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
