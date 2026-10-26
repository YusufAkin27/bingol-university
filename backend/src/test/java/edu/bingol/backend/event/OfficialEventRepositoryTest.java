package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;

/** Resmi etkinlikler COALESCE(eventDate, publishedDate) ile aralığa girer ve o alana göre sıralanır. */
@SpringBootTest
class OfficialEventRepositoryTest {

    @Autowired
    OfficialEventRepository repo;

    private NewsItem item(String title, LocalDate published, LocalDate eventDate) {
        NewsItem n = new NewsItem();
        n.setType(ContentType.ETKINLIK);
        n.setUrl("https://example.org/" + UUID.randomUUID());
        n.setTitle(title);
        n.setPublishedDate(published);
        n.setEventDate(eventDate);
        n.setFetchedAt(Instant.now());
        return repo.saveAndFlush(n);
    }

    @Test
    void usesEventDateWhenPresentAndOrdersByIt() {
        // Yayin tarihi Eylul, gercek gun Ekim: Ekim takviminde gorunmeli
        item("ekim-event", LocalDate.of(2031, 9, 20), LocalDate.of(2031, 10, 25));
        // Yalnizca yayin tarihi var: o tarihle gelir
        item("ekim-yayin", LocalDate.of(2031, 10, 5), null);
        // Yayin Ekim ama etkinlik Kasim: Ekim'de gorunmemeli
        item("kasim-event", LocalDate.of(2031, 10, 28), LocalDate.of(2031, 11, 3));

        List<NewsItem> out = repo.inRange(ContentType.ETKINLIK, LocalDate.of(2031, 10, 1),
                LocalDate.of(2031, 10, 31), PageRequest.of(0, 50));

        assertEquals(List.of("ekim-yayin", "ekim-event"), out.stream().map(NewsItem::getTitle).toList());
    }
}
