package edu.bingol.backend.auth.realemail;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** Role (Apple gizli e-posta) alan adi tespiti. */
class RelayEmailsTest {

    @Test
    void appleRelayDomainIsDetectedCaseInsensitively() {
        assertThat(RelayEmails.isRelay("abc123@privaterelay.appleid.com")).isTrue();
        assertThat(RelayEmails.isRelay("ABC@PrivateRelay.AppleID.com")).isTrue();
        assertThat(RelayEmails.isRelay("  x@privaterelay.appleid.com ")).isTrue();
    }

    @Test
    void realMailboxDomainsAreNotRelays() {
        assertThat(RelayEmails.isRelay("kisi@gmail.com")).isFalse();
        // iCloud+ gizli e-posta takma adlari gercek, teslim edilen adreslerdir
        assertThat(RelayEmails.isRelay("kisi@icloud.com")).isFalse();
        assertThat(RelayEmails.isRelay("kisi@appleid.com")).isFalse();
        // alt alan adi / ek / on ek hilesi
        assertThat(RelayEmails.isRelay("kisi@evil-privaterelay.appleid.com")).isFalse();
        assertThat(RelayEmails.isRelay("kisi@privaterelay.appleid.com.evil.com")).isFalse();
        assertThat(RelayEmails.isRelay("privaterelay.appleid.com@gmail.com")).isFalse();
    }

    @Test
    void nullBlankAndMalformedInputIsNotARelay() {
        assertThat(RelayEmails.isRelay(null)).isFalse();
        assertThat(RelayEmails.isRelay("")).isFalse();
        assertThat(RelayEmails.isRelay("@privaterelay.appleid.com")).isFalse();
        assertThat(RelayEmails.isRelay("kisi@")).isFalse();
        assertThat(RelayEmails.isRelay("yok-at")).isFalse();
    }
}
