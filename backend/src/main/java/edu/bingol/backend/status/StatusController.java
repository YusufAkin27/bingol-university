package edu.bingol.backend.status;

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

    public StatusController(StatusService status) {
        this.status = status;
    }

    /** GET /api/status -> {"NEWS": {...}, "MENU": {...}} */
    @GetMapping("/status")
    public Map<String, SourceStatus> status() {
        Map<String, SourceStatus> out = new LinkedHashMap<>();
        status.all().forEach(s -> out.put(s.getSource(), SourceStatus.of(s)));
        return out;
    }
}
