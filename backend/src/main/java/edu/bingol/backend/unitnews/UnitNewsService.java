package edu.bingol.backend.unitnews;

import edu.bingol.backend.academic.AudienceKey;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.unitnews.UnitNewsDtos.Detail;
import edu.bingol.backend.unitnews.UnitNewsDtos.Item;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;

/**
 * Ogrencinin bolumune gore birim duyurulari. Eslesme: profildeki bolum adi ({@link UnitKeys#deptKey}) ile alt sitelerin
 * bolum/program adlari; profilde fakulte varsa isabet edilen kaynak o fakulteye hizmet etmelidir ({@code faculty_keys};
 * tek isabet de dogrulanir), birden cok sitede ayni ad varsa fakulte ayirir, ayrilamazsa/uyusmazsa HICBIR sey
 * gosterilmez. Bolumun kendi akisi varsa o + kaynagin genel akisi, yoksa yalniz genel akis. Yuksek lisans/doktora
 * ({@code MASTER/PHD}) kullanicilarina fakultesine hizmet eden enstituler de eklenir. Eslesme yoksa bos liste:
 * istemci hicbir sey cizmez.
 */
@Service
@Transactional(readOnly = true)
public class UnitNewsService {

    static final int MAX_LIMIT = 20;
    /** Liste sutunlari: govde (body, 8000 karaktere kadar) YOK; yalniz detay okur (P07-B6). */
    private static final String COLS = "a.id, a.title, a.summary, a.published_date, a.url, a.attachments, "
            + "a.dept_slug, a.source_code, s.name AS source_name";
    private static final String DETAIL_COLS = COLS + ", a.body";
    private static final TypeReference<List<Target>> TARGETS = new TypeReference<>() { };

    /** Bir kaynak + (varsa) bolum akisi. unitName bolum akisi kayitlari icin gosterilen ad. */
    public record Target(String sourceCode, String deptSlug, String unitName) {}

    private final JdbcTemplate jdbc;
    private final UserRepository users;
    private final UnitSourceRepository sources;
    private final UnitDepartmentRepository depts;
    private final UnitAttachmentsJson json = new UnitAttachmentsJson();
    private CacheService cache = CacheService.passthrough();

    public UnitNewsService(JdbcTemplate jdbc, UserRepository users, UnitSourceRepository sources,
                           UnitDepartmentRepository depts) {
        this.jdbc = jdbc;
        this.users = users;
        this.sources = sources;
        this.depts = depts;
    }

    /**
     * Hedef eslesmesi yalniz (bolum, fakulte, lisansustu mu) uclusune baglidir, kullaniciya degil: sunucu onbellegi
     * `unitnews` ad alani; kaynak/bolum varliklari degisince (UnitSource, UnitDepartment olaylari) gecersiz kilinir.
     */
    @Autowired(required = false)
    void setCache(CacheService cache) {
        this.cache = cache;
    }

    public List<Item> feed(Long userId, int limit) {
        List<Target> targets = resolve(userId);
        if (targets.isEmpty()) {
            return List.of();
        }
        Map<String, String> unitNames = unitNames(targets);
        List<Object> args = new ArrayList<>();
        String where = where(targets, args);
        args.add(Math.max(1, Math.min(limit, MAX_LIMIT)));
        return jdbc.query("SELECT " + COLS + " FROM unit_announcement a JOIN unit_source s ON s.code = a.source_code "
                + "WHERE a.hidden = FALSE AND s.enabled = TRUE AND (" + where + ") "
                + "ORDER BY a.published_date DESC, a.id DESC LIMIT ?", (rs, i) -> item(rs, unitNames), args.toArray());
    }

    public Detail detail(Long userId, long id) {
        List<Target> targets = resolve(userId);
        if (!targets.isEmpty()) {
            Map<String, String> unitNames = unitNames(targets);
            List<Object> args = new ArrayList<>();
            String where = where(targets, args);
            args.add(id);
            List<Detail> rows = jdbc.query("SELECT " + DETAIL_COLS + " FROM unit_announcement a JOIN unit_source s "
                    + "ON s.code = a.source_code WHERE a.hidden = FALSE AND s.enabled = TRUE AND (" + where
                    + ") AND a.id = ?", (rs, i) -> detail(rs, unitNames), args.toArray());
            if (!rows.isEmpty()) {
                return rows.get(0);
            }
        }
        throw new ApiException(HttpStatus.NOT_FOUND, "UNIT_NEWS_NOT_FOUND", "Duyuru bulunamadı.");
    }

    // ---- eslesme ----

    List<Target> resolve(Long userId) {
        User u = users.findById(userId).orElse(null);
        if (u == null) {
            return List.of();
        }
        String dkey = UnitKeys.deptKey(u.getDepartment());
        String fkey = AudienceKey.of(u.getFaculty());
        boolean graduate = isGraduate(u.getGrade());
        if (dkey == null && !(fkey != null && graduate)) {
            return List.of(); // eslesme anahtari yok: DB'ye gitmeye gerek yok
        }
        String key = "r:" + Hashing.sha256(dkey + "|" + fkey + "|" + graduate);
        return cache.get("unitnews", key, CacheTier.STABLE, TARGETS, () -> compute(dkey, fkey, graduate));
    }

    private List<Target> compute(String dkey, String fkey, boolean graduate) {
        List<Target> out = new ArrayList<>();
        Map<String, UnitSource> byCode = sources.findByEnabledTrueOrderByCodeAsc().stream()
                .collect(Collectors.toMap(UnitSource::getCode, Function.identity(), (a, b) -> a, LinkedHashMap::new));
        if (dkey != null) {
            List<UnitDepartment> hits = depts.findByNameKeyIn(List.of(dkey)).stream()
                    .filter(d -> byCode.containsKey(d.getSourceCode()) && !byCode.get(d.getSourceCode()).isGraduate())
                    .toList();
            Set<String> codes = hits.stream().map(UnitDepartment::getSourceCode).collect(Collectors.toSet());
            // Fakulte biliniyorsa TEK isabet de dogrulanir (A1): "Hemsirelik" hem Saglik Bilimleri Fakultesi'nde hem
            // Hemsirelik Yuksekokulu'nda gecer; yanlis birimin duyurusu yerine bos doner. Fakulte bilinmiyorsa
            // yalniz tek isabet kabul edilir (asagida).
            if (fkey != null) {
                codes = codes.stream().filter(c -> serves(byCode.get(c), fkey)).collect(Collectors.toSet());
            }
            if (codes.size() == 1) {
                String code = codes.iterator().next();
                out.add(new Target(code, null, null));
                for (UnitDepartment d : hits) {
                    if (d.getSourceCode().equals(code) && d.getFeedPath() != null) {
                        out.add(new Target(code, d.getSlug(), d.getName()));
                    }
                }
            }
        }
        // lisansustu: fakultesine hizmet eden enstituler (bolum eslesmesi olmasa da)
        if (fkey != null && graduate) {
            for (UnitSource s : byCode.values()) {
                if (s.isGraduate() && serves(s, fkey)) {
                    out.add(new Target(s.getCode(), null, null));
                }
            }
        }
        return out;
    }

    private static boolean isGraduate(String grade) {
        return "MASTER".equalsIgnoreCase(grade) || "PHD".equalsIgnoreCase(grade);
    }

    static boolean serves(UnitSource s, String facultyKey) {
        if (s == null || facultyKey == null) {
            return false;
        }
        for (String k : s.getFacultyKeys().split(",")) {
            if (facultyKey.equals(k.strip())) {
                return true;
            }
        }
        return false;
    }

    private Map<String, String> unitNames(List<Target> targets) {
        Map<String, String> m = new HashMap<>();
        for (Target t : targets) {
            if (t.deptSlug() != null) {
                m.put(t.sourceCode() + "/" + t.deptSlug(), t.unitName());
            }
        }
        return m;
    }

    /** Hedeflerin OR kosulu; her kaynak icin genel akis (dept_slug IS NULL) + varsa bolum akislari. */
    private static String where(List<Target> targets, List<Object> args) {
        Map<String, List<String>> bySource = new LinkedHashMap<>();
        for (Target t : targets) {
            List<String> slugs = bySource.computeIfAbsent(t.sourceCode(), k -> new ArrayList<>());
            if (t.deptSlug() != null) {
                slugs.add(t.deptSlug());
            }
        }
        List<String> parts = new ArrayList<>();
        for (Map.Entry<String, List<String>> e : bySource.entrySet()) {
            StringBuilder sb = new StringBuilder("(a.source_code = ? AND (a.dept_slug IS NULL");
            args.add(e.getKey());
            if (!e.getValue().isEmpty()) {
                sb.append(" OR a.dept_slug IN (")
                        .append(String.join(",", java.util.Collections.nCopies(e.getValue().size(), "?"))).append(")");
                args.addAll(e.getValue());
            }
            parts.add(sb.append("))").toString());
        }
        return String.join(" OR ", parts);
    }

    // ---- satir esleme ----

    private Item item(ResultSet rs, Map<String, String> unitNames) throws SQLException {
        return new Item(rs.getLong("id"), rs.getString("title"), rs.getString("summary"),
                rs.getDate("published_date").toLocalDate().toString(), rs.getString("source_name"),
                unitName(rs, unitNames), rs.getString("url"), json.read(rs.getString("attachments")));
    }

    private Detail detail(ResultSet rs, Map<String, String> unitNames) throws SQLException {
        String body = rs.getString("body");
        return new Detail(rs.getLong("id"), rs.getString("title"), rs.getString("summary"),
                rs.getDate("published_date").toLocalDate().toString(), rs.getString("source_name"),
                unitName(rs, unitNames), rs.getString("url"), json.read(rs.getString("attachments")),
                body == null ? "" : body);
    }

    private static String unitName(ResultSet rs, Map<String, String> unitNames) throws SQLException {
        String slug = rs.getString("dept_slug");
        return slug == null ? null : unitNames.get(rs.getString("source_code") + "/" + slug);
    }
}
