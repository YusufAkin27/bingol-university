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

    /** Ihlal defteri (istege bagli: defter olmadan kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private edu.bingol.backend.moderation.ViolationLedgerService ledger;

    public AccountCreator(UserRepository users, LegalService legal, AdminProperties admin) {
        this.users = users;
        this.legal = legal;
        this.admin = admin;
    }

    /** E-posta KODU dogrulamasiyla gelen kayit: ADMIN_EMAILS adresi yonetici (FULL) olur. */
    @Transactional
    public User create(String email, Pending p) {
        return create(email, p, true);
    }

    /**
     * `promoteAdmin=false`: e-posta sahipligi KODLA kanitlanmadan (yonetici elle dogrulama) acilan hesap ADMIN_EMAILS
     * terfisi almaz (T-011); sabit FULL yonetici yalniz kodlu dogrulamayla olusur.
     */
    @Transactional
    public User create(String email, Pending p, boolean promoteAdmin) {
        User user = users.findByEmail(email).orElseGet(User::new);
        user.setEmail(email);
        user.setPasswordHash(p.passwordHash());
        user.setDisplayName(p.displayName());
        user.setLanguage(p.language());
        user.setFaculty(p.faculty());
        user.setDepartment(p.department());
        user.setGrade(p.grade());
        user.setEmailVerified(true);
        if (promoteAdmin && user.getRole() != Role.ADMIN && admin.isAdminEmail(email)) {
            user.setRole(Role.ADMIN);
            user.setAdminProfile(edu.bingol.backend.admin.rbac.AdminProfile.FULL); // ADMIN_EMAILS hesabi her zaman FULL
        }
        boolean fresh = user.getId() == null;
        user = users.saveAndFlush(user);
        legal.recordSignupConsent(user.getId());
        // Silinip ayni e-postayla yeniden kayit: ihlal defterindeki strike'lar devralinir (T-058)
        if (fresh && ledger != null) {
            ledger.inheritOnRegister(user.getId(), email);
        }
        return user;
    }
}
