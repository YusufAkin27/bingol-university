package edu.bingol.backend.profile;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap silmede (KVKK) kullaniciya ait kisisel kayitlari siler: cihaz (FCM token), bildirim kutusu ve
 * tercihleri, kayitli haberler, kulup basvuru yanitlari, topluluk uyelikleri, oylar, engellemeler, etkinlik
 * geri bildirimi. Serbest metin tutan destek/geri bildirim/itiraz/rapor/basvuru kayitlari silinmez ama metinleri
 * temizlenir (SCRUBS): kullanici satiri zaten anonimlestirildigi icin kayit kimliksizdir.
 * Sohbet gecmisi baskalarinin verisi oldugundan satirlar silinmez; yalnizca odalardan cikis yapilir.
 * Bilerek KORUNANLAR: legal_acceptance (sozlesme onayi = hukuki kanit), moderation_strike/rapor ve yasak izleri
 * (moderasyon denetimi), event_attendance/RSVP-sayaclari (anonim istatistik), topluluk gonderileri ve mesajlar
 * (baskalarinin baglami; yazar anonim gorunur), admin_audit (yonetici islemi izi).
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
            "DELETE FROM feedback_vote WHERE user_id = ?",
            "DELETE FROM event_feedback WHERE user_id = ?",
            "DELETE FROM user_block WHERE blocker_id = ?",
            "DELETE FROM user_block WHERE blocked_id = ?",
            "DELETE FROM club_join_answer WHERE user_id = ?",
            // Sahiplik devri yapilmadan sahip satiri silinmez; BANNED kaydi moderasyon izi olarak kalir
            "DELETE FROM community_member WHERE user_id = ? AND role <> 'OWNER' AND status <> 'BANNED'");

    /** Serbest metinler temizlenir, satir (ve kimlik baglantisi) kalir; kullanici satiri anonimlestirildi. */
    static final List<String> SCRUBS = List.of(
            "UPDATE feedback SET subject = 'Silinmiş kullanıcı', message = '[silindi]', is_public = FALSE WHERE user_id = ?",
            "UPDATE support_ticket SET subject = '[silindi]' WHERE user_id = ?",
            "UPDATE support_message SET text = '[silindi]' WHERE author_id = ? AND from_staff = FALSE",
            "UPDATE moderation_appeal SET message = '[silindi]' WHERE user_id = ?",
            "UPDATE report SET note = NULL WHERE reporter_id = ?",
            "UPDATE event_application SET note = NULL, answer1 = NULL, answer2 = NULL, answer3 = NULL WHERE user_id = ?",
            "UPDATE event_certificate SET holder_name = 'Silinmiş kullanıcı' WHERE user_id = ?");

    static final String LEAVE_ROOMS =
            "UPDATE conversation_member SET left_at = CURRENT_TIMESTAMP WHERE user_id = ? AND left_at IS NULL";

    private final JdbcTemplate jdbc;

    public AccountDataPurger(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void purge(Long userId) {
        DELETES.forEach(sql -> jdbc.update(sql, userId));
        SCRUBS.forEach(sql -> jdbc.update(sql, userId));
        jdbc.update(LEAVE_ROOMS, userId);
    }
}
