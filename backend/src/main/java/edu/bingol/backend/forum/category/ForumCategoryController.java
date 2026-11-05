package edu.bingol.backend.forum.category;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.category.ForumCategoryDtos.CategoryView;
import java.time.Duration;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
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

    @GetMapping
    public List<CategoryView> list() {
        limiter.check("forum:read:" + CurrentUser.id(), 120, Duration.ofMinutes(1));
        return service.publicList();
    }
}
