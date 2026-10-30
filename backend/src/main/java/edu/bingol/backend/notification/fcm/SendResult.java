package edu.bingol.backend.notification.fcm;

import java.util.List;
import java.util.Map;

/**
 * @param invalid   silinmesi gereken token'lar (UNREGISTERED / gecersiz token)
 * @param retryable gecici hatayla (UNAVAILABLE, INTERNAL, QUOTA) ulasmayan token'lar; yeniden denenir
 * @param codes     token -> FCM hata kodu (UNREGISTERED, QUOTA_EXCEEDED...); yonetici hata listesi icin, bos olabilir
 * @param permanent kalici hata (THIRD_PARTY_AUTH_ERROR = APNs anahtari eksik, INVALID_ARGUMENT yuk hatasi, yetki...):
 *                  yeniden denemek ise yaramaz ama BASARILI SAYILMAZ; kayit hata koduyla DEAD olur (token silinmez)
 */
public record SendResult(List<String> invalid, List<String> retryable, Map<String, String> codes, List<String> permanent) {

    public SendResult(List<String> invalid, List<String> retryable, Map<String, String> codes) {
        this(invalid, retryable, codes, List.of());
    }

    public SendResult(List<String> invalid, List<String> retryable) {
        this(invalid, retryable, Map.of(), List.of());
    }

    public static SendResult empty() {
        return new SendResult(List.of(), List.of());
    }
}
