package edu.bingol.backend.support.faq;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.CacheTier;
import edu.bingol.backend.common.SlicePaging;
import edu.bingol.backend.i18n.Lang;
import org.springframework.context.i18n.LocaleContextHolder;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Slice;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import tools.jackson.core.type.TypeReference;

/** Sik sorulan sorular: herkese acik okuma, yonetici duzenleme. */
@RestController
@RequestMapping("/api")
public class FaqController {

    public record FaqEntry(Long id, String question, String answer) {}

    public record FaqGroup(String category, List<FaqEntry> items) {}

    public record FaqRequest(@NotBlank @Pattern(regexp = "tr|en|ar") String lang, @NotBlank @Size(max = 40) String category, @NotBlank @Size(max = 300) String question,
                             @NotBlank @Size(max = 2000) String answer, Integer sortOrder, Boolean published) {}

    public record FaqAdminView(Long id, String lang, String category, String question, String answer, int sortOrder,
                               boolean published) {
        static FaqAdminView of(FaqItem f) {
            return new FaqAdminView(f.getId(), f.getLang(), f.getCategory(), f.getQuestion(), f.getAnswer(), f.getSortOrder(),
                    f.isPublished());
        }
    }

    private static final TypeReference<List<FaqGroup>> GROUPS = new TypeReference<>() { };

    private final FaqRepository repo;
    private CacheService cache = CacheService.passthrough();

    public FaqController(FaqRepository repo) {
        this.repo = repo;
    }

    /** Sunucu onbellegi `faq` ad alani; SSS yazmasi (FaqItem varlik olaylari) gecersiz kilar. */
    @Autowired(required = false)
    void setCache(CacheService cache) {
        this.cache = cache;
    }

    /** GET /api/faq (herkese acik) — kategoriye gore gruplu, istek dilinde; o dilde icerik yoksa Turkce. */
    @GetMapping("/faq")
    public List<FaqGroup> list() {
        Lang lang = Lang.of(LocaleContextHolder.getLocale());
        return cache.get("faq", "l:" + lang.code(), CacheTier.STABLE, GROUPS, () -> publicGroups(lang));
    }

    private List<FaqGroup> publicGroups(Lang lang) {
        List<FaqItem> items = repo.findByLangAndPublishedTrueOrderByCategoryAscSortOrderAscIdAsc(lang.code());
        if (items.isEmpty() && lang != Lang.TR) {
            items = repo.findByLangAndPublishedTrueOrderByCategoryAscSortOrderAscIdAsc(Lang.TR.code());
        }
        Map<String, List<FaqEntry>> grouped = items.stream()
                .collect(Collectors.groupingBy(FaqItem::getCategory, LinkedHashMap::new,
                        Collectors.mapping(f -> new FaqEntry(f.getId(), f.getQuestion(), f.getAnswer()),
                                Collectors.toList())));
        return grouped.entrySet().stream().map(e -> new FaqGroup(e.getKey(), e.getValue())).toList();
    }

    /** Yonetici listesi sayfalidir (?cursor=&limit=, en cok 50); devam varsa X-Next-Cursor basligi. */
    @GetMapping("/admin/faq")
    public ResponseEntity<List<FaqAdminView>> adminList(@RequestParam(required = false) Long cursor,
                                                        @RequestParam(required = false) Integer limit) {
        Slice<FaqItem> slice = repo.findAllByOrderByLangAscCategoryAscSortOrderAscIdAsc(SlicePaging.request(cursor, limit));
        return SlicePaging.respond(slice, slice.getContent().stream().map(FaqAdminView::of).toList());
    }

    @PostMapping("/admin/faq")
    @ResponseStatus(HttpStatus.CREATED)
    public FaqAdminView create(@Valid @RequestBody FaqRequest r) {
        return FaqAdminView.of(repo.save(apply(new FaqItem(), r)));
    }

    @PutMapping("/admin/faq/{id}")
    public FaqAdminView update(@PathVariable Long id, @Valid @RequestBody FaqRequest r) {
        FaqItem f = repo.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "FAQ_NOT_FOUND", "Soru bulunamadı."));
        return FaqAdminView.of(repo.save(apply(f, r)));
    }

    @DeleteMapping("/admin/faq/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        repo.deleteById(id);
    }

    private static FaqItem apply(FaqItem f, FaqRequest r) {
        f.setLang(r.lang());
        f.setCategory(r.category().trim());
        f.setQuestion(r.question().trim());
        f.setAnswer(r.answer().trim());
        f.setSortOrder(r.sortOrder() == null ? 0 : r.sortOrder());
        f.setPublished(r.published() == null || r.published());
        f.setUpdatedAt(Instant.now());
        return f;
    }
}
