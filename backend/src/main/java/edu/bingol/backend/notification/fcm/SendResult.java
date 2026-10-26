package edu.bingol.backend.notification.fcm;

import java.util.List;

/**
 * @param invalid   silinmesi gereken token'lar (UNREGISTERED / gecersiz token)
 * @param retryable gecici hatayla (UNAVAILABLE, INTERNAL, QUOTA) ulasmayan token'lar; yeniden denenir
 */
public record SendResult(List<String> invalid, List<String> retryable) {

    public static SendResult empty() {
        return new SendResult(List.of(), List.of());
    }
}
