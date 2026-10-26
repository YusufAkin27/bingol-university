package edu.bingol.backend.notification;

import java.util.Collection;
import java.util.Collections;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Yerellestirilmis bildirim sablonlari kaydi. Yeni ozellik tek satirla sablon ekler:
 * <pre>
 *   static final Template APPLIED = NotificationTemplates.register("notif.event.applied",
 *           NotificationType.EVENT, NotificationSubtype.EVENT_ADMISSION);
 *   notifications.sendTemplate(userId, APPLIED, data, collapseKey, eventTitle);
 * </pre>
 * Anahtar `<key>.title` ve `<key>.body` olarak messages*.properties'e (tr/en/ar) eklenmelidir; eksikleri
 * NotificationTemplatesTest yakalar.
 */
public final class NotificationTemplates {

    /** @param key anahtar oneki; @param subtype null olabilir */
    public record Template(String key, NotificationType type, NotificationSubtype subtype) {}

    private static final Map<String, Template> REGISTRY = new ConcurrentHashMap<>();

    static {
        // Mevcut ozelliklerin sablonlari (geriye uyumlu alt tur cikarimi icin).
        register("notif.event.approved", NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE);
        register("notif.event.rejected", NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE);
        register("notif.event.rejectedNote", NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE);
        register("notif.event.updated", NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE);
        register("notif.event.cancelled", NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE);
        register("notif.event.reminderDay", NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER);
        register("notif.event.reminderHour", NotificationType.EVENT, NotificationSubtype.EVENT_REMINDER);
        register("notif.community.joinRequest", NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_JOIN);
        register("notif.community.joinApproved", NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_JOIN);
        register("notif.community.joinRejected", NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_JOIN);
        register("notif.community.moderator", NotificationType.COMMUNITY, NotificationSubtype.COMMUNITY_ROLE);
        register("notif.community.approved", NotificationType.COMMUNITY, null);
        register("notif.community.rejected", NotificationType.COMMUNITY, null);
        register("notif.community.rejectedNote", NotificationType.COMMUNITY, null);
    }

    private NotificationTemplates() {}

    public static Template register(String key, NotificationType type, NotificationSubtype subtype) {
        if (subtype != null && subtype.parent() != type) {
            throw new IllegalArgumentException("Alt tur " + subtype + " ana tur " + type + " ile uyumsuz");
        }
        Template t = new Template(key, type, subtype);
        REGISTRY.put(key, t);
        return t;
    }

    public static Optional<Template> find(String key) {
        return Optional.ofNullable(REGISTRY.get(key));
    }

    public static Collection<Template> all() {
        return Collections.unmodifiableCollection(REGISTRY.values());
    }
}
