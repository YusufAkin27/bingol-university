package edu.bingol.backend.notification.fcm;

import java.util.List;
import java.util.Map;

/**
 * @param invalid   silinmesi gereken token'lar (UNREGISTERED / gecersiz token)
 * @param retryable gecici hatayla (UNAVAILABLE, INTERNAL, QUOTA) ulasmayan token'lar; yeniden denenir
 * @param codes     token -> FCM hata kodu (UNREGISTERED, QUOTA_EXCEEDED...); yonetici hata listesi icin, bos olabilir
 */
public record SendResult(List<String> invalid, List<String> retryable, Map<String, String> codes) {

    public SendResult(List<String> invalid, List<String> retryable) {
        this(invalid, retryable, Map.of());
    }

    public static SendResult empty() {
        return new SendResult(List.of(), List.of());
    }
}
