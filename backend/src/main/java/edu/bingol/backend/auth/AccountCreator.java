package edu.bingol.backend.auth;

import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.legal.LegalService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Dogrulanan kaydin hesabini olusturur. Ayri bean: @Transactional AuthService icinden self-invocation ile
 * calismazdi. Kullanici + sozlesme onayi tek transaction'dadir; biri duserse ikisi de geri alinir.
 */
@Component
public class AccountCreator {

    private final UserRepository users;
    private final LegalService legal;
    private final AdminProperties admin;

    public AccountCreator(UserRepository users, LegalService legal, AdminProperties admin) {
        this.users = users;
        this.legal = legal;
        this.admin = admin;
    }

    @Transactional
    public User create(String email, Pending p) {
        User user = users.findByEmail(email).orElseGet(User::new);
        user.setEmail(email);
        user.setPasswordHash(p.passwordHash());
        user.setDisplayName(p.displayName());
        user.setLanguage(p.language());
        user.setEmailVerified(true);
        if (user.getRole() != Role.ADMIN && admin.isAdminEmail(email)) {
            user.setRole(Role.ADMIN);
        }
        user = users.saveAndFlush(user);
        legal.recordSignupConsent(user.getId());
        return user;
    }
}
