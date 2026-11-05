package edu.bingol.backend.forum.poll;

import edu.bingol.backend.profile.UserAccountDeletedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap silmede (KVKK) kullanicinin forum anketi oylari silinir ve sectigi seceneklerin sayaclari AYNI islemde dusurulur
 * (sayaclar ile oy satirlari tutarli kalir). Hesap silme akisindan (ProfileService) senkron yayinlanan
 * {@link UserAccountDeletedEvent} ile, o islemin icinde calisir; {@code AccountDataPurger.HANDLED_ELSEWHERE} bu sinifi gosterir.
 * Duz SQL: depolara bagimlilik yok, PostgreSQL ve H2'de ayni.
 */
@Component
public class ForumPollAccountPurger {

    private final JdbcTemplate jdbc;

    public ForumPollAccountPurger(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @EventListener
    public void onAccountDeleted(UserAccountDeletedEvent event) {
        purge(event.userId());
    }

    /** Oy basina 1: once sayac, sonra satir. @return silinen oy sayisi */
    public int purge(Long userId) {
        jdbc.update("UPDATE forum_poll_option SET vote_count = vote_count - 1 WHERE vote_count > 0 "
                + "AND id IN (SELECT option_id FROM forum_poll_vote WHERE user_id = ?)", userId);
        return jdbc.update("DELETE FROM forum_poll_vote WHERE user_id = ?", userId);
    }
}
