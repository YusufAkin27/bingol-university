package edu.bingol.backend.moderation;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Kullanici askiya alma / geri acma. Askiya alinan kullanicinin mevcut token'lari Redis anahtariyla aninda gecersiz olur. */
@Service
public class UserModerationService {

    private final UserRepository users;
    private final StringRedisTemplate redis;
    private final NotificationService notifications;

    public UserModerationService(UserRepository users, StringRedisTemplate redis, NotificationService notifications) {
        this.users = users;
        this.redis = redis;
        this.notifications = notifications;
    }

    @Transactional
    public void suspend(Long userId, String reason) {
        User u = find(userId);
        if (u.getRole() == Role.ADMIN) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_SUSPEND_ADMIN", "Yönetici askıya alınamaz.");
        }
        u.setStatus(UserStatus.SUSPENDED);
        u.setSuspendedReason(reason);
        users.save(u);
        redis.opsForValue().set(JwtAuthFilter.SUSPENDED_KEY_PREFIX + userId, "1");
    }

    @Transactional
    public void unsuspend(Long userId) {
        User u = find(userId);
        if (u.getStatus() == UserStatus.SUSPENDED) {
            u.setStatus(UserStatus.ACTIVE);
            u.setSuspendedReason(null);
            users.save(u);
        }
        redis.delete(JwtAuthFilter.SUSPENDED_KEY_PREFIX + userId);
        notifications.sendLocalized(userId, NotificationType.SYSTEM, "notif.account.reactivated.title", null, null, null);
    }

    private User find(Long id) {
        return users.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
    }
}
