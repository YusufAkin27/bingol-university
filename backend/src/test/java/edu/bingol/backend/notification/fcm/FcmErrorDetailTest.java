package edu.bingol.backend.notification.fcm;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import org.junit.jupiter.api.Test;

class FcmErrorDetailTest {

    @Test
    void masksSecretsAndShortensMessage() {
        String tok = "ya29.a0AfH6SMBx1234567890abcdefghijklmnopqrstuvwxyz1234567890";
        String d = FcmErrorDetail.of(new IllegalStateException(
                "fail Bearer " + tok + " for svc@bu-kamp.iam.gserviceaccount.com token " + tok + " " + "x".repeat(500)));
        assertTrue(d.startsWith("IllegalStateException; msg="), d);
        assertFalse(d.contains("ya29"), d);
        assertFalse(d.contains("@bu-kamp"), d);
        assertTrue(d.length() < 330, "uzunluk " + d.length());
    }

    @Test
    void includesCauseChainClassNamesOnly() {
        var e = new RuntimeException("outer", new IOException("secret detail", new java.net.UnknownHostException("h")));
        String d = FcmErrorDetail.of(e);
        assertTrue(d.contains("cause=IOException > UnknownHostException"), d);
        assertFalse(d.contains("secret detail"), d);
    }

    @Test
    void nullMessageIsEmpty() {
        assertEquals("", FcmErrorDetail.mask(null));
        assertEquals("RuntimeException", FcmErrorDetail.of(new RuntimeException()));
    }
}
