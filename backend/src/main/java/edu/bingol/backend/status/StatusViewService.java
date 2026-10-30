package edu.bingol.backend.status;

import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.status.dto.SourceStatus;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.stereotype.Service;
import tools.jackson.core.type.TypeReference;

/**
 * Herkese acik kaynak durumu gorunumu (GET /api/status). Herkese ayni cevap (dil disinda) oldugundan sunucu
 * onbellegine girer: `status` ad alani, {@link SyncStatus} yazmasinda (markOk/markMaintenance) gecersiz kilinir.
 */
@Service
public class StatusViewService {

    private static final TypeReference<LinkedHashMap<String, SourceStatus>> VIEW = new TypeReference<>() { };

    private final StatusService status;
    private final I18n i18n;
    private final CacheService cache;

    public StatusViewService(StatusService status, I18n i18n, CacheService cache) {
        this.status = status;
        this.i18n = i18n;
        this.cache = cache;
    }

    public Map<String, SourceStatus> view(Lang lang) {
        return cache.get("status", "v:" + lang.code(), CacheTier.SHORT, VIEW, () -> {
            Map<String, SourceStatus> out = new LinkedHashMap<>();
            status.all().forEach(s -> out.put(s.getSource(), SourceStatus.of(s, maintenanceText(s.getSource(), lang))));
            return (LinkedHashMap<String, SourceStatus>) out;
        });
    }

    /** Ceviri anahtari yoksa (msg anahtarin kendisini doner) null: istemci teknik message'a duser. */
    private String maintenanceText(String source, Lang lang) {
        String key = "status.maintenance." + source;
        String text = i18n.msg(key, lang);
        return key.equals(text) ? null : text;
    }
}
