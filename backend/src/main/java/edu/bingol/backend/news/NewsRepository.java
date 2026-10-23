package edu.bingol.backend.news;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NewsRepository extends JpaRepository<NewsItem, Long> {

    boolean existsByUrl(String url);

    Page<NewsItem> findByType(ContentType type, Pageable pageable);
}
