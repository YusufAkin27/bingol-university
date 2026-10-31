package edu.bingol.backend.admin.rbac;

import static edu.bingol.backend.admin.rbac.PermissionMatrix.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * /api/admin/** yol + yontem -> gereken izin eslemesi (saf fonksiyon, birim testlidir). Kurallar SIRAYLA denenir, ilk
 * eslesen kazanir: ozel kurallar once, alan (onek) kurallari sonra. Eslenmemis yol {@link PermissionMatrix#FULL_ONLY}
 * ister (guvenli varsayilan). Yeni yonetici ucu eklenince `RbacCoverageTest` eslenmemis ucu BASARISIZ eder:
 * buraya bilincli bir kural eklenmelidir.
 */
public final class AdminPermissionPolicy {

    private static final Set<String> READ = Set.of("GET", "HEAD");

    private record Rule(Pattern path, Set<String> methods, String read, String write) {
        boolean matches(String method, String p) {
            return (methods == null || methods.contains(method)) && path.matcher(p).matches();
        }

        String permFor(String method) {
            return READ.contains(method) ? read : write;
        }
    }

    private static final List<Rule> RULES = new ArrayList<>();

    /** Tek izinli ozel kural (yontem kumesi null = hepsi). */
    private static void one(Set<String> methods, String regex, String perm) {
        RULES.add(new Rule(Pattern.compile("^" + regex + "$"), methods, perm, perm));
    }

    /** Alan kurali: okuma (GET) ve yazma (digerleri) icin ayri izin. */
    private static void area(String regex, String read, String write) {
        RULES.add(new Rule(Pattern.compile("^" + regex + "$"), null, read, write));
    }

    private static final String ID = "[^/]+";

    static {
        // --- kendi bilgisi / rbac ---
        one(Set.of("GET"), "/api/admin/me", DASHBOARD_READ);
        one(Set.of("GET"), "/api/admin/stats", DASHBOARD_READ);
        one(Set.of("GET"), "/api/admin/rbac/(me|matrix)", DASHBOARD_READ);
        one(null, "/api/admin/rbac(/.*)?", RBAC_MANAGE);

        // --- analitik ---
        one(null, "/api/admin/analytics(/.*)?", ANALYTICS_READ);
        one(Set.of("GET"), "/api/admin/notifications/stats", ANALYTICS_READ);

        // --- denetim ---
        one(null, "/api/admin/audit(/.*)?", AUDIT_READ);

        // --- kullanicilar ---
        one(Set.of("GET"), "/api/admin/users/export[.]csv", USERS_EXPORT);
        one(Set.of("POST"), "/api/admin/users/" + ID + "/export", USERS_EXPORT);
        // T-011: e-posta sahipligini kanitlamadan hesap acma/dogrulama yalniz FULL (users.write sahibi MODERATOR yapamaz)
        one(Set.of("POST"), "/api/admin/users/" + ID + "/verify-email", USERS_VERIFY);
        one(Set.of("POST"), "/api/admin/pending-registrations/" + ID + "/verify", USERS_VERIFY);
        one(Set.of("PATCH"), "/api/admin/users/" + ID + "/role", USERS_ROLE);
        one(Set.of("DELETE"), "/api/admin/users/" + ID, USERS_DELETE);
        one(Set.of("GET"), "/api/admin/users/" + ID + "/(sessions|push-devices|devices)", USERS_PII);
        one(Set.of("POST"), "/api/admin/users/" + ID + "/block-access", MODERATION_WRITE);
        one(Set.of("GET"), "/api/admin/users/" + ID + "/strikes", MODERATION_READ);
        one(Set.of("GET"), "/api/admin/users/" + ID + "/conversations(/.*)?", CHAT_READ);
        one(Set.of("GET"), "/api/admin/pending-registrations/export[.]csv", USERS_EXPORT);
        one(Set.of("GET"), "/api/admin/pending-registrations", USERS_PII);
        area("/api/admin/users(/.*)?", USERS_READ, USERS_WRITE);
        area("/api/admin/pending-registrations(/.*)?", USERS_PII, USERS_WRITE);

        // --- moderasyon ---
        // Sikayet ayrintisi mesaj baglamini (sohbet icerigi) dondurur: chat.read ister (VIEWER liste okur, icerik okuyamaz)
        one(Set.of("GET"), "/api/admin/reports/(?!export[.]csv$|reason-templates$)[^/]+", CHAT_READ);
        one(Set.of("POST"), "/api/admin/profanity/check", MODERATION_READ);
        area("/api/admin/(reports|appeals|moderation|profanity|access-bans)(/.*)?", MODERATION_READ, MODERATION_WRITE);

        // --- sohbet ---
        one(Set.of("GET"), "/api/admin/(chat-media|chat-messages)(/.*)?", CHAT_READ);
        one(Set.of("GET"), "/api/admin/media/attachments/.*", CHAT_READ);
        area("/api/admin/(messages|conversations)(/.*)?", CHAT_READ, CHAT_WRITE);

        // --- zorla senkron (icerik kaynaklari) ---
        one(Set.of("POST"), "/api/admin/(sync|sync-menu|sources/sync)", SYSTEM_WRITE);

        // --- icerik: gizle/kaldir alt kumesi ---
        one(Set.of("POST"), "/api/admin/(events|community-posts|posts)/" + ID + "/(hide|unhide)", CONTENT_HIDE);
        one(Set.of("PATCH"), "/api/admin/news/" + ID, CONTENT_HIDE);
        one(Set.of("PATCH", "DELETE"), "/api/admin/(posts|community-posts)/" + ID, CONTENT_HIDE);

        // --- duyuru (akademik duyuru): yalniz duyuru yetkisi ---
        area("/api/admin/announcements(/.*)?", COMMS_READ, COMMS_ANNOUNCE);

        // --- icerik: yemek kalorisi (EDITOR/FULL yazar, VIEWER okur; area kuralindan once bilincli) ---
        one(Set.of("PUT"), "/api/admin/menu/(calories|" + ID + "/calories)", CONTENT_WRITE);

        // --- icerik ---
        area("/api/admin/(news|menu|academic|faq|communities|communitiespage|community-categories|community-posts"
                + "|events|polls|posts|sources)(/.*)?", CONTENT_READ, CONTENT_WRITE);

        // --- destek ---
        area("/api/admin/(support|feedback)(/.*)?", SUPPORT_READ, SUPPORT_WRITE);

        // --- iletisim (push/mail) ---
        one(Set.of("POST"), "/api/admin/push/users/" + ID + "/send", COMMS_SINGLE);
        one(Set.of("POST"), "/api/admin/(push/audience-count|push/audience/preview|mail/campaigns/audience/preview)",
                COMMS_READ);
        one(Set.of("GET"), "/api/admin/push/campaigns/" + ID + "/failures", COMMS_READ);
        area("/api/admin/push/campaigns(/.*)?", COMMS_READ, COMMS_SEND);
        area("/api/admin/mail/campaigns(/.*)?", COMMS_READ, COMMS_SEND);
        area("/api/admin/mail/(templates|variables)(/.*)?", COMMS_READ, COMMS_WRITE);

        // --- veri saklama (DS1): okuma VIEWER dahil; disa aktarma ve silme yalniz FULL ---
        one(Set.of("GET"), "/api/admin/system/storage", RETENTION_READ);
        one(Set.of("POST"), "/api/admin/data-retention/exports", RETENTION_EXPORT);
        one(Set.of("POST"), "/api/admin/data-retention/purges", RETENTION_PURGE);
        area("/api/admin/data-retention(/.*)?", RETENTION_READ, RETENTION_PURGE);

        // --- sistem / altyapi ---
        area("/api/admin/push/(fcm|outbox|devices)(/.*)?", SYSTEM_READ, SYSTEM_WRITE);
        area("/api/admin/mail/(outbox|suppressions|quota)(/.*)?", SYSTEM_READ, SYSTEM_WRITE);
        area("/api/admin/(ops|system|crypto|crashes)(/.*)?", SYSTEM_READ, SYSTEM_WRITE);

        // --- sozlesme / ayar ---
        one(Set.of("POST"), "/api/admin/legal/" + ID, LEGAL_PUBLISH);
        area("/api/admin/legal(/.*)?", LEGAL_READ, LEGAL_PUBLISH);
        area("/api/admin/settings(/.*)?", SETTINGS_READ, SETTINGS_WRITE);
    }

    private AdminPermissionPolicy() {}

    /** Acikca eslenmis izin; bos = eslenmemis (kapsam testi bunu hata sayar). */
    public static Optional<String> explicit(String method, String path) {
        if (method == null || path == null) {
            return Optional.empty();
        }
        String m = method.toUpperCase(java.util.Locale.ROOT);
        // HEAD, GET isleyicisine gider (Spring): izin de GET kurallariyla degerlendirilir (T-010/A1-37)
        if (m.equals("HEAD")) {
            m = "GET";
        }
        String p = normalize(path);
        for (Rule r : RULES) {
            if (r.matches(m, p)) {
                return Optional.of(r.permFor(m));
            }
        }
        return Optional.empty();
    }

    /** Gereken izin; eslenmemis yol icin FULL_ONLY (guvenli varsayilan). */
    public static String required(String method, String path) {
        return explicit(method, path).orElse(FULL_ONLY);
    }

    private static String normalize(String path) {
        String p = path;
        int q = p.indexOf('?');
        if (q >= 0) {
            p = p.substring(0, q);
        }
        while (p.length() > 1 && p.endsWith("/")) {
            p = p.substring(0, p.length() - 1);
        }
        return p;
    }
}
