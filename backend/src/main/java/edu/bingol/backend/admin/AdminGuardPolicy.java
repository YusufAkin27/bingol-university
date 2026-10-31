package edu.bingol.backend.admin;

import java.util.List;
import java.util.regex.Pattern;

/**
 * Yonetici yazma guvenligi kurallari (saf fonksiyonlar, birim testlidir): hangi istek SEBEP ister, hangisi "yikici"
 * (daha siki saatlik hiz siniri) sayilir. Yollar `/api/admin/...` onekli ham istek yoludur.
 */
public final class AdminGuardPolicy {

    /** Kritik islemlerde en kisa sebep uzunlugu. */
    public static final int DEFAULT_MIN_REASON = 5;
    /** Sohbet icerigi acarken en kisa sebep (message_access_audit kisiti ile ayni: 10). */
    public static final int CHAT_MIN_REASON = 10;

    private static final Pattern USER_ROLE = Pattern.compile("^/api/admin/users/[^/]+/role$");
    private static final Pattern USER_DELETE = Pattern.compile("^/api/admin/users/[^/]+$");
    private static final Pattern USER_ACCOUNT_OPS =
            Pattern.compile("^/api/admin/users/[^/]+/(verify-email|send-reset|revoke-sessions)$");
    private static final Pattern LEGAL_PUBLISH = Pattern.compile("^/api/admin/legal/[^/]+$");
    private static final Pattern SETTING = Pattern.compile("^/api/admin/settings/([^/]+)$");
    private static final Pattern BULK = Pattern.compile("^/api/admin/.*/bulk(/.*)?$");
    private static final Pattern PENDING_DELETE = Pattern.compile("^/api/admin/pending-registrations/[^/]+$");
    private static final Pattern BLOCKLIST = Pattern.compile("^/api/admin/moderation/blocklist(/[^/]+)?$");
    private static final Pattern SUSPEND_REC =
            Pattern.compile("^/api/admin/moderation/suspend-recommendations/[^/]+/accept$");
    /** P07 etkinlik derin yonetimi: basvuruyu zorla kabul/ret ve sertifika iptali (POST). */
    private static final Pattern EVENT_DECIDE =
            Pattern.compile("^/api/admin/events/[^/]+/(applications/[^/]+/(accept|reject)|certificates/[^/]+/revoke)$");
    /** P07: geri bildirim, duyuru kaydi, ortak duzenleyen silme (DELETE). */
    private static final Pattern EVENT_DELETE =
            Pattern.compile("^/api/admin/events/[^/]+/(feedback|announcements|organizers)/[^/]+$");

    /** P06 kulup derin yonetimi: kapat/yeniden ac/zorla devir (POST). */
    private static final Pattern CLUB_POST =
            Pattern.compile("^/api/admin/communities/[^/]+/(close|reopen|transfer-ownership)$");
    /** P06: kulup silme, uye cikarma, davet iptali, kulup gonderisi/duyurusu silme (DELETE). */
    private static final Pattern CLUB_DELETE = Pattern.compile(
            "^/api/admin/(communities/[^/]+(/members/[^/]+|/invites/[^/]+)?|community-posts/[^/]+)$");
    /** P06: uye rolu degistirme (PATCH). */
    private static final Pattern CLUB_ROLE = Pattern.compile("^/api/admin/communities/[^/]+/members/[^/]+/role$");

    /** P09 kullanici derin yonetimi: profil mudahalesi (PATCH), oturum/push cihazi sonlandirma (DELETE), KVKK disa aktarma (POST). */
    private static final Pattern USER_PROFILE = Pattern.compile("^/api/admin/users/[^/]+/profile$");
    private static final Pattern USER_EXTRA_DELETE =
            Pattern.compile("^/api/admin/users/[^/]+/(push-devices|sessions)/[^/]+$");
    private static final Pattern USER_EXPORT = Pattern.compile("^/api/admin/users/[^/]+/export$");
    /** Kullanici adina KVKK disa aktarma icin en kisa sebep (kisisel verinin tamami cikar). */
    public static final int EXPORT_MIN_REASON = 20;

    /** P08 sohbet mudahalesi: mesaj gizle/geri goster/toplu gizle, sohbet kapat/ac (POST). */
    private static final Pattern CHAT_POST = Pattern.compile(
            "^/api/admin/(messages/([^/]+/(hide|unhide)|bulk-hide)|conversations/[^/]+/(close|reopen))$");
    /** P08: mesaj kalici silme, uyeyi sohbetten cikarma (DELETE). */
    private static final Pattern CHAT_DELETE =
            Pattern.compile("^/api/admin/(messages/[^/]+|conversations/[^/]+/members/[^/]+)$");

    /** P11 moderasyon: strike affi, gizlenen icerik geri alma (POST); sebep sablonu silme (DELETE). */
    private static final Pattern MOD_POST = Pattern.compile(
            "^/api/admin/moderation/(strikes/[^/]+/forgive|hidden/[^/]+/[^/]+/restore)$");
    private static final Pattern MOD_TEMPLATE_DELETE = Pattern.compile("^/api/admin/moderation/reason-templates/[^/]+$");
    /** P12 destek: talep/geri bildirim silme (DELETE), geri bildirim birlestirme (POST). */
    private static final Pattern SUPPORT_DELETE = Pattern.compile("^/api/admin/support/(tickets|feedback)/[^/]+$");
    private static final Pattern SUPPORT_MERGE = Pattern.compile("^/api/admin/support/feedback/merge$");

    /** P13 mail altyapisi: elle bastirma + toplu/tek kuyruk islemi (POST), bastirma kaldirma (DELETE). */
    private static final Pattern MAIL_OPS_POST = Pattern.compile(
            "^/api/admin/mail/(suppressions|outbox/(bulk|[^/]+/(retry|cancel)))$");
    private static final Pattern MAIL_OPS_DELETE = Pattern.compile("^/api/admin/mail/suppressions/[^/]+$");

    /** P14 push kuyrugu: tek kaydi iptal (POST); toplu islemler BULK desenine girer. */
    private static final Pattern PUSH_OUTBOX_CANCEL = Pattern.compile("^/api/admin/push/outbox/[^/]+/cancel$");

    /** P15: menu toplu silme, bekleyen kayit toplu iptali, kaynak elle senkronu (POST; /news|academic/bulk zaten BULK ile kapsanir). */
    private static final Pattern P15_POST = Pattern.compile(
            "^/api/admin/(menu/bulk-delete|pending-registrations/bulk-cancel|sources/sync)$");

    /** DS1 veri saklama: disa aktarma (kisisel veri cikarir) ve onayli silme (POST); ikisi de gerekce ister. */
    private static final Pattern RETENTION_POST = Pattern.compile("^/api/admin/data-retention/(exports|purges)$");

    /** T-013: icerik moderasyonu (gonderi gizle/geri goster, gonderi kalici silme, haber gizleme/duzenleme). */
    private static final Pattern POST_HIDE = Pattern.compile("^/api/admin/(posts|community-posts)/[^/]+/(hide|unhide)$");
    private static final Pattern POST_DELETE = Pattern.compile("^/api/admin/posts/[^/]+$");
    private static final Pattern NEWS_ITEM = Pattern.compile("^/api/admin/news/[^/]+$");
    /** T-013: kullaniciyi askiya alma / erisimini engelleme (POST). */
    private static final Pattern USER_SUSPEND = Pattern.compile("^/api/admin/users/[^/]+/(suspend|block-access)$");
    /** T-011: bekleyen kaydi e-posta kodu olmadan dogrulama (POST). */
    private static final Pattern PENDING_VERIFY = Pattern.compile("^/api/admin/pending-registrations/[^/]+/verify$");
    /** T-013: erisim engeli olusturma, itiraz karari, kampanya olusturma/zamanlama/iptal, anahtar yeniden sarma (POST). */
    private static final Pattern SENSITIVE_POST = Pattern.compile("^/api/admin/(access-bans|moderation/appeals/[^/]+/decide"
            + "|(push|mail)/campaigns(/[^/]+/(schedule|cancel))?|crypto/rewrap)$");

    /** Kritik ayar anahtarlari (tam ad ya da onek). */
    private static final List<String> CRITICAL_SETTING_PREFIXES = List.of(
            "maintenance_mode", "min_version_", "store_url_", "legal.", "legal_", "support_email");

    private AdminGuardPolicy() {}

    /** P06: kulup/kulup icerigi yikici islemi mi (sebep ister, saatlik siki hiz siniri). */
    static boolean clubDestructive(String method, String path) {
        return ("POST".equals(method) && CLUB_POST.matcher(path).matches())
                || ("DELETE".equals(method) && CLUB_DELETE.matcher(path).matches())
                || ("PATCH".equals(method) && CLUB_ROLE.matcher(path).matches());
    }

    /** P08: sohbet mudahalesi yazma islemi mi (sebep ister, saatlik siki hiz siniri). */
    static boolean chatDestructive(String method, String path) {
        return ("POST".equals(method) && CHAT_POST.matcher(path).matches())
                || ("DELETE".equals(method) && CHAT_DELETE.matcher(path).matches());
    }

    /** P11/P12: moderasyon af/geri alma/sablon silme, destek silme/birlestirme (sebep ister, saatlik siki hiz siniri). */
    static boolean modSupportDestructive(String method, String path) {
        return ("POST".equals(method) && (MOD_POST.matcher(path).matches() || SUPPORT_MERGE.matcher(path).matches()))
                || ("DELETE".equals(method)
                && (MOD_TEMPLATE_DELETE.matcher(path).matches() || SUPPORT_DELETE.matcher(path).matches()));
    }

    /** P13: mail bastirma/kuyruk yazma islemi mi (sebep ister, saatlik siki hiz siniri). */
    static boolean mailOpsDestructive(String method, String path) {
        return ("POST".equals(method) && MAIL_OPS_POST.matcher(path).matches())
                || ("DELETE".equals(method) && MAIL_OPS_DELETE.matcher(path).matches());
    }

    /** T-013: gonderi gizle/geri goster/sil ve haber gizleme/duzenleme (sebep ister). */
    static boolean contentModeration(String method, String path) {
        return ("POST".equals(method) && POST_HIDE.matcher(path).matches())
                || ("DELETE".equals(method) && POST_DELETE.matcher(path).matches())
                || ("PATCH".equals(method) && NEWS_ITEM.matcher(path).matches());
    }

    /** T-011/T-013: hesap islemleri (e-posta dogrulama, sifirlama, oturum kapatma) ve kullanici askiya alma/erisim engeli (POST). */
    static boolean accountOps(String method, String path) {
        return "POST".equals(method)
                && (USER_ACCOUNT_OPS.matcher(path).matches() || USER_SUSPEND.matcher(path).matches());
    }

    public static boolean isWrite(String method) {
        return "POST".equals(method) || "PUT".equals(method) || "PATCH".equals(method) || "DELETE".equals(method);
    }

    /** Kritik ayar anahtari mi (bakim modu, min surum, magaza adresi, sozlesme, destek e-postasi). */
    public static boolean criticalSetting(String key) {
        if (key == null) {
            return false;
        }
        String k = key.toLowerCase(java.util.Locale.ROOT);
        return CRITICAL_SETTING_PREFIXES.stream().anyMatch(k::startsWith);
    }

    /** Bu yazma istegi sebep ister mi: en kisa uzunluk, istemiyorsa 0. */
    public static int reasonMin(String method, String path) {
        if (!isWrite(method) || path == null) {
            return 0;
        }
        if ("PATCH".equals(method) && USER_ROLE.matcher(path).matches()) {
            return DEFAULT_MIN_REASON;
        }
        if ("DELETE".equals(method) && USER_DELETE.matcher(path).matches()) {
            return DEFAULT_MIN_REASON;
        }
        if ("POST".equals(method) && LEGAL_PUBLISH.matcher(path).matches()) {
            return DEFAULT_MIN_REASON;
        }
        // T-013: TUM ayar yazimlari gerekce ister (kritik olmayan ayar da herkese acik metni/davranisi degistirir)
        if ("PUT".equals(method) && SETTING.matcher(path).matches()) {
            return DEFAULT_MIN_REASON;
        }
        if ("POST".equals(method) && BULK.matcher(path).matches()) {
            return DEFAULT_MIN_REASON;
        }
        if (("POST".equals(method) && EVENT_DECIDE.matcher(path).matches())
                || ("DELETE".equals(method) && EVENT_DELETE.matcher(path).matches())) {
            return DEFAULT_MIN_REASON;
        }
        if (clubDestructive(method, path) || chatDestructive(method, path)) {
            return DEFAULT_MIN_REASON;
        }
        if ("POST".equals(method) && USER_EXPORT.matcher(path).matches()) {
            return EXPORT_MIN_REASON;
        }
        if (("PATCH".equals(method) && USER_PROFILE.matcher(path).matches())
                || ("DELETE".equals(method) && USER_EXTRA_DELETE.matcher(path).matches())) {
            return DEFAULT_MIN_REASON;
        }
        if (modSupportDestructive(method, path)) {
            return DEFAULT_MIN_REASON;
        }
        if (mailOpsDestructive(method, path)) {
            return DEFAULT_MIN_REASON;
        }
        if ("POST".equals(method) && PUSH_OUTBOX_CANCEL.matcher(path).matches()) {
            return DEFAULT_MIN_REASON;
        }
        if ("POST".equals(method) && P15_POST.matcher(path).matches()) {
            return DEFAULT_MIN_REASON;
        }
        if ("POST".equals(method) && RETENTION_POST.matcher(path).matches()) {
            return DEFAULT_MIN_REASON;
        }
        if (contentModeration(method, path) || accountOps(method, path)) {
            return DEFAULT_MIN_REASON;
        }
        if ("POST".equals(method) && (SENSITIVE_POST.matcher(path).matches() || PENDING_VERIFY.matcher(path).matches())) {
            return DEFAULT_MIN_REASON;
        }
        return 0;
    }

    /** Yikici/geri alinmasi zor islem mi (saatlik siki hiz siniri). */
    public static boolean destructive(String method, String path) {
        if (!isWrite(method) || path == null) {
            return false;
        }
        if (reasonMin(method, path) > 0) {
            return true;
        }
        return ("POST".equals(method) && USER_ACCOUNT_OPS.matcher(path).matches())
                || ("DELETE".equals(method) && PENDING_DELETE.matcher(path).matches())
                || (("POST".equals(method) || "DELETE".equals(method)) && BLOCKLIST.matcher(path).matches())
                || ("POST".equals(method) && SUSPEND_REC.matcher(path).matches());
    }
}
