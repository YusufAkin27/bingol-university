package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.admin.bulk.BulkDtos.NewsAction;
import edu.bingol.backend.admin.bulk.BulkDtos.Report;
import edu.bingol.backend.admin.bulk.BulkSupport.Tally;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRepository;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Toplu haber gizle/goster. Her haber KENDI islemiyle (depo cagrisi) calisir; biri hata verse digerleri etkilenmez.
 * Bilerek @Transactional DEGILDIR (tek hata tum partiyi geri alirdi). Zaten istenen durumdaki kayit SKIPPED sayilir.
 */
@Service
public class NewsBulkService {

    private static final Logger log = LoggerFactory.getLogger(NewsBulkService.class);

    private final NewsRepository news;

    public NewsBulkService(NewsRepository news) {
        this.news = news;
    }

    public Report run(NewsAction action, List<Long> ids) {
        boolean hide = action == NewsAction.HIDE;
        Tally t = new Tally();
        for (Long id : ids) {
            try {
                Optional<NewsItem> found = news.findById(id);
                if (found.isEmpty()) {
                    t.skipped(id, "NOT_FOUND");
                } else if (found.get().isHidden() == hide) {
                    t.skipped(id, "ALREADY_DONE");
                } else {
                    NewsItem n = found.get();
                    n.setHidden(hide);
                    news.save(n);
                    t.done(id);
                }
            } catch (RuntimeException e) {
                log.warn("Toplu haber islemi hatasi: id={} {}", id, e.toString());
                t.failed(id, "INTERNAL_ERROR");
            }
        }
        return t.report();
    }
}
