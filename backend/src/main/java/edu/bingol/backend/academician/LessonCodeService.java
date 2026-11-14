package edu.bingol.backend.academician;

import edu.bingol.backend.config.JwtProperties;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Service;

/**
 * Doner yoklama QR kodu (durumsuz, tablo yok; ClubJoinCodeService/CheckinCodeService kardesi):
 * {@code bingol-lesson:{oturumId}.{adim}.{MAC}}. Adim 5 sn; guncel + onceki adim kabul edilir (en cok 10 sn).
 * MAC = base64url(HMAC-SHA256(anahtar, "{oturumId}.{adim}") ilk 16 bayt); anahtar = HMAC(jwt.secret, "bingol-lesson-v1")
 * (baska QR kodlariyla karismaz). Yalnizca sunucu saati kullanilir; oturum durumu (acik/sure) cagirandan sinanir.
 */
@Service
public class LessonCodeService {

    public static final String PREFIX = "bingol-lesson:";
    public static final long STEP_SECONDS = 5;
    private static final int MAX_LENGTH = 300;
    private static final Pattern BODY = Pattern.compile("^([0-9]{1,18})\\.([0-9]{1,15})\\.([A-Za-z0-9_\\-]{1,64})$");

    /** Ekranda gosterilecek kod ve gecerlilik penceresi (sunucu saati, ms). */
    public record CodeWindow(String code, long fromMs, long untilMs) {}

    private final byte[] key;

    public LessonCodeService(JwtProperties jwt) {
        this.key = hmac(jwt.secret().getBytes(StandardCharsets.UTF_8), "bingol-lesson-v1");
    }

    public String generate(long sessionId, Instant now) {
        return generateForStep(sessionId, step(now));
    }

    String generateForStep(long sessionId, long step) {
        return PREFIX + sessionId + "." + step + "." + mac(sessionId, step);
    }

    /** Guncel adim + sonraki {@code count - 1} adim (canli ekran onceden alir; istemci sunucu saat farkina gore secer). */
    public List<CodeWindow> upcoming(long sessionId, Instant now, int count) {
        long s = step(now);
        List<CodeWindow> out = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            long st = s + i;
            out.add(new CodeWindow(generateForStep(sessionId, st), st * STEP_SECONDS * 1000, (st + 1) * STEP_SECONDS * 1000));
        }
        return out;
    }

    /** Kod gecerliyse oturum kimligini, degilse -1 doner. Guncel ve onceki adim kabul edilir; gelecek adim reddedilir. */
    public long verify(String code, Instant now) {
        if (code == null || code.length() > MAX_LENGTH) {
            return -1;
        }
        String s = code.trim();
        if (!s.startsWith(PREFIX)) {
            return -1;
        }
        Matcher m = BODY.matcher(s.substring(PREFIX.length()));
        if (!m.matches()) {
            return -1;
        }
        long id;
        long step;
        try {
            id = Long.parseLong(m.group(1));
            step = Long.parseLong(m.group(2));
        } catch (NumberFormatException e) {
            return -1;
        }
        boolean macOk = MessageDigest.isEqual(mac(id, step).getBytes(StandardCharsets.UTF_8),
                m.group(3).getBytes(StandardCharsets.UTF_8));
        long current = step(now);
        boolean inWindow = step <= current && step >= current - 1;
        return macOk && inWindow ? id : -1;
    }

    private static long step(Instant t) {
        return t.getEpochSecond() / STEP_SECONDS;
    }

    private String mac(long sessionId, long step) {
        byte[] full = hmac(key, sessionId + "." + step);
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
