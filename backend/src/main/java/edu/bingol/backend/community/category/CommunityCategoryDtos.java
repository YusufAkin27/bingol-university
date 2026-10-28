package edu.bingol.backend.community.category;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/** Kulup kategorisi uclarinin istek/yanit kayitlari. */
public final class CommunityCategoryDtos {

    private CommunityCategoryDtos() {}

    /**
     * Herkese acik satir. {@code category} eski alan adidir (= key; kesfet filtresi ve kulup.category degeri),
     * {@code count} kesfette gorunen (ACTIVE + PUBLIC) kulup sayisi; yeni alanlar: key, name (istek dilinde),
     * icon, sortOrder.
     */
    public record PublicCategory(String category, long count, String key, String name, String icon, int sortOrder) {
    }

    public record AdminCategory(Long id, String key, String nameTr, String nameEn, String nameAr, String icon,
                                int sortOrder, boolean active, long usageCount, Instant createdAt, Instant updatedAt) {
    }

    public record AdminList(List<AdminCategory> items, long activeCount, int maxActive) {
    }

    /** POST/PUT govdesi. key yalnizca olusturmada kullanilir (bos = ad(tr)'den uretilir); sonradan degismez. */
    public record SaveRequest(
            @Size(max = 40) String key,
            @NotBlank @Size(max = 80) String nameTr,
            @Size(max = 80) String nameEn,
            @Size(max = 80) String nameAr,
            @Size(max = 40) String icon,
            Boolean active) {
    }

    public record ActiveRequest(@NotNull Boolean active) {
    }

    public record OrderRequest(@NotEmpty @Size(max = 200) List<@NotNull Long> ids) {
    }
}
