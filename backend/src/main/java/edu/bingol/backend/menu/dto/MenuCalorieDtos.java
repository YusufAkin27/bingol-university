package edu.bingol.backend.menu.dto;

import java.util.List;

/** Yonetici kalori uclarinin istek/yanit govdeleri. */
public final class MenuCalorieDtos {

    private MenuCalorieDtos() {}

    /** Bir yemek icin kalori; kcal null/yok = kaloriyi sil. */
    public record Entry(String name, Integer kcal) {}

    /** PUT /api/admin/menu/{date}/calories. */
    public record DayRequest(List<Entry> items) {}

    /** PUT /api/admin/menu/calories (toplu). */
    public record BulkRequest(List<BulkDay> days) {}

    public record BulkDay(String date, List<Entry> items) {}

    /** Toplu uc: uygulanamayan satir sebebiyle listelenir (istek yine de kismen uygulanir). */
    public record Skipped(String date, String name, String reason) {}

    /** reason: DAY_NOT_FOUND | ITEM_NOT_FOUND | NAME_INVALID. */
    public record BulkResult(int updated, int cleared, int unchanged, List<Skipped> skipped) {}
}
