package edu.bingol.backend.event.extras;

import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationTemplates.Template;
import edu.bingol.backend.notification.NotificationType;

/** T14 bildirim sablonlari (tr/en/ar metinleri messages*.properties sonundaki T14 blogunda). */
final class ExtrasTemplates {

    /** {0} etkinlik basligi, {1} duyuru basligi, {2} duyuru metni. */
    static final Template ANNOUNCEMENT = NotificationTemplates.register("notif.event.announcement",
            NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE);

    /** {0} etkinlik basligi. */
    static final Template CO_ORGANIZER_ADDED = NotificationTemplates.register("notif.event.coOrganizerAdded",
            NotificationType.EVENT, NotificationSubtype.EVENT_UPDATE);

    private ExtrasTemplates() {}
}
