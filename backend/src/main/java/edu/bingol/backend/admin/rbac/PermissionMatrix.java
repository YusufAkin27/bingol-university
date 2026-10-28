package edu.bingol.backend.admin.rbac;

import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Yonetici izin matrisi: profil -> izin kumesi, TEK yerde kod tablosu (DB'de ozellestirme yoktur). Izin anahtarlari
 * `alan.islem` bicimindedir ve web (`adminNav.ts`, `useCan`) ile AYNIDIR. Yeni izin eklenince yalniz burasi ve
 * {@link AdminPermissionPolicy} guncellenir; kapsam testi (RbacCoverageTest) eslenmemis ucu basarisiz eder.
 */
public final class PermissionMatrix {

    // --- izin anahtarlari ---
    public static final String DASHBOARD_READ = "dashboard.read";
    public static final String ANALYTICS_READ = "analytics.read";
    public static final String USERS_READ = "users.read";
    /** Maskesiz kisisel alanlar: tam e-posta, IP, cihaz/oturum ayrintisi. */
    public static final String USERS_PII = "users.pii";
    public static final String USERS_WRITE = "users.write";
    public static final String USERS_ROLE = "users.role";
    public static final String USERS_DELETE = "users.delete";
    public static final String USERS_EXPORT = "users.export";
    public static final String MODERATION_READ = "moderation.read";
    public static final String MODERATION_WRITE = "moderation.write";
    public static final String CHAT_READ = "chat.read";
    public static final String CHAT_WRITE = "chat.write";
    public static final String CONTENT_READ = "content.read";
    public static final String CONTENT_WRITE = "content.write";
    /** Gizle/geri goster ve gonderi/haber kaldirma alt kumesi. */
    public static final String CONTENT_HIDE = "content.hide";
    public static final String SUPPORT_READ = "support.read";
    public static final String SUPPORT_WRITE = "support.write";
    public static final String COMMS_READ = "comms.read";
    public static final String COMMS_WRITE = "comms.write";
    public static final String COMMS_SEND = "comms.send";
    public static final String COMMS_SINGLE = "comms.single";
    public static final String COMMS_ANNOUNCE = "comms.announce";
    public static final String LEGAL_READ = "legal.read";
    public static final String LEGAL_PUBLISH = "legal.publish";
    public static final String SETTINGS_READ = "settings.read";
    public static final String SETTINGS_WRITE = "settings.write";
    public static final String SYSTEM_READ = "system.read";
    public static final String SYSTEM_WRITE = "system.write";
    public static final String AUDIT_READ = "audit.read";
    public static final String RBAC_MANAGE = "rbac.manage";
    /** Haritada eslenmemis /api/admin yollari icin guvenli varsayilan: yalniz FULL. */
    public static final String FULL_ONLY = "admin.full";

    private static final AdminProfile F = AdminProfile.FULL;
    private static final AdminProfile M = AdminProfile.MODERATOR;
    private static final AdminProfile S = AdminProfile.SUPPORT;
    private static final AdminProfile E = AdminProfile.EDITOR;
    private static final AdminProfile V = AdminProfile.VIEWER;

    private static final Map<String, List<AdminProfile>> GRANTS = new LinkedHashMap<>();

    private static void grant(String perm, AdminProfile... profiles) {
        GRANTS.put(perm, List.of(profiles));
    }

    static {
        grant(DASHBOARD_READ, F, M, S, E, V);
        grant(ANALYTICS_READ, F, M, S, E, V);
        grant(USERS_READ, F, M, S, V);
        grant(USERS_PII, F, M);
        grant(USERS_WRITE, F, M);
        grant(USERS_ROLE, F);
        grant(USERS_DELETE, F);
        grant(USERS_EXPORT, F);
        grant(MODERATION_READ, F, M, V);
        grant(MODERATION_WRITE, F, M);
        grant(CHAT_READ, F, M);
        grant(CHAT_WRITE, F, M);
        grant(CONTENT_READ, F, M, S, E, V);
        grant(CONTENT_WRITE, F, E);
        grant(CONTENT_HIDE, F, E, M);
        grant(SUPPORT_READ, F, S, V);
        grant(SUPPORT_WRITE, F, S);
        grant(COMMS_READ, F, S, E, V);
        grant(COMMS_WRITE, F, E);
        grant(COMMS_SEND, F);
        grant(COMMS_SINGLE, F, S);
        grant(COMMS_ANNOUNCE, F, E);
        grant(LEGAL_READ, F, M, S, E, V);
        grant(LEGAL_PUBLISH, F);
        grant(SETTINGS_READ, F, V);
        grant(SETTINGS_WRITE, F);
        grant(SYSTEM_READ, F, V);
        grant(SYSTEM_WRITE, F);
        grant(AUDIT_READ, F, V);
        grant(RBAC_MANAGE, F);
        grant(FULL_ONLY, F);
    }

    private static final Map<AdminProfile, Set<String>> BY_PROFILE = new EnumMap<>(AdminProfile.class);

    static {
        for (AdminProfile p : AdminProfile.values()) {
            Set<String> set = new LinkedHashSet<>();
            GRANTS.forEach((perm, profiles) -> {
                if (profiles.contains(p)) {
                    set.add(perm);
                }
            });
            BY_PROFILE.put(p, Collections.unmodifiableSet(set));
        }
    }

    private PermissionMatrix() {}

    /** Tum izin anahtarlari (tanim sirasiyla). */
    public static List<String> allPermissions() {
        return List.copyOf(GRANTS.keySet());
    }

    /** Bir profilin izinleri (degistirilemez). */
    public static Set<String> permissionsOf(AdminProfile p) {
        return BY_PROFILE.get(p == null ? AdminProfile.VIEWER : p);
    }

    /** Bir iznin tanimli olup olmadigi. */
    public static boolean isKnown(String perm) {
        return GRANTS.containsKey(perm);
    }

    public static boolean allows(AdminProfile p, String perm) {
        return p != null && perm != null && BY_PROFILE.get(p).contains(perm);
    }

    /** Izin -> verilen profiller (matris gosterimi icin). */
    public static Map<String, List<AdminProfile>> grants() {
        return Collections.unmodifiableMap(GRANTS);
    }

    /** Matris gosterimi icin sirali profil listesi. */
    public static List<AdminProfile> profiles() {
        return new ArrayList<>(List.of(AdminProfile.values()));
    }
}
