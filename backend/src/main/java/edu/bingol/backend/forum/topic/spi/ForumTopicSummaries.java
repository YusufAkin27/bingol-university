package edu.bingol.backend.forum.topic.spi;

import edu.bingol.backend.forum.topic.dto.TopicSummary;
import java.util.Collection;
import java.util.List;

/**
 * SPI (uygulayan: forum.topic, A): konu kimliklerinden liste kartlari (arama, profil, kaydedilenler icin E).
 * Gorunmeyen (silinmis/kaldirilmis/engelli/sessize alinmis/pasif yazar) konular SESSIZCE atlanir; kalanlar
 * {@code topicIds} sirasini korur.
 */
public interface ForumTopicSummaries {

    List<TopicSummary> summaries(Collection<Long> topicIds, Long viewerId);
}
