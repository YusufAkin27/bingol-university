package edu.bingol.backend.mail.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.mail.MailDailyQuota;
import edu.bingol.backend.mail.MailStatus;
import edu.bingol.backend.mail.admin.MailOpsDtos.QuotaView;
import org.junit.jupiter.api.Test;

/** P13 kota gorunumu: yuzde/uyari esikleri, kalan, duyuru payi, sinirsiz mod (Redissiz bellek ici sayac). */
class MailQuotaAdminServiceTest {

    private static MailProperties props(int limit, int reserve, int resetHour) {
        return new MailProperties(true, "noreply@bukampus.online", "BU", 5000, 3, 20, false, "", 30, 300, "", 180, "",
                limit, reserve, resetHour);
    }

    private static MailQuotaAdminService service(MailDailyQuota q, MailProperties p) {
        MailOutboxQueryRepository repo = mock(MailOutboxQueryRepository.class);
        when(repo.countByStatus(MailStatus.DEAD)).thenReturn(3L);
        when(repo.countByStatus(MailStatus.PENDING)).thenReturn(7L);
        when(repo.oldestCreated(any())).thenReturn(null);
        return new MailQuotaAdminService(q, p, repo);
    }

    private static void sent(MailDailyQuota q, int n) {
        for (int i = 0; i < n; i++) {
            q.recordSent();
        }
    }

    @Test
    void levelsFollowThresholds() {
        MailProperties p = props(100, 20, 21);
        MailDailyQuota q = new MailDailyQuota(p);
        MailQuotaAdminService s = service(q, p);

        sent(q, 79);
        QuotaView ok = s.view();
        assertThat(ok.level()).isEqualTo("OK");
        assertThat(ok.used()).isEqualTo(79);
        assertThat(ok.remaining()).isEqualTo(21);
        assertThat(ok.announcementCap()).isEqualTo(80);
        assertThat(ok.announcementRemaining()).isEqualTo(1);

        sent(q, 1);
        QuotaView warn = s.view();
        assertThat(warn.percent()).isEqualTo(80.0);
        assertThat(warn.level()).isEqualTo("WARN");
        assertThat(warn.announcementRemaining()).isZero();

        sent(q, 15);
        assertThat(s.view().level()).isEqualTo("CRITICAL");
        sent(q, 20);
        QuotaView over = s.view();
        assertThat(over.remaining()).isZero();
        assertThat(over.percent()).isGreaterThan(100);
    }

    @Test
    void unlimitedModeReportsOffAndNoRemaining() {
        MailProperties p = props(0, 60, 21);
        QuotaView v = service(new MailDailyQuota(p), p).view();
        assertThat(v.enabled()).isFalse();
        assertThat(v.level()).isEqualTo("OFF");
        assertThat(v.percent()).isEqualTo(-1);
        assertThat(v.remaining()).isEqualTo(-1);
        assertThat(v.queue().dead()).isEqualTo(3);
        assertThat(v.queue().pending()).isEqualTo(7);
        assertThat(v.history()).hasSize(2);
    }

    @Test
    void exposesResetAndPublicCodeBudget() {
        MailProperties p = props(100, 20, 6);
        MailDailyQuota q = new MailDailyQuota(p);
        QuotaView v = service(q, p).view();
        assertThat(v.resetHourUtc()).isEqualTo(6);
        assertThat(v.publicCodeCapRegistration()).isEqualTo(60);
        assertThat(v.publicCodeCapReset()).isEqualTo(85);
        assertThat(v.publicCodeUsed()).isZero();
        assertThat(v.nextReset()).isNotBlank();
    }
}
