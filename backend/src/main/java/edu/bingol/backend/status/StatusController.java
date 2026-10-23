package edu.bingol.backend.status;

import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class StatusController {

    public record SourceStatus(boolean maintenance, String lastSuccessAt, String lastAttemptAt, String message) {}

    private final StatusService status;

    public StatusController(StatusService status) {
        this.status = status;
    }

    /** GET /api/status -> {"NEWS": {...}, "MENU": {...}} ; maintenance=true ise mobil "bakimda" gostermeli. */
    @GetMapping("/status")
    public Map<String, SourceStatus> status() {
        Map<String, SourceStatus> out = new LinkedHashMap<>();
        for (SyncStatus s : status.all()) {
            out.put(s.getSource(), new SourceStatus(
                    s.getState() == SyncStatus.State.MAINTENANCE,
                    s.getLastSuccessAt() == null ? null : s.getLastSuccessAt().toString(),
                    s.getLastAttemptAt() == null ? null : s.getLastAttemptAt().toString(),
                    s.getMessage()));
        }
        return out;
    }
}
