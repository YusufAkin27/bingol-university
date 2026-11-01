package edu.bingol.backend.unitnews;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.unitnews.UnitNewsDtos.Detail;
import edu.bingol.backend.unitnews.UnitNewsDtos.Item;
import jakarta.servlet.http.HttpServletResponse;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Ogrencinin bolumune gore birim duyurulari (giris gerekli; eslesme yoksa bos dizi). Yanit KISISELDIR (kullanicinin
 * bolumune gore degisir): {@code Cache-Control: private, no-store} ayarlanir; ShallowEtagHeaderFilter ({@code /api/news/*}
 * kalibi) no-store goren yanita ETag eklemez, boylece ortak onbellek/vekil baska kullaniciya sunamaz.
 */
@RestController
@RequestMapping("/api/news/unit")
public class UnitNewsController {

    static final String CACHE_CONTROL = "private, no-store";

    private final UnitNewsService service;

    public UnitNewsController(UnitNewsService service) {
        this.service = service;
    }

    @GetMapping
    public List<Item> feed(@RequestParam(defaultValue = "10") int limit, HttpServletResponse res) {
        res.setHeader("Cache-Control", CACHE_CONTROL);
        return service.feed(CurrentUser.id(), limit);
    }

    @GetMapping("/{id}")
    public Detail detail(@PathVariable long id, HttpServletResponse res) {
        res.setHeader("Cache-Control", CACHE_CONTROL);
        return service.detail(CurrentUser.id(), id);
    }
}
