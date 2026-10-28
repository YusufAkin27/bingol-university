package edu.bingol.backend.mail;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * SMTP hatasinin ADRESE ozgu KALICI hata (kullanici bilinmiyor) olup olmadigini ayirir. Yalniz acik durumlar:
 * 550/551/553 kodu + adres/posta kutusu yok anlami. Politika/itibar retleri (5.7.x, spam, blocked), kota (552),
 * "islem basarisiz" (554) ve tum 4xx gecici hatalar KALICI SAYILMAZ (yeniden denenir).
 */
final class MailBounces {

    private static final Pattern CODE = Pattern.compile("(?<![0-9])(550|551|553)(?:[ -]|$)");
    private static final Pattern UNKNOWN_USER = Pattern.compile(
            "5\\.1\\.[0-9]|user unknown|no such user|unknown user|does not exist|does not exist|"
                    + "unknown recipient|invalid recipient|recipient (address )?rejected|mailbox (unavailable|not found)|"
                    + "address rejected|no mailbox|user not found|recipient not found");
    private static final Pattern POLICY = Pattern.compile(
            "5\\.7\\.[0-9]|spam|blocked|block list|blacklist|blocklist|reputation|policy|denied|not authorized|"
                    + "relay|dmarc|spf|dkim|rate limit|too many");

    private MailBounces() {
    }

    static boolean isPermanentRecipientFailure(Throwable error) {
        for (Throwable t = error; t != null; t = t.getCause() == t ? null : t.getCause()) {
            String msg = t.getMessage();
            if (msg == null) {
                continue;
            }
            String m = msg.toLowerCase(Locale.ROOT);
            if (CODE.matcher(m).find() && UNKNOWN_USER.matcher(m).find() && !POLICY.matcher(m).find()) {
                return true;
            }
        }
        return false;
    }
}
