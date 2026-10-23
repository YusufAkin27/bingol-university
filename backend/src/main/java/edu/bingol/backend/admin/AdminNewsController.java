package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AdminNewsRow;
import edu.bingol.backend.admin.AdminDtos.HiddenRequest;
import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRepository;
import jakarta.validation.Valid;
import java.util.ArrayList;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Haber yonetimi: gizlenmis kayitlar dahil liste ve gizle/goster (gizli kayit herkese acik uclarda gorunmez). */
@RestController
@RequestMapping("/api/admin/news")
public class AdminNewsController {

    private final NamedParameterJdbcTemplate jdbc;
    private final NewsRepository news;

    public AdminNewsController(NamedParameterJdbcTemplate jdbc, NewsRepository news) {
        this.jdbc = jdbc;
        this.news = news;
    }

    /** GET /api/admin/news?q=&type=&hidden=&page=&size= (en yeni once) */
    @GetMapping
    @Transactional(readOnly = true)
    public PageResponse<AdminNewsRow> list(@RequestParam(required = false) String q,
                                           @RequestParam(required = false) ContentType type,
                                           @RequestParam(required = false) Boolean hidden,
                                           @RequestParam(defaultValue = "0") int page,
                                           @RequestParam(defaultValue = "20") int size) {
        int s = Math.min(Math.max(size, 1), AdminUserService.MAX_PAGE_SIZE);
        int p = Math.max(page, 0);
        List<String> c = new ArrayList<>();
        MapSqlParameterSource params = new MapSqlParameterSource();
        if (q != null && !q.isBlank()) {
            c.add("title ILIKE :q ESCAPE '\\'");
            params.addValue("q", "%" + UserFilter.escapeLike(q.trim()) + "%");
        }
        if (type != null) {
            c.add("type = :type");
            params.addValue("type", type.name());
        }
        if (hidden != null) {
            c.add("hidden = :hidden");
            params.addValue("hidden", hidden);
        }
        String where = c.isEmpty() ? "TRUE" : String.join(" AND ", c);
        Long total = jdbc.queryForObject("SELECT count(*) FROM news_item WHERE " + where, params, Long.class);
        params.addValue("lim", s).addValue("off", (long) p * s);
        List<AdminNewsRow> rows = jdbc.query("SELECT id, type, title, summary, url, image_url, published_date, fetched_at, "
                + "hidden FROM news_item WHERE " + where + " ORDER BY published_date DESC NULLS LAST, id DESC "
                + "LIMIT :lim OFFSET :off", params, (rs, i) -> new AdminNewsRow(rs.getLong("id"), rs.getString("type"),
                        rs.getString("title"), rs.getString("summary"), rs.getString("url"), rs.getString("image_url"),
                        rs.getString("published_date"), AdminUserRepository.ts(rs, "fetched_at"), rs.getBoolean("hidden")));
        return PageResponse.of(rows, p, s, total == null ? 0 : total);
    }

    @PatchMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Transactional
    public void setHidden(@PathVariable Long id, @Valid @RequestBody HiddenRequest r) {
        NewsItem n = news.findById(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Haber bulunamadı."));
        n.setHidden(r.hidden());
        news.save(n);
    }
}
