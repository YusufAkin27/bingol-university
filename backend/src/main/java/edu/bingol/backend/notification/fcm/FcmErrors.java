package edu.bingol.backend.notification.fcm;

import com.google.firebase.messaging.MessagingErrorCode;

/** FCM hata kodlarini eylemlere ayirir (saf fonksiyon; SDK sinifi olusturmadan test edilir). */
public final class FcmErrors {

    public enum Kind { INVALID_TOKEN, RETRYABLE, PERMANENT }

    private FcmErrors() {}

    /**
     * INVALID_ARGUMENT hem gecersiz token hem bozuk yuk icin doner; yuk hatasinda butun token'lari silmemek icin
     * yalnizca mesaj "token"dan bahsediyorsa token gecersiz sayilir.
     */
    public static Kind classify(MessagingErrorCode code, String message) {
        if (code == null) {
            return Kind.RETRYABLE; // ag/zaman asimi gibi kodsuz hatalar gecicidir
        }
        return switch (code) {
            case UNREGISTERED, SENDER_ID_MISMATCH -> Kind.INVALID_TOKEN;
            case INVALID_ARGUMENT -> message != null && message.toLowerCase().contains("token")
                    ? Kind.INVALID_TOKEN : Kind.PERMANENT;
            case UNAVAILABLE, INTERNAL, QUOTA_EXCEEDED -> Kind.RETRYABLE;
            default -> Kind.PERMANENT;
        };
    }
}
