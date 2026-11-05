package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailDailyQuota;
import edu.bingol.backend.profile.ProfileService;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Ertelenmis dogrulama otomatik tamamlama isi: kota payi (kalanin %50'si), kullanici basina kota gunu basina 1 kod,
 * en eski kayit once, tukenmis kota, 180 sn bekleme ve 14 gun saklama. H2 uzerinde duz SQL; posta/kota servisleri sahte.
 * Saat sabit: 2026-11-05 10:00Z; kota gunu baslangici 2026-11-04T21:00Z.
 */
@SpringBootTest
class DeferredVerificationJobTest {

    static final Instant NOW = Instant.parse("2026-11-05T10:00:00Z");
    static final Instant DAY_START = Instant.parse("2026-11-04T21:00:00Z");

    @Autowired JdbcTemplate jdbc;

    VerificationService verification;
    ProfileService profiles;
    MailDailyQuota quota;
    DeferredVerificationJob job;

    @BeforeEach
    void setUp() {
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'dvj-%'");
        verification = mock(VerificationService.class);
        profiles = mock(ProfileService.class);
        quota = mock(MailDailyQuota.class);
        when(quota.enabled()).thenReturn(true);
        when(quota.exhausted()).thenReturn(false);
        when(quota.dayStart(any(Instant.class))).thenReturn(DAY_START);
        when(quota.publicRemaining(MailDailyQuota.CodeKind.REGISTRATION)).thenReturn(100L); // butce = 50
        job = job(0.5, 200, 14);
    }

    DeferredVerificationJob job(double share, int perRun, int retentionDays) {
        return new DeferredVerificationJob(jdbc, verification, profiles, quota, null,
                Clock.fixed(NOW, ZoneOffset.UTC), true, share, perRun, retentionDays);
    }

    long user(String name, boolean verified, boolean deferred, Instant created, Instant mailed) {
        jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, verification_deferred, "
                + "verification_mailed_at, role, status, language, show_email, created_at) "
                + "VALUES (?, 'x', 'T', ?, ?, ?, 'USER', 'ACTIVE', 'en', FALSE, ?)",
                "dvj-" + name + "@bingol.edu.tr", verified, deferred, mailed == null ? null : Timestamp.from(mailed),
                Timestamp.from(created));
        return jdbc.queryForObject("SELECT id FROM app_user WHERE email = ?", Long.class, "dvj-" + name + "@bingol.edu.tr");
    }

    Instant ago(Duration d) {
        return NOW.minus(d);
    }

    @Test
    void sendsToDeferredUnverifiedUsersOldestFirstInTheirLanguage() {
        user("b", false, true, ago(Duration.ofHours(5)), null);
        user("a", false, true, ago(Duration.ofHours(9)), null);
        user("verified", true, true, ago(Duration.ofHours(9)), null);
        user("legacy", false, false, ago(Duration.ofHours(9)), null);

        assertEquals(2, job.sendCodes(NOW));

        var order = org.mockito.Mockito.inOrder(verification);
        order.verify(verification).issue("dvj-a@bingol.edu.tr", Lang.EN);
        order.verify(verification).issue("dvj-b@bingol.edu.tr", Lang.EN);
        verify(verification, times(2)).issue(anyString(), any());
    }

    @Test
    void atMostOneMailPerUserPerQuotaDay() {
        user("today", false, true, ago(Duration.ofDays(2)), ago(Duration.ofHours(2)));      // bugunun kotasinda postalandi
        long yesterday = user("yesterday", false, true, ago(Duration.ofDays(2)), ago(Duration.ofHours(20)));

        assertEquals(1, job.sendCodes(NOW));
        verify(verification).issue("dvj-yesterday@bingol.edu.tr", Lang.EN);

        // ayni kota gununde ikinci calisma kimseye tekrar gondermez
        assertEquals(0, job.sendCodes(NOW.plusSeconds(3600)));
        verify(verification, times(1)).issue(anyString(), any());
        assertNotNull(jdbc.queryForObject("SELECT verification_mailed_at FROM app_user WHERE id = ?", Timestamp.class, yesterday));
    }

    @Test
    void neverExceedsHalfOfTheRemainingRegistrationShare() {
        for (int i = 0; i < 10; i++) {
            user("u" + i, false, true, ago(Duration.ofHours(30 - i)), null);
        }
        when(quota.publicRemaining(MailDailyQuota.CodeKind.REGISTRATION)).thenReturn(7L); // %50 -> 3

        assertEquals(3, job.sendCodes(NOW));
        verify(verification, times(3)).issue(anyString(), any());
    }

    @Test
    void sendsNothingWhenTheProviderQuotaIsExhausted() {
        user("a", false, true, ago(Duration.ofHours(9)), null);
        when(quota.exhausted()).thenReturn(true);

        assertEquals(0, job.sendCodes(NOW));
        verify(verification, never()).issue(anyString(), any());
    }

    @Test
    void sendsNothingWhenNoRegistrationShareIsLeft() {
        user("a", false, true, ago(Duration.ofHours(9)), null);
        when(quota.publicRemaining(MailDailyQuota.CodeKind.REGISTRATION)).thenReturn(1L); // floor(0.5) = 0

        assertEquals(0, job.sendCodes(NOW));
        verify(verification, never()).issue(anyString(), any());
    }

    @Test
    void perRunCapAppliesEvenWithAHugeShare() {
        for (int i = 0; i < 5; i++) {
            user("c" + i, false, true, ago(Duration.ofHours(30 - i)), null);
        }
        when(quota.publicRemaining(MailDailyQuota.CodeKind.REGISTRATION)).thenReturn(1000L);

        assertEquals(2, job(0.5, 2, 14).sendCodes(NOW));
    }

    @Test
    void resendCooldownSkipsTheUserButStillCountsThemAsMailedToday() {
        long id = user("a", false, true, ago(Duration.ofHours(9)), null);
        doThrow(new RateLimitedException("RESEND_COOLDOWN", "x", 120)).when(verification).issue(anyString(), any());

        assertEquals(0, job.sendCodes(NOW));
        assertNotNull(jdbc.queryForObject("SELECT verification_mailed_at FROM app_user WHERE id = ?", Timestamp.class, id));
    }

    @Test
    void enqueueFailureReleasesTheClaimSoTheNextRunRetries() {
        long id = user("a", false, true, ago(Duration.ofHours(9)), null);
        doThrow(new IllegalStateException("kuyruk")).when(verification).issue(anyString(), any());

        assertEquals(0, job.sendCodes(NOW));
        assertNull(jdbc.queryForObject("SELECT verification_mailed_at FROM app_user WHERE id = ?", Timestamp.class, id));
    }

    @Test
    void disabledJobDoesNothing() {
        user("a", false, true, ago(Duration.ofHours(9)), null);
        DeferredVerificationJob off = new DeferredVerificationJob(jdbc, verification, profiles, quota, null,
                Clock.fixed(NOW, ZoneOffset.UTC), false, 0.5, 200, 14);

        assertEquals(0, off.sendCodes(NOW));
        assertEquals(0, off.purgeExpired(NOW));
        verify(verification, never()).issue(anyString(), any());
    }

    // ------------------------------------------------------------------ saklama

    @Test
    void purgesOnlyUnverifiedDeferredAccountsOlderThanRetention() {
        long old = user("old", false, true, ago(Duration.ofDays(15)), null);
        user("fresh", false, true, ago(Duration.ofDays(13)), null);
        user("oldverified", true, true, ago(Duration.ofDays(30)), null);
        user("oldlegacy", false, false, ago(Duration.ofDays(30)), null);

        assertEquals(1, job.purgeExpired(NOW));

        ArgumentCaptor<Long> ids = ArgumentCaptor.forClass(Long.class);
        verify(profiles, times(1)).anonymizeAccount(ids.capture());
        assertEquals(old, ids.getValue());
    }

    @Test
    void oneFailingPurgeDoesNotStopTheRest() {
        long a = user("pa", false, true, ago(Duration.ofDays(20)), null);
        long b = user("pb", false, true, ago(Duration.ofDays(19)), null);
        doThrow(new IllegalStateException("x")).when(profiles).anonymizeAccount(a);

        assertEquals(1, job.purgeExpired(NOW));
        verify(profiles).anonymizeAccount(b);
    }
}
