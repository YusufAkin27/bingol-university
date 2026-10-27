package edu.bingol.backend.auth;

import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.user.UserRepository;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Baska cihazdaki yeni girisle eski mobil oturum kapandiysa hesap sahibine guvenlik e-postasi gider
 * (`SECURITY_NEW_LOGIN` sablonu, kullanicinin dilinde, kuyruk uzerinden). Hata girisi bozmaz.
 */
@Component
public class NewLoginNotifier {

    private static final Logger log = LoggerFactory.getLogger(NewLoginNotifier.class);
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    private final UserRepository users;
    private final MailService mail;

    public NewLoginNotifier(UserRepository users, MailService mail) {
        this.users = users;
        this.mail = mail;
    }

    @EventListener
    public void onSessionsRevoked(SessionsRevokedEvent e) {
        if (!e.newLogin() || !e.hadSessions() || !"mobile".equals(e.client())) {
            return;
        }
        try {
            users.findById(e.userId()).ifPresent(u -> mail.sendNewLoginAlert(u.getEmail(), "BÜ Kampüs (mobil)",
                    TIME.format(ZonedDateTime.now(ZONE)), Lang.of(u.getLanguage())));
        } catch (RuntimeException ex) {
            log.warn("Yeni giris e-postasi kuyruga yazilamadi (user {}): {}", e.userId(), ex.toString());
        }
    }
}
