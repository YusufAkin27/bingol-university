package edu.bingol.backend.forum.topic;

import edu.bingol.backend.common.CurrentUser;

/**
 * Forum yonetici izinleri (anahtar dizgeleri). Izin matrisine baglama D'nin isidir ({@code PermissionMatrix}:
 * MODERATOR -> read+moderate, EDITOR -> read+categories, FULL hepsi, VIEWER -> read); A matrise DOKUNMAZ ve yalniz
 * {@link CurrentUser#hasAdminPermission} ile bu anahtari denetler. Matriste anahtar yoksa hicbir profil moderator olmaz
 * (kapali basarisiz).
 */
public final class ForumPermissions {

    public static final String READ = "forum.read";
    public static final String MODERATE = "forum.moderate";
    public static final String CATEGORIES = "forum.categories";

    private ForumPermissions() {}

    /** Gecerli istek sahibi forum moderatoru mu (ROLE_ADMIN + forum.moderate). */
    public static boolean canModerate() {
        return CurrentUser.hasAdminPermission(MODERATE);
    }
}
