package edu.bingol.backend.appinfo;

import edu.bingol.backend.appinfo.AppInfoService.AppInfo;
import edu.bingol.backend.appinfo.AppInfoService.VersionCheck;
import edu.bingol.backend.i18n.Lang;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.Map;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Herkese acik uygulama bilgisi (iletisim, banner, bakim modu) ve surum kontrolu; yonetici ayar uclari. */
@RestController
@RequestMapping("/api")
public class AppInfoController {

    public record SettingRequest(@NotNull @Size(max = 1000) String value) {}

    private final AppInfoService service;

    public AppInfoController(AppInfoService service) {
        this.service = service;
    }

    /** Uygulama acilisinda cagrilir: bakim modu, banner, iletisim bilgileri. */
    @GetMapping("/app/info")
    public AppInfo info() {
        return service.info(Lang.of(LocaleContextHolder.getLocale()));
    }

    /** GET /api/app/version?platform=ANDROID&version=1.0.3 */
    @GetMapping("/app/version")
    public VersionCheck version(@RequestParam String platform, @RequestParam String version) {
        return service.checkVersion(platform, version);
    }

    @GetMapping("/admin/settings")
    public Map<String, String> settings() {
        return service.all();
    }

    @PutMapping("/admin/settings/{key}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void set(@PathVariable String key, @Valid @RequestBody SettingRequest r) {
        service.set(key, r.value());
    }
}
