package edu.bingol.backend.academic;

import static edu.bingol.backend.academic.AcademicSupport.placeholders;

import edu.bingol.backend.academic.AcademicDtos.Page;
import edu.bingol.backend.academic.OfficialTimetableDtos.AdminProgramsView;
import edu.bingol.backend.academic.OfficialTimetableDtos.EntryView;
import edu.bingol.backend.academic.OfficialTimetableDtos.ImportResult;
import edu.bingol.backend.academic.OfficialTimetableDtos.Issue;
import edu.bingol.backend.academic.OfficialTimetableDtos.OfficialView;
import edu.bingol.backend.academic.OfficialTimetableDtos.ProgramSummary;
import edu.bingol.backend.academic.OfficialTimetableDtos.TermView;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.catalog.CatalogService.DepartmentHit;
import edu.bingol.backend.common.ApiException;
import java.io.IOException;
import java.io.InputStream;
import java.security.MessageDigest;
import java.sql.Time;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Resmi ders programi: yonetici sablon Excel'i (sayfa "Ders Programi") yukler; birim + program bazinda DEGISTIRIR
 * (ayni dosya tekrar yuklenince cift kayit olusmaz). Kullanici profilindeki bolum + sinifa gore okur.
 * Duz SQL (H2 + PostgreSQL uyumlu).
 */
@Service
public class OfficialTimetableService {

    static final String SHEET = "Ders Programı";
    private static final int MAX_ENTRIES = 20_000;
    private static final int MAX_ISSUES = 200;
    private static final int USER_LIMIT = 1500;

    private final JdbcTemplate jdbc;
    private final CatalogService catalog;
    private final AcademicAudience audience;

    public OfficialTimetableService(JdbcTemplate jdbc, CatalogService catalog, AcademicAudience audience) {
        this.jdbc = jdbc;
        this.catalog = catalog;
        this.audience = audience;
    }

    // ---- yukleme ----

    /** Yuklenen satir (dogrulanmis). */
    private record Row(int excelRow, String term, String unit, String program, String grade, String group, int day,
                       LocalTime start, LocalTime end, String code, String name, String instructor, String room,
                       String note, String source, String catFaculty, String catDept) {}

    private record Mapped(String faculty, String department, boolean matched) {}

    /**
     * @param dryRun true: yalniz dogrula ve onizleme dondur (veritabanina yazmaz)
     * @param defaultTerm satirda "Donem" bos ise kullanilir (bos olabilir: o zaman satir hatasi)
     */
    @Transactional
    public ImportResult importXlsx(Long adminId, String fileName, byte[] bytes, String defaultTerm, boolean dryRun) {
        List<List<String>> grid;
        try (InputStream in = new java.io.ByteArrayInputStream(bytes)) {
            grid = XlsxReader.read(in, SHEET);
        } catch (XlsxReader.XlsxException e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "TIMETABLE_FILE_INVALID", "Excel dosyası okunamadı: {0}",
                    e.getMessage());
        } catch (IOException e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "TIMETABLE_FILE_INVALID", "Excel dosyası okunamadı: {0}",
                    "okuma hatası");
        }
        List<Issue> errors = new ArrayList<>();
        List<Issue> warnings = new ArrayList<>();
        List<Row> rows = parse(grid, defaultTerm == null ? "" : defaultTerm.strip(), errors, warnings);
        if (rows.isEmpty() && errors.isEmpty()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "TIMETABLE_FILE_EMPTY", "Dosyada içe aktarılacak ders satırı yok.");
        }
        if (rows.size() > MAX_ENTRIES) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "TIMETABLE_TOO_LARGE", "En fazla {0} ders saati yüklenebilir.",
                    String.valueOf(MAX_ENTRIES));
        }

        // program -> katalog eslemesi (birim+program basina bir kez)
        Map<String, Mapped> mapped = new LinkedHashMap<>();
        Map<String, List<Row>> byProgram = new LinkedHashMap<>();
        for (Row r : rows) {
            String k = r.term + "\u0001" + r.unit + "\u0001" + r.program;
            byProgram.computeIfAbsent(k, x -> new ArrayList<>()).add(r);
            mapped.computeIfAbsent(k, x -> mapCatalog(r, warnings));
        }
        List<ProgramSummary> items = new ArrayList<>();
        for (Map.Entry<String, List<Row>> e : byProgram.entrySet()) {
            Row f = e.getValue().get(0);
            Mapped m = mapped.get(e.getKey());
            TreeSet<String> grades = new TreeSet<>(OfficialTimetableService::compareGrade);
            e.getValue().forEach(x -> grades.add(x.grade));
            items.add(new ProgramSummary(f.unit, f.program, m.department, m.faculty, m.matched, List.copyOf(grades),
                    e.getValue().size(), true));
        }
        String term = rows.isEmpty() ? defaultTerm : rows.get(0).term;
        if (dryRun || !errors.isEmpty()) {
            if (!dryRun) { // yazma isteginde hata varsa hicbir sey yazilmaz
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "TIMETABLE_IMPORT_INVALID",
                        "Dosyada {0} hata var; önce önizlemeyi düzeltin.", String.valueOf(errors.size()));
            }
            return new ImportResult(true, term, rows.size(), items.size(), 0, 0, null, items, cap(errors), cap(warnings));
        }

        long batchId = AcademicSupport.insert(jdbc,
                "INSERT INTO official_timetable_batch (term, file_name, sha256, row_count, program_count, created_by) "
                        + "VALUES (?, ?, ?, ?, ?, ?)",
                term, fileName == null ? null : trim(fileName, 200), sha256(bytes), rows.size(), items.size(), adminId);
        int replaced = 0;
        for (Map.Entry<String, List<Row>> e : byProgram.entrySet()) {
            Row f = e.getValue().get(0);
            replaced += jdbc.update("DELETE FROM official_timetable_entry WHERE term = ? AND unit = ? AND program = ?",
                    f.term, f.unit, f.program) > 0 ? 1 : 0;
        }
        List<Object[]> batch = new ArrayList<>(rows.size());
        for (Row r : rows) {
            Mapped m = mapped.get(r.term + "\u0001" + r.unit + "\u0001" + r.program);
            batch.add(new Object[] {batchId, r.term, r.unit, m.faculty, m.department, r.program, r.grade, r.group, r.day,
                    Time.valueOf(r.start), Time.valueOf(r.end), r.code, r.name, r.instructor, r.room, r.note, r.source});
        }
        jdbc.batchUpdate("INSERT INTO official_timetable_entry (batch_id, term, unit, faculty, department, program, grade, "
                + "grp, day_of_week, start_time, end_time, course_code, course_name, instructor, room, note, source_url) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", batch);
        // bos kalan eski yukleme kayitlarini temizle
        jdbc.update("DELETE FROM official_timetable_batch b WHERE NOT EXISTS "
                + "(SELECT 1 FROM official_timetable_entry e WHERE e.batch_id = b.id) AND b.id <> ?", batchId);
        return new ImportResult(false, term, rows.size(), items.size(), rows.size(), replaced, batchId, items, cap(errors),
                cap(warnings));
    }

    private static List<Issue> cap(List<Issue> l) {
        return l.size() <= MAX_ISSUES ? l : new ArrayList<>(l.subList(0, MAX_ISSUES));
    }

    private static String sha256(byte[] b) {
        try {
            byte[] d = MessageDigest.getInstance("SHA-256").digest(b);
            StringBuilder sb = new StringBuilder();
            for (byte x : d) {
                sb.append(String.format("%02x", x));
            }
            return sb.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            return null;
        }
    }

    /** Excel'de "Katalog Fakulte/Bolum" doluysa ve katalogda varsa o; yoksa program adi katalog bolum adiyla birebir (AudienceKey) eslesirse o. */
    private Mapped mapCatalog(Row r, List<Issue> warnings) {
        if (r.catFaculty != null && r.catDept != null && catalog.isValid(r.catFaculty, r.catDept)) {
            return new Mapped(r.catFaculty, r.catDept, true);
        }
        for (DepartmentHit h : catalog.search(r.program, 30)) {
            if (AudienceKey.same(h.department(), r.program)) {
                return new Mapped(h.faculty(), h.department(), true);
            }
        }
        warnings.add(new Issue(r.excelRow, "Program katalogda bulunamadı, ad olduğu gibi kullanılacak: " + r.program
                + " (kullanıcı profilindeki bölüm adıyla eşleşmeyebilir)."));
        return new Mapped(null, r.program, false);
    }

    // ---- ayristirma ----

    private static final String[][] HEADERS = { // alan, ayirt edici (foldlanmis) on ek/ icerik
        {"catFaculty", "katalog fakulte"}, {"catDept", "katalog bolum"}, {"term", "donem"}, {"unit", "birim"},
        {"program", "bolum"}, {"grade", "sinif"}, {"group", "grup"}, {"group", "sube"}, {"day", "gun"},
        {"start", "baslangic"}, {"end", "bitis"}, {"code", "ders kodu"}, {"name", "ders adi"},
        {"instructor", "ogretim"}, {"room", "derslik"}, {"note", "not"}, {"source", "kaynak"},
    };

    private List<Row> parse(List<List<String>> grid, String defaultTerm, List<Issue> errors, List<Issue> warnings) {
        int headerRow = -1;
        Map<String, Integer> col = new HashMap<>();
        for (int i = 0; i < Math.min(grid.size(), 15) && headerRow < 0; i++) {
            Map<String, Integer> c = new HashMap<>();
            List<String> cells = grid.get(i);
            for (int j = 0; j < cells.size(); j++) {
                String f = fold(cells.get(j));
                if (f.isEmpty()) {
                    continue;
                }
                for (String[] h : HEADERS) {
                    if (!c.containsKey(h[0]) && f.startsWith(h[1])) {
                        c.put(h[0], j);
                        break;
                    }
                }
            }
            if (c.keySet().containsAll(Set.of("unit", "program", "grade", "day", "start", "end", "name"))) {
                headerRow = i;
                col = c;
            }
        }
        if (headerRow < 0) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "TIMETABLE_HEADER_MISSING",
                    "Başlık satırı bulunamadı. Gerekli sütunlar: Birim, Bölüm / Program, Sınıf, Gün, Başlangıç, Bitiş, Ders Adı.");
        }
        List<Row> out = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        for (int i = headerRow + 1; i < grid.size(); i++) {
            List<String> cells = grid.get(i);
            int excelRow = i + 1;
            if (cells.stream().allMatch(s -> s == null || s.isBlank())) {
                continue;
            }
            String unit = text(cells, col.get("unit"), 160);
            String program = text(cells, col.get("program"), 160);
            String name = text(cells, col.get("name"), 200);
            String term = text(cells, col.get("term"), 40);
            if (term.isEmpty()) {
                term = defaultTerm;
            }
            String gradeRaw = text(cells, col.get("grade"), 40);
            String grade = grade(gradeRaw);
            int day = day(text(cells, col.get("day"), 20));
            LocalTime start = time(text(cells, col.get("start"), 20));
            LocalTime end = time(text(cells, col.get("end"), 20));
            List<String> bad = new ArrayList<>();
            if (term.isEmpty()) {
                bad.add("Dönem boş");
            }
            if (unit.isEmpty()) {
                bad.add("Birim boş");
            }
            if (program.isEmpty()) {
                bad.add("Bölüm / Program boş");
            }
            if (name.isEmpty()) {
                bad.add("Ders adı boş");
            }
            if (grade == null) {
                bad.add("Sınıf geçersiz: '" + gradeRaw + "'");
            }
            if (day < 0) {
                bad.add("Gün geçersiz");
            }
            if (start == null) {
                bad.add("Başlangıç saati geçersiz");
            }
            if (end == null) {
                bad.add("Bitiş saati geçersiz");
            }
            if (start != null && end != null && !end.isAfter(start)) {
                bad.add("Bitiş saati başlangıçtan sonra olmalı");
            }
            if (!bad.isEmpty()) {
                errors.add(new Issue(excelRow, String.join("; ", bad)));
                continue;
            }
            String code = text(cells, col.get("code"), 30);
            String group = text(cells, col.get("group"), 40);
            String dedupe = (term + "|" + unit + "|" + program + "|" + grade + "|" + group + "|" + day + "|" + start + "|"
                    + end + "|" + code + "|" + name).toLowerCase(Locale.ROOT);
            if (!seen.add(dedupe)) {
                warnings.add(new Issue(excelRow, "Aynı satır tekrar ediyor, atlandı: " + name));
                continue;
            }
            out.add(new Row(excelRow, term, unit, program, grade, group.isEmpty() ? null : group, day, start, end,
                    code.isEmpty() ? null : code, name, nul(text(cells, col.get("instructor"), 200)),
                    nul(text(cells, col.get("room"), 100)), nul(text(cells, col.get("note"), 300)),
                    nul(trim(text(cells, col.get("source"), 500), 500)),
                    nul(text(cells, col.get("catFaculty"), 160)), nul(text(cells, col.get("catDept"), 160))));
        }
        return out;
    }

    private static String text(List<String> cells, Integer idx, int max) {
        if (idx == null || idx >= cells.size() || cells.get(idx) == null) {
            return "";
        }
        String s = cells.get(idx).replace(' ', ' ').strip().replaceAll("\\s+", " ");
        return s.length() > max ? s.substring(0, max) : s;
    }

    private static String nul(String s) {
        return s == null || s.isEmpty() ? null : s;
    }

    private static String trim(String s, int max) {
        return s == null ? null : s.length() > max ? s.substring(0, max) : s;
    }

    static String fold(String s) {
        return AudienceKey.of(s == null ? "" : s) == null ? "" : AudienceKey.of(s).replaceAll("\\s+", " ");
    }

    /** "1", "1.", "1. Sinif", "I", "II. SINIF", "Hazirlik", "Yuksek Lisans" -> kanonik deger; olmazsa null. */
    static String grade(String raw) {
        String f = fold(raw).replace("sinif", "").replace(".", "").replace("-", " ").trim();
        if (f.isEmpty()) {
            return null;
        }
        return switch (f) {
            case "1", "i" -> "1";
            case "2", "ii" -> "2";
            case "3", "iii" -> "3";
            case "4", "iv" -> "4";
            case "5", "v" -> "5";
            case "6", "vi" -> "6";
            case "haz", "hazirlik", "prep" -> "PREP";
            case "yuksek lisans", "yl", "master" -> "MASTER";
            case "doktora", "phd" -> "PHD";
            default -> null;
        };
    }

    /** Gun adi ya da 1..7; gecersizse -1. */
    static int day(String raw) {
        String f = fold(raw).replaceAll("[^a-z0-9]", "");
        if (f.isEmpty()) {
            return -1;
        }
        if (f.matches("[1-7]")) {
            return Integer.parseInt(f);
        }
        String[][] names = {{"pazartesi", "1"}, {"sali", "2"}, {"carsamba", "3"}, {"persembe", "4"}, {"cumartesi", "6"},
            {"cuma", "5"}, {"pazar", "7"}};
        for (String[] n : names) {
            if (f.startsWith(n[0])) {
                return Integer.parseInt(n[1]);
            }
        }
        return -1;
    }

    /** "08:15", "8.15", "08:15:00" veya Excel zaman kesri ("0.34375"); gecersizse null. */
    static LocalTime time(String raw) {
        String s = raw == null ? "" : raw.strip();
        if (s.isEmpty()) {
            return null;
        }
        try {
            if (s.matches("0\\.\\d+|1(\\.0+)?|0")) { // kesir
                int minutes = (int) Math.round(Double.parseDouble(s) * 24 * 60);
                return minutes >= 24 * 60 ? null : LocalTime.of(minutes / 60, minutes % 60);
            }
            java.util.regex.Matcher m = java.util.regex.Pattern.compile("^(\\d{1,2})[.:](\\d{2})(?:[.:]\\d{2})?$").matcher(s);
            if (m.matches()) {
                return LocalTime.of(Integer.parseInt(m.group(1)), Integer.parseInt(m.group(2)));
            }
        } catch (java.time.DateTimeException | NumberFormatException e) {
            return null;
        }
        return null;
    }

    static int compareGrade(String a, String b) {
        return Integer.compare(gradeOrder(a), gradeOrder(b));
    }

    private static int gradeOrder(String g) {
        return switch (g) {
            case "PREP" -> 0;
            case "MASTER" -> 20;
            case "PHD" -> 21;
            default -> g.length() == 1 && Character.isDigit(g.charAt(0)) ? g.charAt(0) - '0' : 99;
        };
    }

    // ---- yonetici: okuma / silme / yayin ----

    public AdminProgramsView adminPrograms(String term) {
        List<TermView> terms = jdbc.query("SELECT term, COUNT(*) AS n, COUNT(DISTINCT unit || '|' || program) AS p "
                + "FROM official_timetable_entry GROUP BY term ORDER BY term DESC",
                (rs, i) -> new TermView(rs.getString(1), rs.getInt(2), rs.getInt(3)));
        String t = term != null && !term.isBlank() ? term.strip() : terms.isEmpty() ? null : terms.get(0).term();
        if (t == null) {
            return new AdminProgramsView(terms, null, List.of());
        }
        Map<String, Object[]> agg = new LinkedHashMap<>();
        jdbc.query("SELECT unit, program, department, faculty, grade, COUNT(*), MIN(CASE WHEN published THEN 1 ELSE 0 END) "
                + "FROM official_timetable_entry WHERE term = ? GROUP BY unit, program, department, faculty, grade "
                + "ORDER BY unit, program", rs -> {
                    String k = rs.getString(1) + "\u0001" + rs.getString(2);
                    String unit = rs.getString(1), program = rs.getString(2), department = rs.getString(3), faculty = rs.getString(4);
                    Object[] a = agg.computeIfAbsent(k, x -> new Object[] {unit, program, department,
                        faculty, new TreeSet<String>(OfficialTimetableService::compareGrade), 0, true});
                    @SuppressWarnings("unchecked")
                    TreeSet<String> g = (TreeSet<String>) a[4];
                    g.add(rs.getString(5));
                    a[5] = (int) a[5] + rs.getInt(6);
                    a[6] = (boolean) a[6] && rs.getInt(7) == 1;
                }, t);
        List<ProgramSummary> items = new ArrayList<>();
        for (Object[] a : agg.values()) {
            @SuppressWarnings("unchecked")
            TreeSet<String> g = (TreeSet<String>) a[4];
            String faculty = (String) a[3];
            items.add(new ProgramSummary((String) a[0], (String) a[1], (String) a[2], faculty, faculty != null,
                    List.copyOf(g), (int) a[5], (boolean) a[6]));
        }
        return new AdminProgramsView(terms, t, items);
    }

    public Page<EntryView> adminEntries(int page, int size, String term, String unit, String program, String grade) {
        int p = Math.max(page, 0);
        int s = Math.min(Math.max(size, 1), 200);
        StringBuilder where = new StringBuilder("WHERE term = ? AND unit = ? AND program = ? ");
        List<Object> args = new ArrayList<>(List.of(need(term), need(unit), need(program)));
        if (grade != null && !grade.isBlank()) {
            where.append("AND grade = ? ");
            args.add(grade.strip().toUpperCase(Locale.ROOT));
        }
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM official_timetable_entry " + where, Long.class, args.toArray());
        args.add(s);
        args.add((long) p * s);
        List<EntryView> items = jdbc.query(ENTRY_SELECT + where + "ORDER BY grade, day_of_week, start_time, id LIMIT ? OFFSET ?",
                ENTRY, args.toArray());
        return new Page<>(items, p, s, total == null ? 0 : total);
    }

    private static String need(String v) {
        if (v == null || v.isBlank()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "TIMETABLE_PARAM", "{0} zorunlu.", "term/unit/program");
        }
        return v.strip();
    }

    @Transactional
    public int adminDeleteProgram(String term, String unit, String program) {
        int n = jdbc.update("DELETE FROM official_timetable_entry WHERE term = ? AND unit = ? AND program = ?", need(term),
                need(unit), need(program));
        if (n == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "TIMETABLE_NOT_FOUND", "Ders programı kaydı bulunamadı.");
        }
        jdbc.update("DELETE FROM official_timetable_batch b WHERE NOT EXISTS "
                + "(SELECT 1 FROM official_timetable_entry e WHERE e.batch_id = b.id)");
        return n;
    }

    @Transactional
    public int adminPublish(String term, String unit, String program, boolean published) {
        int n = jdbc.update("UPDATE official_timetable_entry SET published = ? WHERE term = ? AND unit = ? AND program = ?",
                published, need(term), need(unit), need(program));
        if (n == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "TIMETABLE_NOT_FOUND", "Ders programı kaydı bulunamadı.");
        }
        return n;
    }

    // ---- kullanici ----

    /**
     * Yayinda olan resmi program. department/grade verilmezse kullanicinin profilinden; grade profilde yoksa tum siniflar.
     * @param unit verilirse yalniz o birim (ayni bolum adi birden cok MYO'da olabilir)
     */
    public OfficialView forUser(Long uid, String term, String department, String grade, String unit) {
        AcademicAudience.Who me = audience.of(uid);
        String dept = department != null && !department.isBlank() ? department : me.department();
        String gr = grade != null && !grade.isBlank() ? grade.strip().toUpperCase(Locale.ROOT) : me.grade();
        String t = term != null && !term.isBlank() ? term.strip() : currentTerm();
        if (t == null || dept == null || dept.isBlank()) {
            return new OfficialView(t, List.of(), List.of(), dept != null && !dept.isBlank());
        }
        List<EntryView> items = query(t, dept, gr, unit);
        Set<String> units = new TreeSet<>();
        items.forEach(x -> units.add(x.unit()));
        return new OfficialView(t, items, List.copyOf(units), true);
    }

    /** Yayindaki satirlar: bolum adi AudienceKey ile eslenir; grade/unit bos degilse suzer. */
    private List<EntryView> query(String term, String dept, String grade, String unit) {
        StringBuilder sql = new StringBuilder(ENTRY_SELECT + "WHERE published = TRUE AND term = ? AND "
                + AudienceKey.sql("department") + " = ? ");
        List<Object> args = new ArrayList<>(List.of(term, AudienceKey.of(dept)));
        if (grade != null && !grade.isBlank()) {
            sql.append("AND grade = ? ");
            args.add(grade);
        }
        if (unit != null && !unit.isBlank()) {
            sql.append("AND unit = ? ");
            args.add(unit.strip());
        }
        sql.append("ORDER BY unit, grade, day_of_week, start_time, id LIMIT ").append(USER_LIMIT);
        return jdbc.query(sql.toString(), ENTRY, args.toArray());
    }

    /**
     * Kisisel programa tohumlama icin profilin (bolum + sinif) resmi programi. Sinif profilde yoksa BOS doner:
     * tum siniflari kopyalamak ogrenciye yanlis program verir. Donem: yayindaki en yeni donem.
     */
    OfficialMatch matchFor(Long uid) {
        String t = currentTerm();
        AcademicAudience.Who me = audience.of(uid);
        if (t == null || !me.complete() || me.grade() == null || me.grade().isBlank()) {
            return new OfficialMatch(t, List.of());
        }
        return new OfficialMatch(t, query(t, me.department(), me.grade().strip().toUpperCase(Locale.ROOT), null));
    }

    /** Profile uyan resmi satirlar (tum birimlerden). */
    record OfficialMatch(String term, List<EntryView> items) {
        List<String> units() {
            return items.stream().map(EntryView::unit).distinct().sorted().toList();
        }
    }

    String currentTerm() {
        List<String> r = jdbc.query("SELECT term FROM official_timetable_entry WHERE published = TRUE ORDER BY id DESC LIMIT 1",
                (rs, i) -> rs.getString(1));
        return r.isEmpty() ? null : r.get(0);
    }

    // ---- ortak ----

    private static final String ENTRY_SELECT = "SELECT id, term, unit, faculty, department, program, grade, grp, day_of_week, "
            + "start_time, end_time, course_code, course_name, instructor, room, note, source_url, published "
            + "FROM official_timetable_entry ";

    private static final org.springframework.jdbc.core.RowMapper<EntryView> ENTRY = (rs, i) -> new EntryView(
            rs.getLong("id"), rs.getString("term"), rs.getString("unit"), rs.getString("faculty"),
            rs.getString("department"), rs.getString("program"), rs.getString("grade"), rs.getString("grp"),
            rs.getInt("day_of_week"), AcademicTime.fmtTime(rs.getTime("start_time").toLocalTime()),
            AcademicTime.fmtTime(rs.getTime("end_time").toLocalTime()), rs.getString("course_code"),
            rs.getString("course_name"), rs.getString("instructor"), rs.getString("room"), rs.getString("note"),
            rs.getString("source_url"), rs.getBoolean("published"));
}
