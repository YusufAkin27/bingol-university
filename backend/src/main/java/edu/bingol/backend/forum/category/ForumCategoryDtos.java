package edu.bingol.backend.forum.category;

/** Forum kategori DTO'lari (entity API'ye donmez). */
public final class ForumCategoryDtos {

    private ForumCategoryDtos() {}

    /**
     * Herkese acik liste ogesi: {@code name}/{@code groupName} istek diline gore. {@code groupKey} bos olabilir
     * (grupsuz); {@code groupOrder} grup bolumlerinin sirasidir (grupsuz = en sona).
     */
    public record CategoryView(Long id, String slug, String name, int sortOrder, long topicCount, String groupKey,
                               String groupName, int groupOrder) {

        /** Grupsuz gorunum (eski cagrilar/testler). */
        public CategoryView(Long id, String slug, String name, int sortOrder, long topicCount) {
            this(id, slug, name, sortOrder, topicCount, null, null, Integer.MAX_VALUE);
        }
    }

    /** Yonetici gorunumu: uc dilin adi, durum, konu sayisi ve grup anahtari. */
    public record AdminCategoryView(Long id, String slug, String nameTr, String nameEn, String nameAr, int sortOrder,
                                    boolean active, long topicCount, String groupKey) {}

    /**
     * Yonetici girdisi. Olusturmada {@code nameTr/nameEn/nameAr} zorunludur ({@code slug} bossa Turkce addan
     * uretilir). Guncellemede (PATCH) null alanlar degismez. {@code groupKey}: mevcut bir grup anahtari; PATCH'te
     * bos metin grubu kaldirir.
     */
    public record CategoryInput(String slug, String nameTr, String nameEn, String nameAr, Integer sortOrder,
                                Boolean active, String groupKey) {

        public CategoryInput(String slug, String nameTr, String nameEn, String nameAr, Integer sortOrder,
                             Boolean active) {
            this(slug, nameTr, nameEn, nameAr, sortOrder, active, null);
        }
    }
}
