package edu.bingol.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.AdminUserCreateController.CreateUserRequest;
import edu.bingol.backend.auth.AccountCreator;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;

/** Yonetici kullanici ekleme: dogrulama kurallari ve hesap olusturma cagrisi (AccountCreator, ADMIN_EMAILS terfisi YOK). */
class AdminUserCreateControllerTest {

    private AccountCreator accounts;
    private UserRepository users;
    private AdminUserCreateController controller;

    @BeforeEach
    void setUp() {
        accounts = mock(AccountCreator.class);
        users = mock(UserRepository.class);
        PasswordEncoder enc = mock(PasswordEncoder.class);
        when(enc.encode(any())).thenReturn("hash");
        controller = new AdminUserCreateController(accounts, users, enc,
                new AdminProperties(List.of("root@bingol.edu.tr")), mock(RateLimiter.class), mock(ContentGuard.class));
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(1L, null, List.of()));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private static CreateUserRequest req(String email, String pw) {
        return new CreateUserRequest(email, pw, "Ali Veli", "tr");
    }

    @Test
    void createsVerifiedAccountWithoutAdminPromotion() {
        User saved = new User();
        saved.setEmail("ali@example.com");
        saved.setDisplayName("Ali Veli");
        when(users.findByEmail("ali@example.com")).thenReturn(Optional.empty());
        when(accounts.create(eq("ali@example.com"), any(), eq(false))).thenReturn(saved);
        var out = controller.create(req(" Ali@Example.com ", "secret1"));
        assertThat(out.email()).isEqualTo("ali@example.com");
        verify(accounts).create(eq("ali@example.com"), any(), eq(false));
    }

    @Test
    void rejectsShortPasswordPlusAliasAdminEmailAndDuplicate() {
        assertThatThrownBy(() -> controller.create(req("a@example.com", "123")))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("PASSWORD_TOO_SHORT"));
        assertThatThrownBy(() -> controller.create(req("a+x@example.com", "secret1")))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("EMAIL_ALIAS_NOT_ALLOWED"));
        assertThatThrownBy(() -> controller.create(req("root@bingol.edu.tr", "secret1")))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.code()).isEqualTo("VERIFY_ADMIN_EMAIL_FORBIDDEN"));
        assertThatThrownBy(() -> controller.create(req("bozuk", "secret1")))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("EMAIL_FULL_REQUIRED"));
        when(users.findByEmail("var@example.com")).thenReturn(Optional.of(new User()));
        assertThatThrownBy(() -> controller.create(req("var@example.com", "secret1")))
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.code()).isEqualTo("EMAIL_ALREADY_REGISTERED"));
        verify(accounts, never()).create(any(), any(), eq(false));
    }
}
