package edu.bingol.backend.notification;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
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
}
