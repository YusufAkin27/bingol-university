package edu.bingol.backend.notification.outbox;

/** Push kuyruk kaydinin durumu. FAILED = gecici hata, geri cekilmeyle yeniden denenecek. */
public enum PushOutboxStatus { PENDING, SENDING, SENT, FAILED, DEAD }
