package edu.bingol.backend.academic;

import edu.bingol.backend.academic.AcademicDtos.Page;
import edu.bingol.backend.academic.OfficialTimetableDtos.AdminProgramsView;
import edu.bingol.backend.academic.AcademicDtos.TimetableView;
import edu.bingol.backend.academic.OfficialTimetableDtos.ApplyRequest;
import edu.bingol.backend.academic.OfficialTimetableDtos.EntryView;
import edu.bingol.backend.academic.OfficialTimetableDtos.ImportResult;
import edu.bingol.backend.academic.OfficialTimetableDtos.OfficialStatus;
import edu.bingol.backend.academic.OfficialTimetableDtos.OfficialView;
import edu.bingol.backend.academic.OfficialTimetableDtos.PublishRequest;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Resmi ders programi: kullanici okuma ucu + yonetici Excel yukleme/yonetim uclari (yalniz HTTP eslemesi + hiz siniri). */
@RestController
@RequestMapping("/api")
public class OfficialTimetableController {

    private static final long MAX_FILE_BYTES = 1_800_000; // /api/admin/** govde sinirinin (2 MB) altinda

    private final OfficialTimetableService service;
    private final OfficialTimetableSeeder seeder;
    private final RateLimiter limiter;

    public OfficialTimetableController(OfficialTimetableService service, OfficialTimetableSeeder seeder, RateLimiter limiter) {
        this.service = service;
        this.seeder = seeder;
        this.limiter = limiter;
    }

    private Long read() {
        Long uid = CurrentUser.id();
        limiter.check("acd:read:" + uid, 120, Duration.ofMinutes(1));
        return uid;
    }

    /** Yonetici kimligi (Basic auth yoneticisinde kullanici kaydi yoktur: null). */
    private Long admin(String bucket, int perMinute) {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        Long id = a != null && a.getPrincipal() instanceof Long l ? l : null;
        limiter.check("acd:" + bucket + ":" + (id != null ? id : "basic"), perMinute, Duration.ofMinutes(1));
        return id;
    }

    // ---- kullanici ----

    /** Profildeki bolum/sinif icin yayinda olan resmi program; department/grade/unit/term ile baska program da sorgulanabilir. */
    @GetMapping("/timetable/official")
    public OfficialView official(@RequestParam(required = false) String term, @RequestParam(required = false) String department,
                                 @RequestParam(required = false) String grade, @RequestParam(required = false) String unit) {
        return service.forUser(read(), term, department, grade, unit);
    }

    /** Profilin resmi programi var mi, kisisel programa kopyalandi mi, hangi birimler eslesti. */
    @GetMapping("/timetable/official/status")
    public OfficialStatus officialStatus() {
        return seeder.status(read());
    }

    /** Resmi programi kisisel programa kopyalar (replace=true: mevcut dersleri silip yeniden; onay istemcide). */
    @PostMapping("/timetable/official/apply")
    public TimetableView officialApply(@RequestBody(required = false) ApplyRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("acd:official-apply:" + uid, 10, Duration.ofHours(1));
        return seeder.apply(uid, req);
    }

    // ---- yonetici ----

    @PostMapping("/admin/academic/timetable/import")
    public ImportResult importXlsx(@RequestParam("file") MultipartFile file, @RequestParam(required = false) String term,
                                   @RequestParam(defaultValue = "true") boolean dryRun) {
        Long id = admin("tt-import", 12);
        if (file.isEmpty() || file.getSize() > MAX_FILE_BYTES) {
            throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "TIMETABLE_FILE_INVALID", "Excel dosyası okunamadı: {0}",
                    "dosya boş ya da 1,8 MB'tan büyük");
        }
        byte[] bytes;
        try {
            bytes = file.getBytes();
        } catch (IOException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TIMETABLE_FILE_INVALID", "Excel dosyası okunamadı: {0}", "okuma hatası");
        }
        if (bytes.length < 4 || bytes[0] != 'P' || bytes[1] != 'K') { // .xlsx bir zip arsividir
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "TIMETABLE_FILE_INVALID", "Excel dosyası okunamadı: {0}",
                    ".xlsx dosyası bekleniyor");
        }
        return service.importXlsx(id, file.getOriginalFilename(), bytes, term, dryRun);
    }

    @GetMapping("/admin/academic/timetable/programs")
    public AdminProgramsView programs(@RequestParam(required = false) String term) {
        return service.adminPrograms(term);
    }

    @GetMapping("/admin/academic/timetable/entries")
    public Page<EntryView> entries(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size,
                                   @RequestParam String term, @RequestParam String unit, @RequestParam String program,
                                   @RequestParam(required = false) String grade) {
        return service.adminEntries(page, size, term, unit, program, grade);
    }

    @DeleteMapping("/admin/academic/timetable/programs")
    public Map<String, Integer> deleteProgram(@RequestParam String term, @RequestParam String unit, @RequestParam String program) {
        admin("tt-write", 60);
        return Map.of("deleted", service.adminDeleteProgram(term, unit, program));
    }

    @PostMapping("/admin/academic/timetable/publish")
    public Map<String, Integer> publish(@RequestBody PublishRequest req) {
        admin("tt-write", 60);
        boolean on = req.published() == null || req.published();
        return Map.of("updated", service.adminPublish(req.term(), req.unit(), req.program(), on));
    }
}
