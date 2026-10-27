package edu.bingol.backend.legal;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalDtos.AcceptRequest;
import edu.bingol.backend.legal.LegalDtos.AcceptanceView;
import edu.bingol.backend.legal.LegalDtos.LegalContent;
import edu.bingol.backend.legal.LegalDtos.LegalSummary;
import edu.bingol.backend.legal.LegalDtos.PendingConsent;
import edu.bingol.backend.legal.LegalDtos.PublishRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Sozlesmeler. Okuma herkese aciktir (giris oncesi kayit ekraninda gosterilir); metin istek dilinde
 * (Accept-Language) doner, o dilde yoksa Turkce.
 */
@RestController
@RequestMapping("/api")
public class LegalController {

    private final LegalService legal;

    public LegalController(LegalService legal) {
        this.legal = legal;
    }

    private static Lang lang() {
        return Lang.of(LocaleContextHolder.getLocale());
    }

    private static LegalType type(String raw) {
        LegalType t = LegalType.parse(raw);
        if (t == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "LEGAL_NOT_FOUND", "Belge bulunamadı.");
        }
        return t;
    }

    /** Guncel tum belgelerin ozeti. */
    @GetMapping("/legal")
    public List<LegalSummary> list() {
        return legal.current(lang()).stream().map(LegalSummary::of).toList();
    }

    @GetMapping("/legal/{type}")
    public LegalContent get(@PathVariable String type) {
        LegalContent c = LegalContent.of(legal.current(type(type), lang()));
        return new LegalContent(c.type(), c.version(), c.title(), legal.render(c.content()), c.lang(), c.publishedAt());
    }

    @GetMapping("/legal/{type}/versions")
    public List<LegalSummary> versions(@PathVariable String type) {
        return legal.versions(type(type), lang()).stream().map(LegalSummary::of).toList();
    }

    // --- giris gerekli ---

    @GetMapping("/legal/consents/pending")
    public List<PendingConsent> pending() {
        return legal.pending(CurrentUser.id(), lang());
    }

    @PostMapping("/legal/consents")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void accept(@Valid @RequestBody AcceptRequest r) {
        legal.accept(CurrentUser.id(), r.items());
    }

    @GetMapping("/legal/consents/mine")
    public List<AcceptanceView> mine() {
        return legal.mine(CurrentUser.id());
    }

    // --- yonetici ---

    /** Yeni surum yayinla (tr zorunlu, en/ar istege bagli). */
    @PostMapping("/admin/legal/{type}")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Integer> publish(@PathVariable String type, @Valid @RequestBody PublishRequest r) {
        return Map.of("version", legal.publish(type(type), r));
    }
}
