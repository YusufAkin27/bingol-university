package edu.bingol.backend.dbmaint.admin;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Yonetici panelinden disa aktarilip temizlenebilen SISEN log/kuyruk tablolarinin SABIT beyaz listesi. Tablo ve kolon
 * adlari yalniz buradan SQL'e girer (kullanici girdisi degil). ASLA kullanici icerigi (mesaj, gonderi), sozlesme
 * onayi, ana tablo ya da yapilandirma buraya konmaz. Yeni log tablosu eklenince saklama suresi + buraya kayit birlikte
 * gelir (docs/DATABASE.md bolum 9 kural 4).
 */
public final class RetentionTables {

    /** Kolonun disa aktarimdaki maskeleme turu. */
    public enum Kind { PLAIN, EMAIL, OPAQUE }

    public record Col(String name, Kind kind) {
        static Col p(String n) {
            return new Col(n, Kind.PLAIN);
        }

        static Col email(String n) {
            return new Col(n, Kind.EMAIL);
        }

        static Col opaque(String n) {
            return new Col(n, Kind.OPAQUE);
        }
    }

    /**
     * @param timeColumn  aralik filtresi kolonu (TIMESTAMPTZ)
     * @param keyColumn   keyset sayfalama anahtari (artan, tekil)
     * @param extraWhere  tabloya ozel sabit kosul (ornek yalniz SENT/DEAD kuyruk satirlari) ya da bos
     * @param deletable   false ise yalniz disa aktarilir (ornek ekleme-yalniz tetikleyicili denetim)
     */
    public record Spec(String name, String label, String description, String timeColumn, String keyColumn,
                       String extraWhere, int minDays, boolean personalData, boolean deletable,
                       String notDeletableReason, List<Col> columns) {

        /** SQL kosulu: zaman araligi + tabloya ozel kosul ({@code :from}, {@code :to}). */
        public String rangeWhere() {
            String w = timeColumn + " >= :from AND " + timeColumn + " < :to";
            return extraWhere == null || extraWhere.isBlank() ? w : w + " AND (" + extraWhere + ")";
        }

        public String columnList() {
            return String.join(", ", columns.stream().map(Col::name).toList());
        }
    }

    private static final Map<String, Spec> ALL = new LinkedHashMap<>();

    private static void add(Spec s) {
        ALL.put(s.name(), s);
    }

    static {
        add(new Spec("admin_audit", "Yönetici işlem kaydı",
                "Yönetim panelinde yapılan yazma işlemlerinin ve kişisel veri okumalarının denetim kaydı.",
                "created_at", "id", "", 90, true, true, null, List.of(Col.p("id"), Col.p("admin_id"),
                Col.email("admin_email"), Col.p("method"), Col.p("path"), Col.p("status"), Col.p("target_type"),
                Col.p("target_id"), Col.p("reason"), Col.p("summary"), Col.p("request_id"), Col.opaque("ip"),
                Col.p("created_at"))));
        add(new Spec("message_access_audit", "Sohbet içeriği erişim kaydı",
                "Yöneticinin sohbet içeriğine erişim kayıtları (KVKK kanıtı).",
                "created_at", "id", "", 365, true, false,
                "Ekleme-yalnız kayıttır; veritabanı silmeyi engeller. Yalnız dışa aktarılabilir.",
                List.of(Col.p("id"), Col.p("admin_id"), Col.p("conversation_id"), Col.p("message_count"),
                        Col.p("from_message_id"), Col.p("to_message_id"), Col.p("reason"), Col.opaque("ip"),
                        Col.p("created_at"))));
        add(new Spec("club_audit", "Kulüp işlem kaydı", "Kulüp yönetimi (üye, rol, devir) denetim kaydı.",
                "created_at", "id", "", 90, true, true, null,
                List.of(Col.p("id"), Col.p("community_id"), Col.p("actor_id"), Col.p("target_user_id"),
                        Col.p("action"), Col.p("detail"), Col.p("created_at"))));
        add(new Spec("analytics_event", "Analitik ham olaylar",
                "Mobil kullanım olayları (ham). Günlük özet ayrı tabloda kalıcıdır, silinmez.",
                "created_at", "id", "", 7, true, true, null,
                List.of(Col.p("id"), Col.p("user_id"), Col.p("name"), Col.p("screen"), Col.p("props"),
                        Col.p("created_at"))));
        add(new Spec("notification", "Okunmuş bildirimler", "Kullanıcıların OKUNMUŞ uygulama içi bildirimleri.",
                "created_at", "id", "read_at IS NOT NULL", 30, true, true, null,
                List.of(Col.p("id"), Col.p("user_id"), Col.p("type"), Col.p("title"), Col.p("body"),
                        Col.p("read_at"), Col.p("created_at"))));
        add(new Spec("mail_outbox", "E-posta kuyruğu (gönderilmiş/ölü)",
                "Yalnız GÖNDERİLMİŞ (SENT) ve ÖLÜ (DEAD) e-posta kayıtları; bekleyenlere dokunulmaz. Gövde/değişkenler dışa aktarılmaz.",
                "created_at", "id", "status IN ('SENT', 'DEAD')", 7, true, true, null,
                List.of(Col.p("id"), Col.email("to_address"), Col.p("template"), Col.p("lang"), Col.p("status"),
                        Col.p("attempts"), Col.p("last_error"), Col.p("created_at"), Col.p("sent_at"))));
        add(new Spec("push_outbox", "Push kuyruğu (gönderilmiş/ölü)",
                "Yalnız GÖNDERİLMİŞ (SENT) ve ÖLÜ (DEAD) push kayıtları; yük (payload) dışa aktarılmaz.",
                "created_at", "id", "status IN ('SENT', 'DEAD')", 7, true, true, null,
                List.of(Col.p("id"), Col.p("user_id"), Col.p("device_id"), Col.p("status"), Col.p("attempts"),
                        Col.p("msg_type"), Col.p("campaign_id"), Col.p("error_code"), Col.p("last_error"),
                        Col.p("created_at"), Col.p("sent_at"))));
        add(new Spec("user_device_log", "Cihaz/IP geçmişi", "Kullanıcı × cihaz × IP görülme kayıtları (erişim engeli için).",
                "last_seen_at", "id", "", 30, true, true, null,
                List.of(Col.p("id"), Col.p("user_id"), Col.p("device_hash"), Col.p("platform"),
                        Col.p("app_version"), Col.opaque("ip"), Col.p("first_seen_at"), Col.p("last_seen_at"),
                        Col.p("last_event"), Col.p("seen_count"))));
        add(new Spec("blocked_attempt_log", "Engellenen erişim denemeleri", "Erişim engeline takılan istekler.",
                "attempted_at", "id", "", 30, true, true, null,
                List.of(Col.p("id"), Col.p("ban_id"), Col.p("kind"), Col.opaque("ip"), Col.p("device_hash"),
                        Col.p("user_id"), Col.p("path"), Col.p("attempted_at"))));
        add(new Spec("profanity_hit_log", "Uygunsuz ifade isabetleri", "Uygunsuz ifade filtresi isabet kayıtları (metin içermez).",
                "at", "id", "", 30, true, true, null,
                List.of(Col.p("id"), Col.p("field"), Col.p("entity"), Col.p("user_id"), Col.p("action"),
                        Col.p("at"))));
    }

    private RetentionTables() {}

    public static List<Spec> all() {
        return List.copyOf(ALL.values());
    }

    public static Optional<Spec> find(String name) {
        return name == null ? Optional.empty() : Optional.ofNullable(ALL.get(name.trim()));
    }
}
