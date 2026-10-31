package edu.bingol.backend.notification;

import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/** Alici bildirim alabilir mi: hesap var ve ACTIVE (askida/silinmis degil). */
@Component
public class RecipientGuard {

    /** Birim testler icin: herkes alabilir. */
    public static final RecipientGuard ALLOW_ALL = new RecipientGuard(null);

    private final UserRepository users;

    @Autowired
    public RecipientGuard(UserRepository users) {
        this.users = users;
    }

    public boolean canReceive(Long userId) {
        if (users == null) {
            return true;
        }
        return users.findById(userId).map(User::isActive).orElse(false);
    }

    /**
     * Toplu karsiligi (tek sorgu): bildirim alabilen kullanicilar ve kayitli dilleri. `users` yoksa (birim testler)
     * herkes alabilir ve dil bilinmez (deger null: cagiran dili kendisi cozer).
     */
    public Map<Long, Lang> receivable(Collection<Long> userIds) {
        Map<Long, Lang> out = new HashMap<>();
        if (users == null) {
            userIds.forEach(id -> out.put(id, null));
            return out;
        }
        users.findAllById(userIds).forEach(u -> {
            if (u.isActive()) {
                out.put(u.getId(), Lang.of(u.getLanguage()));
            }
        });
        return out;
    }
}
