package edu.bingol.backend.forum.category;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.category.ForumCategoryDtos.CategoryView;
import java.time.Duration;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Forum kategorileri (herkese acik liste; giris gerekli). Yonetim uclari D'nin admin denetleyicisindedir. */
@RestController
@RequestMapping("/api/forum/categories")
public class ForumCategoryController {

    private final ForumCategoryService service;
    private final RateLimiter limiter;

    public ForumCategoryController(ForumCategoryService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /**
     * Aktif kategoriler (gruplu). {@code q} verilirse ad/adres/grup adinda Turkce karakter duyarsiz suzulur
     * (kategori secicide arama); bos {@code q} tum listedir. Yanit kisiye ozel degildir ama sayilar degisir: onbellek yok.
     */
    @GetMapping
    public List<CategoryView> list(@RequestParam(required = false) String q) {
        Long uid = CurrentUser.id();
        limiter.check("forum:read:" + uid, 120, Duration.ofMinutes(1));
        if (q != null && !q.isBlank()) {
            limiter.check("forum:catq:" + uid, 90, Duration.ofMinutes(1));
        }
        return service.publicList(q);
    }
}
