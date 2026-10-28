package edu.bingol.backend.notification.outbox;

/**
 * Push kuyruk kaydinin durumu. FAILED = gecici hata, geri cekilmeyle yeniden denenecek.
 * CANCELLED = yonetici gonderilmeden iptal etti (yeniden kuyruga alinabilir).
 */
public enum PushOutboxStatus { PENDING, SENDING, SENT, FAILED, DEAD, CANCELLED }
