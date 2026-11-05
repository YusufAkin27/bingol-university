package edu.bingol.backend.forum.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.moderation.spi.ForumTextSanitizer;
import java.sql.Timestamp;
import java.text.Normalizer;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Forum kategori yonetimi (yonetim paneli, izin forum.categories). {@code forum_category} tablosuna (A, V1400) duz SQL ile
 * yazar; kategori SILINMEZ, DELETE = arsivle ({@code active=false}). A'nin kullanici listesi yalniz aktif kategorileri
 * gosterir. Konular arsivlenen kategoride kalir. Son aktif kategori arsivlenemez (konu acilacak yer kalmaz).
 */
@Service
public class ForumAdminCategoryService {

    public record CategoryView(Long id, String slug, String nameTr, String nameEn, String nameAr, int sortOrder,
                               boolean active, long topicCount) {}

    /** Alan null = degistirme. */
    public record CategoryInput(String slug, String nameTr, String nameEn, String nameAr, Boolean active, Integer sortOrder) {}

    private static final Pattern SLUG = Pattern.compile("[a-z0-9]+(-[a-z0-9]+)*");
    private static final int MAX_NAME = 80;
    private static final int MAX_SLUG = 60;

    private static final String SELECT = "SELECT c.id, c.slug, c.name_tr, c.name_en, c.name_ar, c.sort_order, c.active, "
            + "(SELECT COUNT(*) FROM forum_topic t WHERE t.category_id = c.id AND t.deleted_at IS NULL AND t.status = 'ACTIVE') "
            + "AS topic_count FROM forum_category c";

    private final JdbcTemplate jdbc;

    public ForumAdminCategoryService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Transactional(readOnly = true)
    public List<CategoryView> list() {
        return jdbc.query(SELECT + " ORDER BY c.sort_order, c.id LIMIT 200", (rs, i) -> view(rs));
    }

    @Transactional(readOnly = true)
    public CategoryView get(Long id) {
        List<CategoryView> r = jdbc.query(SELECT + " WHERE c.id = ?", (rs, i) -> view(rs), id);
        if (r.isEmpty()) {
            throw notFound();
        }
        return r.get(0);
    }

    @Transactional
    public CategoryView create(CategoryInput in) {
        String tr = name(in.nameTr());
        String en = name(in.nameEn() == null || in.nameEn().isBlank() ? in.nameTr() : in.nameEn());
        String ar = name(in.nameAr() == null || in.nameAr().isBlank() ? in.nameTr() : in.nameAr());
        String slug = in.slug() == null || in.slug().isBlank() ? uniqueSlug(slugify(tr)) : checkedSlug(in.slug(), null);
        Integer max = jdbc.queryForObject("SELECT COALESCE(MAX(sort_order), 0) FROM forum_category", Integer.class);
        int order = in.sortOrder() != null ? in.sortOrder() : (max == null ? 0 : max) + 10;
        boolean active = in.active() == null || in.active();
        jdbc.update("INSERT INTO forum_category (slug, name_tr, name_en, name_ar, sort_order, active, created_at) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?)", slug, tr, en, ar, order, active, Timestamp.from(Instant.now()));
        Long id = jdbc.queryForObject("SELECT id FROM forum_category WHERE slug = ?", Long.class, slug);
        return get(id);
    }

    @Transactional
    public CategoryView update(Long id, CategoryInput in) {
        CategoryView cur = get(id);
        String tr = in.nameTr() == null ? cur.nameTr() : name(in.nameTr());
        String en = in.nameEn() == null ? cur.nameEn() : name(in.nameEn());
        String ar = in.nameAr() == null ? cur.nameAr() : name(in.nameAr());
        String slug = in.slug() == null || in.slug().isBlank() ? cur.slug() : checkedSlug(in.slug(), id);
        int order = in.sortOrder() == null ? cur.sortOrder() : in.sortOrder();
        boolean active = in.active() == null ? cur.active() : in.active();
        if (cur.active() && !active) {
            assertNotLastActive(id);
        }
        jdbc.update("UPDATE forum_category SET slug = ?, name_tr = ?, name_en = ?, name_ar = ?, sort_order = ?, active = ? "
                + "WHERE id = ?", slug, tr, en, ar, order, active, id);
        return get(id);
    }

    /** DELETE = arsivle. Zaten arsivdeyse sessizce basarili. */
    @Transactional
    public void archive(Long id) {
        CategoryView cur = get(id);
        if (!cur.active()) {
            return;
        }
        assertNotLastActive(id);
        jdbc.update("UPDATE forum_category SET active = FALSE WHERE id = ?", id);
    }

    /** Verilen sira 10, 20, ... olarak yazilir; listede olmayanlar mevcut sirayla sona gider. */
    @Transactional
    public List<CategoryView> reorder(List<Long> ids) {
        if (ids == null || ids.isEmpty() || ids.size() > 200 || new HashSet<>(ids).size() != ids.size()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_CATEGORY_REORDER_INVALID", "Geçersiz kategori sırası.");
        }
        List<Long> all = jdbc.queryForList("SELECT id FROM forum_category ORDER BY sort_order, id LIMIT 200", Long.class);
        Set<Long> known = new HashSet<>(all);
        for (Long id : ids) {
            if (!known.contains(id)) {
                throw notFound();
            }
        }
        List<Long> order = new ArrayList<>(ids);
        all.stream().filter(i -> !ids.contains(i)).forEach(order::add);
        int n = 10;
        for (Long id : order) {
            jdbc.update("UPDATE forum_category SET sort_order = ? WHERE id = ?", n, id);
            n += 10;
        }
        return list();
    }

    // --- yardimcilar ---

    private void assertNotLastActive(Long id) {
        Integer others = jdbc.queryForObject("SELECT COUNT(*) FROM forum_category WHERE active = TRUE AND id <> ?", Integer.class, id);
        if (others == null || others == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_MOD_CATEGORY_LAST_ACTIVE",
                    "Son aktif kategori arşivlenemez.");
        }
    }

    private static String name(String raw) {
        String n = raw == null ? "" : ForumTextSanitizer.singleLine(raw);
        if (n.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_CATEGORY_NAME_REQUIRED", "Kategori adı zorunludur.");
        }
        if (n.length() > MAX_NAME) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_CATEGORY_NAME_REQUIRED", "Kategori adı zorunludur.");
        }
        return n;
    }

    private String checkedSlug(String raw, Long selfId) {
        String s = raw.strip().toLowerCase(Locale.ROOT);
        if (s.length() > MAX_SLUG || !SLUG.matcher(s).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_CATEGORY_SLUG_INVALID", "Geçersiz kategori kısa adı.");
        }
        Integer taken = selfId == null
                ? jdbc.queryForObject("SELECT COUNT(*) FROM forum_category WHERE slug = ?", Integer.class, s)
                : jdbc.queryForObject("SELECT COUNT(*) FROM forum_category WHERE slug = ? AND id <> ?", Integer.class, s, selfId);
        if (taken != null && taken > 0) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_MOD_CATEGORY_SLUG_TAKEN", "Bu kısa ad kullanımda.");
        }
        return s;
    }

    private String uniqueSlug(String base) {
        String b = base.isEmpty() ? "kategori" : base;
        String s = b;
        int i = 2;
        while (true) {
            Integer c = jdbc.queryForObject("SELECT COUNT(*) FROM forum_category WHERE slug = ?", Integer.class, s);
            if (c == null || c == 0) {
                return s;
            }
            String suffix = "-" + i++;
            s = (b.length() + suffix.length() > MAX_SLUG ? b.substring(0, MAX_SLUG - suffix.length()) : b) + suffix;
        }
    }

    /** Turkce harfleri ASCII'ye katlayip kisa ad uretir ("Öneri & Şikâyet" -> "oneri-sikayet"). */
    static String slugify(String name) {
        String s = name.replace('ı', 'i').replace('İ', 'i').replace('ş', 's').replace('Ş', 's').replace('ğ', 'g')
                .replace('Ğ', 'g').replace('ç', 'c').replace('Ç', 'c').replace('ö', 'o').replace('Ö', 'o')
                .replace('ü', 'u').replace('Ü', 'u');
        s = Normalizer.normalize(s, Normalizer.Form.NFD).replaceAll("\\p{M}+", "").toLowerCase(Locale.ROOT);
        s = s.replaceAll("[^a-z0-9]+", "-").replaceAll("^-+|-+$", "");
        return s.length() > MAX_SLUG ? s.substring(0, MAX_SLUG).replaceAll("-+$", "") : s;
    }

    private static CategoryView view(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new CategoryView(rs.getLong("id"), rs.getString("slug"), rs.getString("name_tr"), rs.getString("name_en"),
                rs.getString("name_ar"), rs.getInt("sort_order"), rs.getBoolean("active"), rs.getLong("topic_count"));
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_MOD_CATEGORY_NOT_FOUND", "Kategori bulunamadı.");
    }
}
