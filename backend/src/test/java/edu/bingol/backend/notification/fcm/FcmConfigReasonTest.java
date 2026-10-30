package edu.bingol.backend.notification.fcm;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** FCM kapaliyken neden sessiz kalmaz: yonetici durum ucu / saglik `error` alani kapali olma nedenini tasir. */
class FcmConfigReasonTest {

    @Test
    void noCredentialsIsReportedAsSuch() {
        FcmSender s = new FcmConfig().fcmSender("", "");

        assertThat(s.enabled()).isFalse();
        assertThat(s.check(false).error()).isEqualTo("NO_CREDENTIALS");
    }

    @Test
    void brokenCredentialsAreReportedWithExceptionClassNotContent() {
        FcmSender s = new FcmConfig().fcmSender("%%%bozuk-base64-gizli%%%", "");

        assertThat(s.enabled()).isFalse();
        assertThat(s.check(false).error()).startsWith("INIT_FAILED:").doesNotContain("gizli");
    }
}
