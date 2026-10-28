package edu.bingol.backend.notification.fcm;

/**
 * FCM yapilandirma kontrolu sonucu. Sir icermez: yalnizca Firebase proje kimligi (gizli degil) ve hata KODU.
 *
 * @param enabled   kimlik bilgisi yuklendi ve Firebase Admin baslatildi
 * @param validated Firebase'e validateOnly (kuru calistirma, cihaza gitmez) istegi basarili oldu
 * @param projectId Firebase proje kimligi (varsa)
 * @param error     basarisizsa kisa neden kodu (ornek: UNAUTHENTICATED, DISABLED); aksi halde null
 */
public record FcmCheck(boolean enabled, boolean validated, String projectId, String error) {}
