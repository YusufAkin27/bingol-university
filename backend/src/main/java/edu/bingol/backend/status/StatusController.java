package edu.bingol.backend.status;

import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.status.dto.SourceStatus;
import java.util.Map;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class StatusController {

    private final StatusViewService status;

    public StatusController(StatusViewService status) {
        this.status = status;
    }

    /** GET /api/status -> {"NEWS": {...}, "MENU": {...}} */
    @GetMapping("/status")
    public Map<String, SourceStatus> status() {
        return status.view(Lang.of(LocaleContextHolder.getLocale()));
    }
}
