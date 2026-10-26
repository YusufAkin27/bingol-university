package edu.bingol.backend.profile;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap silmede (KVKK) kullaniciya ait kisisel kayitlari siler: cihaz (FCM token), bildirim kutusu ve
 * tercihleri, kayitli haberler, kulup basvuru yanitlari, topluluk uyelikleri. Sohbet gecmisi baskalarinin
 * verisi oldugundan satirlar silinmez; yalnizca odalardan cikis yapilir.
 * Duz SQL: boylece ilgili modullerin depolarina bagimlilik olusmaz.
 */
@Component
public class AccountDataPurger {

    /** Silinecek tablolar (hepsinde user_id sutunu var). Topluluk sahipligi ve yasak kayitlari korunur. */
    static final List<String> DELETES = List.of(
            "DELETE FROM device WHERE user_id = ?",
            "DELETE FROM notification WHERE user_id = ?",
            "DELETE FROM notification_pref WHERE user_id = ?",
            "DELETE FROM notification_subtype_pref WHERE user_id = ?",
            "DELETE FROM bookmark WHERE user_id = ?",
            "DELETE FROM club_join_answer WHERE user_id = ?",
            // Sahiplik devri yapilmadan sahip satiri silinmez; BANNED kaydi moderasyon izi olarak kalir
            "DELETE FROM community_member WHERE user_id = ? AND role <> 'OWNER' AND status <> 'BANNED'");

    static final String LEAVE_ROOMS =
            "UPDATE conversation_member SET left_at = CURRENT_TIMESTAMP WHERE user_id = ? AND left_at IS NULL";

    private final JdbcTemplate jdbc;

    public AccountDataPurger(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void purge(Long userId) {
        DELETES.forEach(sql -> jdbc.update(sql, userId));
        jdbc.update(LEAVE_ROOMS, userId);
    }
}
