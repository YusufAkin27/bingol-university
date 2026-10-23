package edu.bingol.backend.export;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import java.time.Instant;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Kullanici kendi verilerini JSON olarak indirir (KVKK m.11). Gunde en fazla 3 kez. */
@RestController
@RequestMapping("/api")
public class DataExportController {

    private final List<DataExporter> exporters;
    private final RateLimiter limiter;

    public DataExportController(List<DataExporter> exporters, RateLimiter limiter) {
        this.exporters = exporters.stream().sorted(Comparator.comparing(DataExporter::section)).toList();
        this.limiter = limiter;
    }

    @GetMapping("/users/me/export")
    public ResponseEntity<Map<String, Object>> export() {
        Long uid = CurrentUser.id();
        limiter.check("export:user:" + uid, 3, Duration.ofDays(1));
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("exportedAt", Instant.now().toString());
        for (DataExporter e : exporters) {
            out.put(e.section(), e.export(uid));
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"my-data.json\"")
                .body(out);
    }
}
