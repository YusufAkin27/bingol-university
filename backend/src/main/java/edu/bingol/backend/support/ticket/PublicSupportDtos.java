package edu.bingol.backend.support.ticket;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Herkese acik destek talebi (T27) istek/cevap sozlesmeleri. */
public final class PublicSupportDtos {

    private PublicSupportDtos() {}

    /** website: bal kabagi (honeypot) alani, gercek kullanici bos birakir. elapsedMs: formun doldurulma suresi. */
    public record SubmitRequest(@NotBlank @Size(max = 80) String name,
                                @NotBlank @Email @Size(max = 254) String email,
                                @NotNull SupportTicket.Category category,
                                @NotBlank @Size(min = 10, max = 2000) String message,
                                @Size(max = 200) String website,
                                Long elapsedMs) {}

    public record VerifyRequest(@NotBlank @Email @Size(max = 254) String email,
                                @NotBlank @Pattern(regexp = "\\d{6}") String code) {}

    public record TrackRequest(@NotBlank @Size(max = 128) String token) {}

    public record TrackReplyRequest(@NotBlank @Size(max = 128) String token,
                                    @NotBlank @Size(max = 2000) String text) {}

    /** Her zaman ayni cevap (enumerasyona/otomasyona karsi). */
    public record CodeSent(String status, int expiresInMinutes) {}

    /** E-posta dogrulandi: talep numarasi ve (yalnizca bu cevapta duz metin) durum sorgu anahtari. */
    public record Verified(Long ticketId, String trackToken) {}
}
