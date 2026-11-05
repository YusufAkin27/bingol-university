package edu.bingol.backend.forum.category;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.forum.category.ForumCategoryDtos.AdminCategoryView;
import edu.bingol.backend.forum.category.ForumCategoryDtos.CategoryInput;
import edu.bingol.backend.forum.category.ForumCategoryDtos.CategoryView;
import edu.bingol.backend.forum.topic.ForumTopicRepository;
import edu.bingol.backend.i18n.Lang;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Forum kategorileri. Herkese acik liste yalniz aktif kategorileri, konu sayaciyla verir; yonetim islemleri
 * (liste/olustur/guncelle/arsivle/sirala) D'nin yonetici ucunca cagrilir (yetki oradadir: forum.categories).
 * Arsivli kategoriye yeni konu acilamaz ({@link #requireOpen}); eski konular yerinde kalir.
 */
@Service
public class ForumCategoryService {

    /** Kategori sayisi icin kati ust sinir (okuma sinirlidir; yonetici birkac satir tanimlar). */
    static final int MAX_CATEGORIES = 200;
    private static final Pattern SLUG = Pattern.compile("[a-z0-9]+(-[a-z0-9]+)*");

    private final ForumCategoryRepository categories;
    private final ForumTopicRepository topics;

    public ForumCategoryService(ForumCategoryRepository categories, ForumTopicRepository topics) {
        this.categories = categories;
        this.topics = topics;
    }

    // ------------------------------------------------------------------ kullanici

    @Transactional(readOnly = true)
    public List<CategoryView> publicList() {
        Lang lang = Lang.of(LocaleContextHolder.getLocale());
        Map<Long, Long> counts = counts();
        List<CategoryView> out = new ArrayList<>();
        for (ForumCategory c : categories.activeOrdered(PageRequest.of(0, MAX_CATEGORIES))) {
            out.add(new CategoryView(c.getId(), c.getSlug(), nameOf(c, lang), c.getSortOrder(),
                    counts.getOrDefault(c.getId(), 0L)));
        }
        return out;
    }

    /** Adi istek diline gore (bos ise Turkce). */
    public static String nameOf(ForumCategory c, Lang lang) {
        String n = switch (lang) {
            case EN -> c.getNameEn();
            case AR -> c.getNameAr();
            default -> c.getNameTr();
        };
        return n == null || n.isBlank() ? c.getNameTr() : n;
    }

    /** Konu acarken/tasirken: kategori var ve arsivli degil; aksi 404 / 409. */
    @Transactional(readOnly = true)
    public ForumCategory requireOpen(Long categoryId) {
        ForumCategory c = categoryId == null ? null : categories.findById(categoryId).orElse(null);
        if (c == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "FORUM_CATEGORY_NOT_FOUND", "Kategori bulunamadı.");
        }
        if (!c.isActive()) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_CATEGORY_ARCHIVED", "Bu kategoriye yeni konu açılamaz.");
        }
        return c;
    }

    /** Verilen kimliklerin kategorileri (arsivliler dahil; mevcut konularin etiketi icin). */
    @Transactional(readOnly = true)
    public Map<Long, ForumCategory> byIds(java.util.Collection<Long> ids) {
        Map<Long, ForumCategory> out = new HashMap<>();
        if (ids == null || ids.isEmpty()) {
            return out;
        }
        for (ForumCategory c : categories.findAllById(ids)) {
            out.put(c.getId(), c);
        }
        return out;
    }

    // ------------------------------------------------------------------ yonetim (D cagirir)

    @Transactional(readOnly = true)
    public List<AdminCategoryView> adminList() {
        Map<Long, Long> counts = counts();
        List<AdminCategoryView> out = new ArrayList<>();
        for (ForumCategory c : categories.allOrdered(PageRequest.of(0, MAX_CATEGORIES))) {
            out.add(adminView(c, counts.getOrDefault(c.getId(), 0L)));
        }
        return out;
    }

    @Transactional
    public AdminCategoryView create(CategoryInput in) {
        String tr = requireName(in == null ? null : in.nameTr());
        String en = requireName(in.nameEn());
        String ar = requireName(in.nameAr());
        if (categories.count() >= MAX_CATEGORIES) {
            throw invalid();
        }
        String slug;
        if (in.slug() != null && !in.slug().isBlank()) {
            slug = normalizeSlug(in.slug());
            if (categories.existsBySlug(slug)) {
                throw slugTaken();
            }
        } else {
            slug = uniqueSlug(Texts.slugify(tr));
        }
        ForumCategory c = new ForumCategory();
        c.setSlug(slug);
        c.setNameTr(tr);
        c.setNameEn(en);
        c.setNameAr(ar);
        c.setSortOrder(in.sortOrder() != null ? in.sortOrder() : categories.maxSortOrder() + 10);
        c.setActive(in.active() == null || in.active());
        return adminView(categories.save(c), 0L);
    }

    @Transactional
    public AdminCategoryView update(Long id, CategoryInput in) {
        ForumCategory c = categories.findById(id).orElseThrow(ForumCategoryService::notFound);
        if (in != null) {
            if (in.nameTr() != null) {
                c.setNameTr(requireName(in.nameTr()));
            }
            if (in.nameEn() != null) {
                c.setNameEn(requireName(in.nameEn()));
            }
            if (in.nameAr() != null) {
                c.setNameAr(requireName(in.nameAr()));
            }
            if (in.slug() != null && !in.slug().isBlank()) {
                String slug = normalizeSlug(in.slug());
                if (!slug.equals(c.getSlug())) {
                    if (categories.existsBySlugAndIdNot(slug, id)) {
                        throw slugTaken();
                    }
                    c.setSlug(slug);
                }
            }
            if (in.sortOrder() != null) {
                c.setSortOrder(in.sortOrder());
            }
            if (in.active() != null) {
                c.setActive(in.active());
            }
        }
        categories.save(c);
        return adminView(c, counts().getOrDefault(id, 0L));
    }

    /** Arsivle (active=false): silinmez; eski konular yerinde kalir, yeni konu acilamaz. Idempotent. */
    @Transactional
    public AdminCategoryView archive(Long id) {
        ForumCategory c = categories.findById(id).orElseThrow(ForumCategoryService::notFound);
        c.setActive(false);
        categories.save(c);
        return adminView(c, counts().getOrDefault(id, 0L));
    }

    /** Verilen siraya gore sort_order yeniden yazilir; listede olmayanlar mevcut sirayla sona gider. */
    @Transactional
    public List<AdminCategoryView> reorder(List<Long> ids) {
        List<ForumCategory> all = categories.allOrdered(PageRequest.of(0, MAX_CATEGORIES));
        Map<Long, ForumCategory> byId = new LinkedHashMap<>();
        all.forEach(c -> byId.put(c.getId(), c));
        List<ForumCategory> ordered = new ArrayList<>();
        if (ids != null) {
            for (Long id : ids) {
                ForumCategory c = byId.remove(id);
                if (c == null) {
                    if (!ordered.stream().anyMatch(o -> o.getId().equals(id))) {
                        throw notFound(); // listede olmayan kimlik
                    }
                    continue; // tekrar eden kimlik: ilki gecerli
                }
                ordered.add(c);
            }
        }
        ordered.addAll(byId.values());
        int order = 10;
        for (ForumCategory c : ordered) {
            c.setSortOrder(order);
            order += 10;
        }
        categories.saveAll(ordered);
        return adminList();
    }

    // ------------------------------------------------------------------ yardimcilar

    private Map<Long, Long> counts() {
        Map<Long, Long> m = new HashMap<>();
        for (Object[] r : topics.countsByCategory()) {
            m.put(((Number) r[0]).longValue(), ((Number) r[1]).longValue());
        }
        return m;
    }

    private static AdminCategoryView adminView(ForumCategory c, long topicCount) {
        return new AdminCategoryView(c.getId(), c.getSlug(), c.getNameTr(), c.getNameEn(), c.getNameAr(),
                c.getSortOrder(), c.isActive(), topicCount);
    }

    private String uniqueSlug(String base) {
        String slug = base.length() > 56 ? base.substring(0, 56).replaceAll("-+$", "") : base;
        if (!categories.existsBySlug(slug)) {
            return slug;
        }
        for (int i = 2; i < 1000; i++) {
            String cand = slug + "-" + i;
            if (!categories.existsBySlug(cand)) {
                return cand;
            }
        }
        throw slugTaken();
    }

    private static String normalizeSlug(String s) {
        String slug = s.trim().toLowerCase(Locale.ROOT);
        if (slug.length() > 60 || !SLUG.matcher(slug).matches()) {
            throw invalid();
        }
        return slug;
    }

    private static String requireName(String s) {
        String n = s == null ? "" : s.strip();
        if (n.isEmpty() || n.length() > 80 || edu.bingol.backend.profile.naming.DisplayNamePolicy.hasInvisible(n)) {
            throw invalid();
        }
        return n;
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "FORUM_CATEGORY_INVALID", "Kategori bilgileri geçersiz.");
    }

    private static ApiException slugTaken() {
        return new ApiException(HttpStatus.CONFLICT, "FORUM_CATEGORY_SLUG_TAKEN", "Bu kategori adresi zaten kullanılıyor.");
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_CATEGORY_NOT_FOUND", "Kategori bulunamadı.");
    }
}
