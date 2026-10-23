package edu.bingol.backend.event;

import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Takvim gorunumu icin siteden gelen resmi ETKINLIK kayitlari (news modulune dokunmadan, salt okunur). */
public interface OfficialEventRepository extends JpaRepository<NewsItem, Long> {

    @Query("SELECT n FROM NewsItem n WHERE n.type = :type AND n.hidden = false AND n.publishedDate >= :from AND n.publishedDate <= :to ORDER BY n.publishedDate, n.id")
    List<NewsItem> inRange(@Param("type") ContentType type, @Param("from") LocalDate from,
                           @Param("to") LocalDate to, Pageable page);
}
