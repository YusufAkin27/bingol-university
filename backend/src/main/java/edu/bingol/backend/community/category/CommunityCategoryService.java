package edu.bingol.backend.community.category;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.Texts;
import edu.bingol.backend.community.category.CommunityCategoryDtos.AdminCategory;
import edu.bingol.backend.community.category.CommunityCategoryDtos.AdminList;
import edu.bingol.backend.community.category.CommunityCategoryDtos.PublicCategory;
import edu.bingol.backend.community.category.CommunityCategoryDtos.SaveRequest;
import edu.bingol.backend.i18n.Lang;
import java.time.Instant;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Kulup kategorileri: herkese acik liste, yonetici CRUD + siralama, kulup yazma yolunda dogrulama. */
@Service
public class CommunityCategoryService {

    private static final Pattern KEY = Pattern.compile("^[a-z0-9][a-z0-9-]{0,39}$");

    private final CommunityCategoryRepository repo;
    private final CommunityRepository communities;

    /** En cok kac AKTIF kategori olabilir (pasifler sayilmaz). */
    @Value("${app.community.max-categories:20}")
    private int maxActive = 20;

    public CommunityCategoryService(CommunityCategoryRepository repo, CommunityRepository communities) {
        this.repo = repo;
        this.communities = communities;
    }

    void setMaxActive(int v) { // testler icin
        this.maxActive = v;
    }

    // ---- herkese acik ----

    /** Yalniz aktifler, sira + id; ad istek dilinde (en/ar bossa tr). Sayi: kesfette gorunen kulup. */
    @Transactional(readOnly = true)
    public List<PublicCategory> listActive() {
        Lang lang = Lang.of(LocaleContextHolder.getLocale());
        Map<String, Long> counts = new HashMap<>();
        for (Object[] r : communities.categoryCounts(Community.Status.ACTIVE, Community.Visibility.PUBLIC)) {
            counts.put((String) r[0], ((Number) r[1]).longValue());
        }
        return repo.findByActiveTrueOrderBySortOrderAscIdAsc().stream()
                .map(c -> new PublicCategory(c.getKey(), counts.getOrDefault(c.getKey(), 0L), c.getKey(),
                        name(c, lang), c.getIcon(), c.getSortOrder()))
                .toList();
    }

    /** Degisince degisen basit surum: en yeni guncelleme + toplam satir. */
    @Transactional(readOnly = true)
    public String version() {
        long max = repo.findAll().stream().mapToLong(c -> c.getUpdatedAt().toEpochMilli()).max().orElse(0L);
        return max + "-" + repo.count();
    }

    private static String name(CommunityCategory c, Lang lang) {
        String n = switch (lang) {
            case EN -> c.getNameEn();
            case AR -> c.getNameAr();
            default -> c.getNameTr();
        };
        return n == null || n.isBlank() ? c.getNameTr() : n;
    }

    // ---- kulup yazma yolu ----

    /**
     * Kulup olusturma/guncellemede kategori: bos = null (kategorisiz); degismediyse (current ile ayni) oldugu gibi
     * kalir (pasif kategori mevcut kulupte korunur); aksi halde var ve AKTIF olmali, kanonik key doner.
     */
    @Transactional(readOnly = true)
    public String resolveForWrite(String raw, String current) {
        String v = Texts.blankToNull(raw);
        if (v == null) {
            return null;
        }
        if (v.equals(current)) {
            return v;
        }
        CommunityCategory c = repo.findByKey(v).orElseGet(() -> repo.findAll().stream()
                .filter(x -> x.getKey().equalsIgnoreCase(v)).findFirst().orElse(null));
        if (c == null || !c.isActive()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "COMMUNITY_CATEGORY_INVALID",
                    "Geçersiz veya pasif kulüp kategorisi.");
        }
        return c.getKey();
    }

    // ---- yonetici ----

    @Transactional(readOnly = true)
    public AdminList adminList() {
        Map<String, Long> usage = usage();
        List<AdminCategory> items = repo.findAllByOrderBySortOrderAscIdAsc().stream()
                .map(c -> view(c, usage.getOrDefault(c.getKey(), 0L))).toList();
        return new AdminList(items, items.stream().filter(AdminCategory::active).count(), maxActive);
    }

    @Transactional
    public AdminCategory create(SaveRequest r) {
        String nameTr = r.nameTr().trim();
        String key = r.key() == null || r.key().isBlank() ? generateKey(nameTr) : r.key().trim();
        if (!KEY.matcher(key).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                    "Anahtar yalnızca küçük harf, rakam ve tire içerebilir.");
        }
        if (repo.existsByKey(key)) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_CATEGORY_KEY_TAKEN", "Bu anahtar zaten kullanımda.");
        }
        boolean active = r.active() == null || r.active();
        if (active) {
            requireRoom();
        }
        CommunityCategory c = new CommunityCategory();
        c.setKey(key);
        apply(c, r);
        c.setActive(active);
        c.setSortOrder(repo.maxSortOrder() + 10);
        repo.saveAndFlush(c);
        return view(c, 0L);
    }

    @Transactional
    public AdminCategory update(Long id, SaveRequest r) {
        CommunityCategory c = load(id);
        apply(c, r);
        if (r.active() != null && r.active() != c.isActive()) {
            if (r.active()) {
                requireRoom();
            }
            c.setActive(r.active());
        }
        c.setUpdatedAt(Instant.now());
        repo.save(c);
        return view(c, repo.usage(c.getKey()));
    }

    @Transactional
    public AdminCategory setActive(Long id, boolean active) {
        CommunityCategory c = load(id);
        if (c.isActive() != active) {
            if (active) {
                requireRoom();
            }
            c.setActive(active);
            c.setUpdatedAt(Instant.now());
            repo.save(c);
        }
        return view(c, repo.usage(c.getKey()));
    }

    /** Kullanimda olan silinemez (pasife alinmali); kullanimda olmayan silinir. */
    @Transactional
    public void delete(Long id) {
        CommunityCategory c = load(id);
        long used = repo.usage(c.getKey());
        if (used > 0) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_CATEGORY_IN_USE",
                    "Kategori " + used + " kulüpte kullanıldığı için silinemez; pasife alabilirsiniz.",
                    String.valueOf(used));
        }
        repo.delete(c);
    }

    /** ids: tum kategorilerin istenen sirasi (eksiksiz ve tekrarsiz olmali). */
    @Transactional
    public AdminList reorder(List<Long> ids) {
        List<CommunityCategory> all = repo.findAllByOrderBySortOrderAscIdAsc();
        Set<Long> have = new HashSet<>();
        all.forEach(c -> have.add(c.getId()));
        if (ids.size() != have.size() || !have.equals(new HashSet<>(ids))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "COMMUNITY_CATEGORY_ORDER_INVALID",
                    "Sıralama tüm kategorileri tekrarsız içermelidir.");
        }
        Map<Long, CommunityCategory> byId = new HashMap<>();
        all.forEach(c -> byId.put(c.getId(), c));
        Instant now = Instant.now();
        int pos = 10;
        for (Long id : ids) {
            CommunityCategory c = byId.get(id);
            if (c.getSortOrder() != pos) {
                c.setSortOrder(pos);
                c.setUpdatedAt(now);
            }
            pos += 10;
        }
        repo.saveAll(all);
        return adminList();
    }

    // ---- ic yardimcilar ----

    private CommunityCategory load(Long id) {
        return repo.findById(id).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                "COMMUNITY_CATEGORY_NOT_FOUND", "Kategori bulunamadı."));
    }

    /** Aktif sayisi sinira ulastiysa 409; aktif satirlar kilitlenerek es zamanli eklemeler sirayla sayilir. */
    private void requireRoom() {
        if (repo.lockActive().size() >= maxActive) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_CATEGORY_LIMIT",
                    "En fazla " + maxActive + " aktif kategori olabilir.", String.valueOf(maxActive));
        }
    }

    private String generateKey(String nameTr) {
        String k = Texts.slugify(nameTr);
        if (k.length() > 40) {
            k = k.substring(0, 40).replaceAll("-+$", "");
        }
        return k.isEmpty() ? "kategori" : k;
    }

    private static void apply(CommunityCategory c, SaveRequest r) {
        String tr = r.nameTr().trim();
        c.setNameTr(tr);
        c.setNameEn(r.nameEn() == null || r.nameEn().isBlank() ? tr : r.nameEn().trim());
        c.setNameAr(r.nameAr() == null || r.nameAr().isBlank() ? tr : r.nameAr().trim());
        c.setIcon(Texts.blankToNull(r.icon()));
    }

    private Map<String, Long> usage() {
        Map<String, Long> m = new HashMap<>();
        for (Object[] r : repo.usageCounts()) {
            m.put((String) r[0], ((Number) r[1]).longValue());
        }
        return m;
    }

    private static AdminCategory view(CommunityCategory c, long usage) {
        return new AdminCategory(c.getId(), c.getKey(), c.getNameTr(), c.getNameEn(), c.getNameAr(), c.getIcon(),
                c.getSortOrder(), c.isActive(), usage, c.getCreatedAt(), c.getUpdatedAt());
    }
}
