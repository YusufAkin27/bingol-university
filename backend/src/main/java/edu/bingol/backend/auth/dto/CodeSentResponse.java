package edu.bingol.backend.auth.dto;

/**
 * Kod e-postasi gonderen uclarin ortak cevabi. `resendAfterSeconds`: "yeniden gonder" dugmesinin acilacagi sure
 * (sunucu bekleme suresi; hesap var/yok fark etmeksizin AYNI deger). Eski istemciler yalniz `message` okur.
 */
public record CodeSentResponse(String message, long resendAfterSeconds) {
}
