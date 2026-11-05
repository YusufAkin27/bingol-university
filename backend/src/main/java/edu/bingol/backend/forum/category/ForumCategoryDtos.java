package edu.bingol.backend.forum.category;

/** Forum kategori DTO'lari (entity API'ye donmez). */
public final class ForumCategoryDtos {

    private ForumCategoryDtos() {}

    /** Herkese acik liste ogesi: {@code name} istek diline gore. */
    public record CategoryView(Long id, String slug, String name, int sortOrder, long topicCount) {}

    /** Yonetici gorunumu: uc dilin adi, durum ve konu sayisi. */
    public record AdminCategoryView(Long id, String slug, String nameTr, String nameEn, String nameAr, int sortOrder,
                                    boolean active, long topicCount) {}

    /**
     * Yonetici girdisi. Olusturmada {@code nameTr/nameEn/nameAr} zorunludur ({@code slug} bossa Turkce addan
     * uretilir). Guncellemede (PATCH) null alanlar degismez.
     */
    public record CategoryInput(String slug, String nameTr, String nameEn, String nameAr, Integer sortOrder,
                                Boolean active) {}
}
