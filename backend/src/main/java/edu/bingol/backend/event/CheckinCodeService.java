package edu.bingol.backend.event;

import edu.bingol.backend.config.JwtProperties;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Kisa omurlu QR yoklama kodu: "{eventId}.{pencere}.{HMAC}". Pencere 30 sn'lik zaman dilimidir; dogrulama
 * guncel ve bir onceki pencereyi kabul eder (kod 30-60 sn gecerli), boylece ekran goruntusu paylasimi hizla bosa cikar.
 * Anahtar jwt.secret'tan turetilir (alan ayrimi icin sabit etiketle), kodda sir yoktur.
 */
@Component
public class CheckinCodeService {

    /** Elle giris kodu: 6 karakter, karisan simgeler (0/O, 1/I) yok; 32 simge x 6 = 30 bit. */
    static final String MANUAL_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    static final int MANUAL_LENGTH = 6;

    static final long STEP_SECONDS = 30;
    /** Kodun en uzun gecerlilik suresi (sn): guncel + onceki pencere. */
    static final int MAX_VALID_SECONDS = (int) (STEP_SECONDS * 2);

    private final byte[] key;

    public CheckinCodeService(JwtProperties jwt) {
        this.key = hmac(jwt.secret().getBytes(StandardCharsets.UTF_8), "bingol-checkin-v1");
    }

    public String generate(long eventId, Instant now) {
        long w = window(now);
        return eventId + "." + w + "." + mac(eventId, w);
    }

    /**
     * Ayni pencereye bagli, tahmin edilemez 6 karakterli elle giris kodu (ornek K7M4QX). QR yukunden ayri bir HMAC
     * etiketiyle uretilir; QR imzasindan turetilemez. Gecerlilik QR ile aynidir (guncel + onceki pencere).
     */
    public String generateManual(long eventId, Instant now) {
        return manual(eventId, window(now));
    }

    /** Elle giris kodu biciminde mi (nokta yok, 6 simge); yazim farklari (kucuk harf, bosluk, tire) tolere edilir. */
    public static boolean looksManual(String code) {
        String n = normalizeManual(code);
        return n.length() == MANUAL_LENGTH && !code.contains(".");
    }

    /** Kodun gecerli son an'i (uretildigi pencereden sonraki pencerenin sonu). */
    public Instant expiresAt(Instant now) {
        return Instant.ofEpochSecond((window(now) + 2) * STEP_SECONDS);
    }

    public boolean verify(long eventId, String code, Instant now) {
        if (code == null) {
            return false;
        }
        if (looksManual(code)) {
            String n = normalizeManual(code);
            long current = window(now);
            boolean ok = MessageDigest.isEqual(manual(eventId, current).getBytes(StandardCharsets.UTF_8),
                    n.getBytes(StandardCharsets.UTF_8));
            // Iki pencereyi de her zaman hesapla (zamanlama farki sizdirma)
            boolean prev = MessageDigest.isEqual(manual(eventId, current - 1).getBytes(StandardCharsets.UTF_8),
                    n.getBytes(StandardCharsets.UTF_8));
            return ok | prev;
        }
        String[] p = code.trim().split("\\.", -1);
        if (p.length != 3) {
            return false;
        }
        long id;
        long w;
        try {
            id = Long.parseLong(p[0]);
            w = Long.parseLong(p[1]);
        } catch (NumberFormatException e) {
            return false;
        }
        long current = window(now);
        if (id != eventId || w > current || w < current - 1) {
            return false;
        }
        return MessageDigest.isEqual(mac(id, w).getBytes(StandardCharsets.UTF_8), p[2].getBytes(StandardCharsets.UTF_8));
    }

    private static String normalizeManual(String code) {
        return code == null ? "" : code.replaceAll("[\\s-]", "").toUpperCase(java.util.Locale.ROOT);
    }

    private String manual(long eventId, long window) {
        byte[] full = hmac(key, "manual:" + eventId + "." + window);
        int bits = ((full[0] & 0xFF) << 24 | (full[1] & 0xFF) << 16 | (full[2] & 0xFF) << 8 | (full[3] & 0xFF)) & 0x3FFFFFFF;
        StringBuilder sb = new StringBuilder(MANUAL_LENGTH);
        for (int i = MANUAL_LENGTH - 1; i >= 0; i--) {
            sb.append(MANUAL_ALPHABET.charAt((bits >> (i * 5)) & 31));
        }
        return sb.toString();
    }

    private static long window(Instant t) {
        return t.getEpochSecond() / STEP_SECONDS;
    }

    private String mac(long eventId, long window) {
        byte[] full = hmac(key, eventId + "." + window);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(Arrays.copyOf(full, 16));
    }

    private static byte[] hmac(byte[] key, String data) {
        try {
            Mac m = Mac.getInstance("HmacSHA256");
            m.init(new SecretKeySpec(key, "HmacSHA256"));
            return m.doFinal(data.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
