package edu.bingol.backend.community.permissions;

import java.util.EnumSet;
import java.util.Optional;
import java.util.Set;

/** Kulupte ince yetki bayraklari. Rol varsayilanlari ve hazir sablonlar {@link ClubRoleTemplate}'te. */
public enum ClubPermission {
    /** Uye cikarma/yasaklama, katilma istegi onayi. */
    MANAGE_MEMBERS,
    /** Gonderi silme ve sabitleme. */
    MANAGE_POSTS,
    /** Kulup adina etkinlik acma ve yonetme. */
    MANAGE_EVENTS,
    /** Kulup bilgisi ve kapak. */
    EDIT_INFO,
    /** Yetki verme/alma; yalnizca sahip (ve sahibin acikca yetkilendirdigi ADMIN) kullanir. */
    MANAGE_ROLES,
    /** Davet kodu uretme/iptal. */
    INVITE;

    public static Set<ClubPermission> all() {
        return EnumSet.allOf(ClubPermission.class);
    }

    public static Optional<ClubPermission> parse(String s) {
        try {
            return s == null ? Optional.empty() : Optional.of(valueOf(s.trim().toUpperCase()));
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
