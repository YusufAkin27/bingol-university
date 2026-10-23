package edu.bingol.backend.notification;

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

    public static NotificationPref defaults(Long userId) {
        NotificationPref p = new NotificationPref();
        p.setUserId(userId);
        return p;
    }
}
