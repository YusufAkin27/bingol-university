package edu.bingol.backend.notification;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Stitch bildirim tasarimindaki kart turleri (docs/changes/push.md "Bildirim kartlari"). Her kart: Android kanali,
 * eylem dugmeleri (`actions`, virgullu kimlikler) ve gorsel stili. Karar TEK yerde verilir: hem push yuku
 * ({@link PushMessages}) hem bildirim kutusu satiri ({@code NotificationView}) buradan turetilir.
 * <p>
 * Kart, once verideki `card` anahtarindan (uretici ya da sablon anahtari belirler), yoksa tur/alt turden cozulur.
 * `card` bildirim satirinin `data` JSON'una da yazilir; boylece eski satirlar da eylem alir.
 */
public enum NotifCard {
    // Sohbet (kanal chat)
    CHAT_DM("chat", "reply,mark_read", null),
    CHAT_GROUP("chat", "reply,mute_1h", null),
    CHAT_PHOTO("chat", "view,reply", "big"),
    CHAT_MANY("chat", "reply,mark_read", null),
    // Etkinlik (kanal event)
    EVENT_DAY("event", "calendar,view", null),
    EVENT_HOUR("event", "qr_checkin", null),
    EVENT_CHANGED("event", "view", null),
    EVENT_ADMISSION("event", "view", null),
    EVENT_CANCELLED("event", "view", null),
    // Duyuru / haber / akademik
    ANNOUNCEMENT("announcement", "view", null),
    UNIT_ANNOUNCEMENT("announcement", "view", null),
    ACADEMIC_ANNOUNCEMENT("academic", "view", null),
    NEWS("announcement", "view", "thumb"),
    EXAM_REMINDER("academic", "exam_card", null),
    MENU_TODAY("announcement", "view", "thumb"),
    // Anket
    POLL_NEW("poll", "vote", null),
    POLL_CLOSING("poll", "vote", null),
    // Sosyal
    POST_LIKE("social", "view", "thumb"),
    USER_FOLLOW("social", "follow_back", null),
    FOLLOW_REQUEST("social", "accept,reject", null),
    FOLLOW_ACCEPTED("social", "view", null),
    // Hesap guvenligi (kanal security; kapatilamaz, sessiz saati asar)
    SECURITY_NEW_DEVICE("security", "not_me,view", null),
    SECURITY_PASSWORD("security", "reset_password", null),
    SECURITY_2FA_OFF("security", "enable_2fa", null),
    SECURITY_2FA_ON("security", "view", null),
    SECURITY_SESSION("security", "sign_out_device", null),
    // Destek yaniti (kanal announcement: `system` adinda bir Android kanali yoktur)
    SUPPORT_TICKET("announcement", "view_ticket", null);

    private final String channel;
    private final List<String> actions;
    private final String imageStyle;

    NotifCard(String channel, String actions, String imageStyle) {
        this.channel = channel;
        this.actions = List.of(actions.split(","));
        this.imageStyle = imageStyle;
    }

    public String channel() {
        return channel;
    }

    /** Eylem kimlikleri (siraya duyarli). */
    public List<String> actions() {
        return actions;
    }

    public String actionsCsv() {
        return String.join(",", actions);
    }

    /** `big` (genis, sohbet fotografi) | `thumb` (sagda kucuk) | null (gorsel yok). Yalniz `imageUrl` varken yuke girer. */
    public String imageStyle() {
        return imageStyle;
    }

    /** Hesap guvenligi karti mi (tercih/sessiz saat uygulanmaz, uygulama on plandayken de gosterilir). */
    public boolean security() {
        return channel.equals("security");
    }

    /** Grup/kulup avatari rozeti cizilsin mi. */
    public boolean groupBadge() {
        return this == CHAT_GROUP;
    }

    /** iOS bildirim kategorisi: eylem kumesinden deterministik (`BU_REPLY_MARK_READ`); mobil bu adlari kaydeder. */
    public String iosCategory() {
        return "BU_" + actionsCsv().toUpperCase(Locale.ROOT).replace(',', '_');
    }

    /** Sablon/baslik anahtarindan kart (kayitli degilse null). Anahtar `.title`/`.body` soneki ile gelebilir. */
    public static NotifCard forKey(String key) {
        if (key == null) {
            return null;
        }
        String k = key.endsWith(".title") ? key.substring(0, key.length() - 6)
                : key.endsWith(".body") ? key.substring(0, key.length() - 5) : key;
        return switch (k) {
            case "notif.event.reminderDay" -> EVENT_DAY;
            case "notif.event.reminderHour" -> EVENT_HOUR;
            case "notif.event.updated" -> EVENT_CHANGED;
            case "notif.event.cancelled", "notif.event.cancelledByAdmin" -> EVENT_CANCELLED;
            case "notif.admission.accepted", "notif.admission.promoted" -> EVENT_ADMISSION;
            case "notif.poll.opened" -> POLL_NEW;
            case "notif.poll.closing" -> POLL_CLOSING;
            case "notif.academic.examReminder", "notif.academic.examReminderRoom" -> EXAM_REMINDER;
            case "notif.academic.announcement" -> ACADEMIC_ANNOUNCEMENT;
            case "notif.unitnews.new" -> UNIT_ANNOUNCEMENT;
            case "notif.menu.today", "notif.menu.todayPartial", "notif.menu.todayPlain" -> MENU_TODAY;
            case "notif.ticket.answered" -> SUPPORT_TICKET;
            case "notif.twofactor.enabled" -> SECURITY_2FA_ON;
            case "notif.twofactor.userdisabled", "notif.twofactor.disabled" -> SECURITY_2FA_OFF;
            case "notif.twofactor.wrongcodes" -> SECURITY_PASSWORD;
            case "notif.security.newdevice" -> SECURITY_NEW_DEVICE;
            case "notif.security.password" -> SECURITY_PASSWORD;
            case "notif.security.session" -> SECURITY_SESSION;
            default -> null;
        };
    }

    /** Veri anahtari `card` gecerli bir kart adiysa o; degilse null. */
    public static NotifCard parse(String name) {
        if (name == null || name.isBlank()) {
            return null;
        }
        try {
            return valueOf(name.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    /**
     * Karti cozer: veri `card` > tur/alt tur. Sohbet turu veriden (gorsel, adet, grup) ayrilir. Tanimsiz kombinasyon
     * (kulup duyurusu, moderasyon...) icin null: genel yol (kanal turden, eylem yok).
     */
    public static NotifCard resolve(NotificationType type, NotificationSubtype subtype, Map<String, String> data, int count) {
        NotifCard explicit = data == null ? null : parse(data.get("card"));
        if (explicit != null) {
            return explicit;
        }
        if (type == NotificationType.MESSAGE) {
            boolean photo = data != null && (notBlank(data.get("imageUrl")) || notBlank(data.get("imageAttachmentId")));
            boolean group = subtype == NotificationSubtype.MESSAGE_GROUP
                    || data != null && "GROUP".equals(data.get("conversationType"));
            return photo ? CHAT_PHOTO : count > 1 ? CHAT_MANY : group ? CHAT_GROUP : CHAT_DM;
        }
        if (subtype != null) {
            switch (subtype) {
                case EVENT_REMINDER: return EVENT_DAY;
                case EVENT_UPDATE: return EVENT_CHANGED;
                case EVENT_ADMISSION: return EVENT_ADMISSION;
                case POLL: return POLL_NEW;
                case ACADEMIC_ANNOUNCEMENT: return ACADEMIC_ANNOUNCEMENT;
                case EXAM_REMINDER: return EXAM_REMINDER;
                case UNIT_ANNOUNCEMENT: return UNIT_ANNOUNCEMENT;
                case MENU_DAILY: return MENU_TODAY;
                case POST_LIKE: return POST_LIKE;
                case USER_FOLLOW: return USER_FOLLOW;
                case FOLLOW_REQUEST: return FOLLOW_REQUEST;
                case FOLLOW_ACCEPTED: return FOLLOW_ACCEPTED;
                default: break;
            }
        }
        if (data != null && data.containsKey("pollId")) {
            return POLL_NEW; // genel yayin (broadcastLocalized) anket acildi: sablon anahtari yok, kimlikten bilinir
        }
        return switch (type) {
            case NEWS -> NEWS;
            case ANNOUNCEMENT -> ANNOUNCEMENT;
            case POST_LIKE -> POST_LIKE;
            case USER_FOLLOW -> USER_FOLLOW;
            case FOLLOW_REQUEST -> FOLLOW_REQUEST;
            case FOLLOW_ACCEPTED -> FOLLOW_ACCEPTED;
            default -> null;
        };
    }

    /**
     * Cozulen kartin push yuku anahtarlari: `card`, `channelId`, `actions`, `iosCategory`, (grup ise) `groupBadge`.
     * `imageStyle` yalniz `imageUrl` yukte varsa eklenir; mevcut anahtarlar EZILMEZ (uretici onceligi).
     */
    public Map<String, String> pushKeys(Map<String, String> existing) {
        Map<String, String> out = new LinkedHashMap<>();
        out.put("card", name());
        out.put("channelId", channel);
        out.put("actions", actionsCsv());
        out.put("iosCategory", iosCategory());
        if (groupBadge() || existing != null && "GROUP".equals(existing.get("conversationType"))) {
            out.put("groupBadge", "1"); // grup/kulup odasi: avatara rozet (fotografli/birikmis karta da)
        }
        if (imageStyle != null && existing != null && notBlank(existing.get("imageUrl"))) {
            out.put("imageStyle", imageStyle);
        }
        return out;
    }

    /** Bildirim kutusu satiri icin: kart + eylemler (kanal/kategori yok). */
    public static NotifCard ofRow(NotificationType type, String subtype, Map<String, String> data) {
        return resolve(type, NotificationSubtype.parse(subtype), data, 1);
    }

    private static boolean notBlank(String s) {
        return s != null && !s.isBlank();
    }
}
