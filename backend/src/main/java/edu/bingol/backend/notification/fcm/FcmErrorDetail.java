package edu.bingol.backend.notification.fcm;

import com.google.firebase.messaging.FirebaseMessagingException;
import java.util.regex.Pattern;

/**
 * FCM hatasindan guvenli, kisa tani metni uretir: hata sinifi, ErrorCode, HTTP durumu, kisa mesaj ve neden zinciri
 * (yalniz sinif adlari). Jeton, anahtar, e-posta ve uzun rastgele diziler maskelenir; en cok ~200 karakter mesaj.
 */
public final class FcmErrorDetail {

    static final int MAX_MESSAGE = 200;
    private static final Pattern EMAIL = Pattern.compile("[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+");
    private static final Pattern LONG_TOKEN = Pattern.compile("[A-Za-z0-9_\\-:./+=]{40,}");
    private static final Pattern BEARER = Pattern.compile("(?i)bearer\\s+\\S+");
    private static final Pattern PEM = Pattern.compile("-----BEGIN[^-]*-----[\\s\\S]*?(-----END[^-]*-----|$)");

    private FcmErrorDetail() {
    }

    public static String of(Throwable t) {
        StringBuilder sb = new StringBuilder(t.getClass().getSimpleName());
        if (t instanceof FirebaseMessagingException fme) {
            if (fme.getErrorCode() != null) {
                sb.append("; errorCode=").append(fme.getErrorCode().name());
            }
            if (fme.getMessagingErrorCode() != null) {
                sb.append("; fcmCode=").append(fme.getMessagingErrorCode().name());
            }
            if (fme.getHttpResponse() != null) {
                sb.append("; http=").append(fme.getHttpResponse().getStatusCode());
            }
        }
        String msg = mask(t.getMessage());
        if (!msg.isEmpty()) {
            sb.append("; msg=").append(msg);
        }
        StringBuilder causes = new StringBuilder();
        Throwable c = t.getCause();
        for (int i = 0; c != null && i < 4; i++, c = c.getCause()) {
            causes.append(causes.length() == 0 ? "" : " > ").append(c.getClass().getSimpleName());
        }
        if (causes.length() > 0) {
            sb.append("; cause=").append(causes);
        }
        return sb.toString();
    }

    static String mask(String s) {
        if (s == null) {
            return "";
        }
        String r = PEM.matcher(s).replaceAll("[key]");
        r = BEARER.matcher(r).replaceAll("Bearer [masked]");
        r = EMAIL.matcher(r).replaceAll("[email]");
        r = LONG_TOKEN.matcher(r).replaceAll("[masked]");
        r = r.replaceAll("\\s+", " ").trim();
        return r.length() > MAX_MESSAGE ? r.substring(0, MAX_MESSAGE) + "..." : r;
    }
}
