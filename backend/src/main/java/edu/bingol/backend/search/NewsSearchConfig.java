package edu.bingol.backend.search;

import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Haber/duyuru/etkinlik haberi icin uc SearchProvider bean'i. */
@Configuration
public class NewsSearchConfig {

    @Bean
    SearchProvider newsSearchProvider(NewsRepository repo) {
        return new NewsSearchProvider(repo, SearchType.NEWS, ContentType.HABER);
    }

    @Bean
    SearchProvider announcementSearchProvider(NewsRepository repo) {
        return new NewsSearchProvider(repo, SearchType.ANNOUNCEMENT, ContentType.DUYURU);
    }

    @Bean
    SearchProvider officialEventSearchProvider(NewsRepository repo) {
        return new NewsSearchProvider(repo, SearchType.EVENT_OFFICIAL, ContentType.ETKINLIK);
    }
}
