package edu.bingol.backend.auth.token;

/** Kullanicinin tum oturumlari iptal edildi (sifre degisimi, "tum cihazlardan cik"); WebSocket tarafi dinler. */
public record SessionsRevokedEvent(Long userId) {}
