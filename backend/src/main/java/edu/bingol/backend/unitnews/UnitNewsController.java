package edu.bingol.backend.unitnews;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.unitnews.UnitNewsDtos.Detail;
import edu.bingol.backend.unitnews.UnitNewsDtos.Item;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Ogrencinin bolumune gore birim duyurulari (giris gerekli; eslesme yoksa bos dizi). */
@RestController
@RequestMapping("/api/news/unit")
public class UnitNewsController {

    private final UnitNewsService service;

    public UnitNewsController(UnitNewsService service) {
        this.service = service;
    }

    @GetMapping
    public List<Item> feed(@RequestParam(defaultValue = "10") int limit) {
        return service.feed(CurrentUser.id(), limit);
    }

    @GetMapping("/{id}")
    public Detail detail(@PathVariable long id) {
        return service.detail(CurrentUser.id(), id);
    }
}
