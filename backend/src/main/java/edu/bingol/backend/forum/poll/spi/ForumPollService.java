package edu.bingol.backend.forum.poll.spi;

import java.util.Collection;
import java.util.Set;

/**
 * SPI: konuya bagli anket. Arayuzu A yayinlar (forum.poll.spi), UYGULAYAN C'dir (forum.poll). A bu bean'i
 * {@code ObjectProvider<ForumPollService>} ile alir; yoksa anketli konu olusturma 400 FORUM_POLL_UNAVAILABLE olur,
 * anketsiz akis etkilenmez.
 */
public interface ForumPollService {

    /**
     * Konuya anket ekler; konu olusturan islemin (transaction) ICINDE cagrilir (hata = konu da geri alinir).
     * Dogrulama C'dedir: 2-6 secenek, secenek &lt;= 80 karakter, endsAt gelecekte ve &lt;= 30 gun.
     */
    PollView createForTopic(Long topicId, CreatePollRequest req);

    /** Konunun anketi (bakanin oyu ve oy hakkiyla); anket yoksa null. */
    PollView pollFor(Long topicId, Long viewerId);

    /** Verilen konulardan anketi olanlar (liste kartlarindaki {@code hasPoll} icin tek sorgu). */
    Set<Long> topicIdsWithPoll(Collection<Long> topicIds);
}
