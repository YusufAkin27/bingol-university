package edu.bingol.backend.notification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class NotificationPref {

    @Id
    private Long userId;

    private boolean news = true;
    private boolean announcements = true;
    private boolean events = true;
    private boolean messages = true;
    private boolean communities = true;
    /** Anket bildirimleri ve akademik (bolum) duyurular: V880; ana turden bagimsiz kendi bayraklari. */
    @Column(columnDefinition = "boolean not null default true")
    private boolean polls = true;
    @Column(columnDefinition = "boolean not null default true")
    private boolean academicAnnouncements = true;

    /**
     * Sohbet mesaj metni onizlemesi push govdesinde (ve kilit ekraninda) gorunsun mu (V890). Varsayilan KAPALI:
     * metin Google/Apple push sunucularindan gecer; yalniz kullanici acikca isterse gonderilir.
     */
    @Column(columnDefinition = "boolean not null default false")
    private boolean messagePreview = false;

    /** Sessiz saatler: gunun dakikasi (0-1439); varsayilan 22:00-07:00, kullanici saat diliminde. */
    private boolean quietEnabled = false;
    private int quietStart = 1320;
    private int quietEnd = 420;
    private String timezone = "Europe/Istanbul";

    public static NotificationPref defaults(Long userId) {
        NotificationPref p = new NotificationPref();
        p.setUserId(userId);
        return p;
    }
}
