package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import java.util.List;
import edu.bingol.backend.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

class AuthServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(),
            mock(JwtService.class), mock(RefreshTokenService.class), verification, new AdminProperties(List.of()));

    @ParameterizedTest
    @ValueSource(strings = {"a@gmail.com", "a@bingol.edu.tr.evil.com", "a@evilbingol.edu.tr", "a@bingol.edu.com"})
    void rejectsNonUniversityEmails(String email) {
        ApiException e = assertThrows(ApiException.class, () -> auth.register(email, "Sifre1234", "Ali"));

        assertEquals("EMAIL_DOMAIN_NOT_ALLOWED", e.code());
        verifyNoInteractions(users, verification);
    }

    @Test
    void normalizesEmail() {
        assertEquals("ali.veli@bingol.edu.tr", AuthService.normalizeEmail("  Ali.Veli@Bingol.EDU.tr "));
    }
}
