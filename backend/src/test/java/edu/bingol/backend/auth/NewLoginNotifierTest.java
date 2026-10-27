package edu.bingol.backend.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class NewLoginNotifierTest {

    private final UserRepository users = mock(UserRepository.class);
    private final MailService mail = mock(MailService.class);
    private final NewLoginNotifier notifier = new NewLoginNotifier(users, mail);

    private User user(String lang) {
        User u = new User();
        u.setEmail("a@bingol.edu.tr");
        u.setLanguage(lang);
        when(users.findById(7L)).thenReturn(Optional.of(u));
        return u;
    }

    @Test
    void sendsAlertOnlyWhenAnOldMobileSessionWasReplaced() {
        user("en");

        notifier.onSessionsRevoked(new SessionsRevokedEvent(7L, "mobile", true, false)); // eski oturum yoktu
        notifier.onSessionsRevoked(new SessionsRevokedEvent(7L)); // logout-all
        verify(mail, never()).sendNewLoginAlert(anyString(), anyString(), anyString(), any());

        notifier.onSessionsRevoked(new SessionsRevokedEvent(7L, "mobile", true, true));
        verify(mail).sendNewLoginAlert(eq("a@bingol.edu.tr"), anyString(), anyString(), eq(Lang.EN));
    }

    @Test
    void mailFailureDoesNotBreakLogin() {
        user("tr");
        org.mockito.Mockito.doThrow(new IllegalStateException("smtp")).when(mail)
                .sendNewLoginAlert(anyString(), anyString(), anyString(), any());

        notifier.onSessionsRevoked(new SessionsRevokedEvent(7L, "mobile", true, true));
    }
}
