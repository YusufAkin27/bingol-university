package edu.bingol.backend.status;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.status.dto.SourceStatus;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class StatusController {

    private final StatusService status;
    private final I18n i18n;

    public StatusController(StatusService status, I18n i18n) {
        this.status = status;
        this.i18n = i18n;
    }

    /** GET /api/status -> {"NEWS": {...}, "MENU": {...}} */
    @GetMapping("/status")
    public Map<String, SourceStatus> status() {
        Map<String, SourceStatus> out = new LinkedHashMap<>();
        status.all().forEach(s -> out.put(s.getSource(), SourceStatus.of(s, maintenanceText(s.getSource()))));
        return out;
    }

    /** Ceviri anahtari yoksa (msg anahtarin kendisini doner) null: istemci teknik message'a duser. */
    private String maintenanceText(String source) {
        String key = "status.maintenance." + source;
        String text = i18n.current(key);
        return key.equals(text) ? null : text;
    }
}
