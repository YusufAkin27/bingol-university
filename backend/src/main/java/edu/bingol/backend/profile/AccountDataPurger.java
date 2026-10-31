package edu.bingol.backend.profile;

import edu.bingol.backend.post.admin.PostAccountPurger;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap silmede (KVKK) kullaniciya ait kisisel kayitlari siler: cihaz (FCM token), bildirim kutusu ve
 * tercihleri, kayitli haberler, kulup basvuru yanitlari, topluluk uyelikleri, oylar, engellemeler, etkinlik
 * geri bildirimi, erisim engeli/uygunsuz ifade log satirlari, goruntuleme kayitlari, tepkiler. Serbest metin tutan
 * destek/geri bildirim/itiraz/rapor/basvuru kayitlari silinmez ama metinleri temizlenir (SCRUBS): kullanici satiri
 * zaten anonimlestirildigi icin kayit kimliksizdir. E-posta kuyrugunda silinen kisinin adresi de silinir.
 * Sohbet gecmisi baskalarinin verisi oldugundan satirlar silinmez; yalnizca odalardan cikis yapilir.
 *
 * <p>Her kullanici baglantili sutunun karari (sil / anonimlestir / yasal saklama) bu sinifta kayitlidir:
 * {@link #DELETES}, {@link #SCRUBS}, {@link #HANDLED_ELSEWHERE} ve gerekceli {@link #RETAINED}. Yeni kullanici
 * sutunlu tablo bunlardan birinde yoksa {@code AccountDataPurgerCoverageTest} kirilir. Matris:
 * docs/DATABASE.md "Hesap silme matrisi".
 *
 * <p>Bilerek KORUNANLAR: legal_acceptance (sozlesme onayi = hukuki kanit), moderation_strike/rapor ve yasak izleri
 * (moderasyon denetimi), event_attendance/RSVP-sayaclari (anonim istatistik), topluluk gonderileri ve mesajlar
 * (baskalarinin baglami; yazar anonim gorunur), admin_audit (yonetici islemi izi).
 * Duz SQL: boylece ilgili modullerin depolarina bagimlilik olusmaz.
 */
@Component
public class AccountDataPurger {

    /** Silinecek tablolar (hepsinde user_id sutunu var). Topluluk sahipligi ve yasak kayitlari korunur. */
    public static final List<String> DELETES = List.of(
            "DELETE FROM device WHERE user_id = ?",
            // Kalici push kuyrugu: bekleyen push kayitlari
            "DELETE FROM push_outbox WHERE user_id = ?",
            // Anketler: secmen kaydi silinir (katilim sayaci poll.voter_count korunur); oylar asagida anonimlestirilir
            "DELETE FROM poll_ballot WHERE user_id = ?",
            // KVKK: cihaz/IP gecmisi (erisim engeli modulu) hesap silinince kendi kayitlari silinir
            "DELETE FROM user_device_log WHERE user_id = ?",
            // Mail kampanyasi alici kayitlari (kisisel veri: kullanici kimligi ile gonderim durumu)
            "DELETE FROM mail_campaign_recipient WHERE user_id = ?",
            "DELETE FROM notification WHERE user_id = ?",
            "DELETE FROM notification_pref WHERE user_id = ?",
            "DELETE FROM notification_subtype_pref WHERE user_id = ?",
            "DELETE FROM bookmark WHERE user_id = ?",
            "DELETE FROM feedback_vote WHERE user_id = ?",
            "DELETE FROM event_feedback WHERE user_id = ?",
            "DELETE FROM user_block WHERE blocker_id = ?",
            "DELETE FROM user_block WHERE blocked_id = ?",
            "DELETE FROM club_join_answer WHERE user_id = ?",
            // Sahiplik devri yapilmadan sahip satiri silinmez; BANNED kaydi moderasyon izi olarak kalir.
            // Devir/kapatma sonrasi kalan OWNER satirini CommunityAccountListener ve gece isi (DbMaintenanceJob) kapatir.
            "DELETE FROM community_member WHERE user_id = ? AND role <> 'OWNER' AND status <> 'BANNED'",
            // T-063 (A8-16): erisim engeli deneme gunlugu (IP + cihaz ozeti + kullanici), uygunsuz ifade isabeti,
            // tek gosterimlik goruntuleme kaydi ve tepkiler hesap silinince kullanici bagiyla birlikte silinir
            "DELETE FROM blocked_attempt_log WHERE user_id = ?",
            "DELETE FROM profanity_hit_log WHERE user_id = ?",
            "DELETE FROM message_attachment_view WHERE user_id = ?",
            "DELETE FROM message_reaction WHERE user_id = ?",
            // Kulup yetki kaydi, grup yeniden ekleme yasagi ve ortak organizator satiri: kisiye ozgu
            "DELETE FROM club_member_grant WHERE user_id = ?",
            "DELETE FROM conversation_add_ban WHERE user_id = ?",
            "DELETE FROM conversation_add_ban WHERE adder_id = ?",
            "DELETE FROM event_co_organizer WHERE user_id = ?");

    /** Serbest metinler temizlenir, satir (ve kimlik baglantisi) kalir; kullanici satiri anonimlestirildi. */
    public static final List<String> SCRUBS = List.of(
            // Anket oylari anonimlestirilir: kullanici bagi kalkar, secenek sayaclari ve toplam oy korunur
            "UPDATE poll_vote SET user_id = NULL WHERE user_id = ?",
            "UPDATE poll SET created_by = NULL WHERE created_by = ?",
            "UPDATE feedback SET subject = 'Silinmiş kullanıcı', message = '[silindi]', is_public = FALSE WHERE user_id = ?",
            "UPDATE support_ticket SET subject = '[silindi]' WHERE user_id = ?",
            "UPDATE support_message SET text = '[silindi]' WHERE author_id = ? AND from_staff = FALSE",
            "UPDATE moderation_appeal SET message = '[silindi]' WHERE user_id = ?",
            "UPDATE report SET note = NULL WHERE reporter_id = ?",
            "UPDATE event_application SET note = NULL, answer1 = NULL, answer2 = NULL, answer3 = NULL WHERE user_id = ?",
            "UPDATE event_certificate SET holder_name = 'Silinmiş kullanıcı' WHERE user_id = ?");

    /**
     * Bu sinifin listeleri DISINDA, ayni hesap silme akisinda isleyen kullanici baglantili sutunlar
     * ("tablo.sutun" -> nerede).
     */
    public static final Map<String, String> HANDLED_ELSEWHERE = Map.ofEntries(
            Map.entry("activity_daily.user_id", "ActivityTracker.purgeUser"),
            Map.entry("analytics_event.user_id", "ActivityTracker.purgeUser"),
            Map.entry("event_rsvp.user_id", "ProfileService.anonymize (RSVP silinir)"),
            Map.entry("tt_course.user_id", "AcademicAccountPurger"),
            Map.entry("tt_exam.user_id", "AcademicAccountPurger"),
            Map.entry("tt_semester.user_id", "AcademicAccountPurger"),
            Map.entry("announcement_read.user_id", "AcademicAccountPurger"),
            Map.entry("post.author_id", "PostAccountPurger (yumusak silme + medya)"),
            Map.entry("post_like.user_id", "PostAccountPurger"),
            Map.entry("post_media.owner_id", "PostAccountPurger"),
            Map.entry("user_follow.follower_id", "SocialAccountPurger"),
            Map.entry("user_follow.followee_id", "SocialAccountPurger"),
            Map.entry("user_follow_stats.user_id", "SocialAccountPurger"),
            Map.entry("profile_privacy.user_id", "AvatarCleanups (gizlilik satiri silinir)"),
            Map.entry("conversation_member.user_id", "LEAVE_ROOMS (satir kalir, left_at dolar; sohbet gecmisi digerlerinin verisi)"),
            Map.entry("community.owner_id", "CommunityAccountListener (sahiplik devri ya da kulup kapatma)"));

    /**
     * Bilerek SILINMEYEN/ANONIMLESTIRILMEYEN kullanici baglantili sutunlar ("tablo.sutun" -> gerekce ve sure).
     * Kullanici satiri anonimlestirildigi icin buradaki kimlik artik bir kisiye bagli degildir; sureler
     * docs/DATABASE.md "Hesap silme matrisi" ile ayni.
     */
    public static final Map<String, String> RETAINED = Map.ofEntries(
            Map.entry("legal_acceptance.user_id", "Hukuki kanit: sozlesme onayi (ispat), suresiz"),
            Map.entry("moderation_strike.user_id", "Moderasyon izi; yeniden kayitla ihlal gecmisinin sifirlanmamasi"),
            Map.entry("suspend_recommendation.user_id", "Moderasyon izi (yonetici karar kaydi)"),
            Map.entry("event_attendance.user_id", "Anonim katilim istatistigi (anonimlesmis hesaba bagli)"),
            Map.entry("message.sender_id", "Baskalarinin sohbet baglami; yazar anonim gorunur, silinen mesaj saklama suresiyle temizlenir"),
            Map.entry("message_attachment.uploader_id", "Sohbet gecmisi (baskalarinin baglami); ek saklama suresiyle temizlenir"),
            Map.entry("community_post.author_id", "Kulup gonderisi: baskalarinin baglami; yazar anonim gorunur"),
            Map.entry("user_event.created_by", "Etkinlik kaydi (katilimcilarin verisi); organizator iptali EventAccountListener"),
            Map.entry("conversation.created_by", "Sohbeti olusturan; sohbet baskalarinin verisi"),
            Map.entry("conversation_member.added_by", "Grup uyelik gecmisi (baskalarinin baglami)"),
            Map.entry("event_announcement.sender_id", "Etkinlik duyurusu; alicilarin baglami"),
            Map.entry("club_audit.target_user_id", "Kulup denetim izi (730 gun, DbMaintenanceJob); kimlik anonim"),
            Map.entry("message_access_audit.target_user_id", "Yonetici mesaj erisim denetimi: ekleme-yalniz tetikleyici, 730 gun"),
            Map.entry("club_ownership_transfer.from_user_id", "Kulup sahiplik devri izi"),
            Map.entry("club_ownership_transfer.to_user_id", "Kulup sahiplik devri izi"),
            Map.entry("admin_profile_change.target_user_id", "Yonetici yetki degisikligi izi (RBAC, iki kisi onayi)"),
            // Yonetici/operator islem izi: eylemi yapan yonetici (kullanici hesabi degil)
            Map.entry("admin_audit.admin_id", "Yonetici islem izi, 365 gun"),
            Map.entry("admin_profile_change.decided_by", "Yonetici islem izi"),
            Map.entry("data_export_receipt.admin_id", "Veri saklama makbuzu: silinemez (DS1)"),
            Map.entry("data_purge_log.admin_id", "Veri silme defteri: silinemez (DS1)"),
            Map.entry("event_moderation_log.admin_id", "Etkinlik moderasyon izi"),
            Map.entry("message_access_audit.admin_id", "Yonetici mesaj erisim denetimi, 730 gun"),
            Map.entry("club_audit.actor_id", "Kulup denetim izi, 730 gun"),
            Map.entry("suspend_recommendation.decided_by", "Yonetici karar izi"),
            Map.entry("moderation_appeal.decided_by", "Yonetici karar izi"),
            Map.entry("report.resolved_by", "Yonetici karar izi"),
            Map.entry("event_application.decided_by", "Organizator karar izi"),
            Map.entry("event_attendance.marked_by", "Yoklamayi isaretleyen organizator izi"),
            Map.entry("event_co_organizer.added_by", "Ortak organizator ekleme izi"),
            Map.entry("access_ban.created_by", "Erisim engeli yonetici izi"),
            Map.entry("blocked_content_hash.created_by", "Engelli icerik ozeti yonetici izi"),
            Map.entry("club_invite.created_by", "Kulup davet izi"),
            Map.entry("club_member_grant.updated_by", "Yetki degisiklik izi"),
            Map.entry("community_post.hidden_by", "Moderasyon izi"),
            Map.entry("department_announcement.created_by", "Duyuru yoneticisi izi"),
            Map.entry("mail_campaign.created_by", "Kampanya yoneticisi izi"),
            Map.entry("mail_suppression.created_by", "Posta bastirma yonetici izi"),
            Map.entry("mail_template_custom.created_by", "Sablon yoneticisi izi"),
            Map.entry("mail_template_custom_version.created_by", "Sablon yoneticisi izi"),
            Map.entry("menu_item_calorie.updated_by", "Menu kalori yonetici izi"),
            Map.entry("message_attachment.hidden_by", "Moderasyon izi"),
            Map.entry("moderation_target_state.hidden_by", "Moderasyon izi"),
            Map.entry("profanity_term.created_by", "Uygunsuz ifade listesi yonetici izi"),
            Map.entry("push_campaign.created_by", "Push kampanya yonetici izi"),
            Map.entry("admin_profile_change.proposed_by", "Yonetici yetki degisikligi oneren yonetici izi"),
            Map.entry("conversation.closed_by", "Sohbeti kapatan yonetici/moderator izi"),
            Map.entry("crash_group.status_by", "Cokme grubu durumunu degistiren yonetici izi (anonim cokme verisi)"),
            Map.entry("event_certificate.revoked_by", "Sertifika iptal eden yonetici izi"),
            Map.entry("message.admin_hidden_by", "Moderasyon izi (yonetici gizledi); mesaj saklama suresiyle temizlenir"),
            Map.entry("message.deleted_by", "Silen kisi izi; silinmis mesaj govdesi saklama suresiyle (90 gun) kalici silinir"),
            Map.entry("moderation_strike.forgiven_by", "Ihlal affeden yonetici izi"),
            Map.entry("post.deleted_by", "Yumusak silme izi (PostAccountPurger hesap silmede yazar=silen yazar); dosyalar saklama suresiyle silinir"),
            Map.entry("support_ticket_note.author_id", "Personelin ic notu yazari (yonetici izi, kullanici degil)"),
            Map.entry("user_event.moderated_by", "Etkinlik moderasyonunu yapan yonetici izi"));

    static final String LEAVE_ROOMS =
            "UPDATE conversation_member SET left_at = CURRENT_TIMESTAMP WHERE user_id = ? AND left_at IS NULL";

    /** Adres eslesmeli silme (A11-09c): kuyrukta silinen kisinin adresi; "hesap silindi" postasi kalir. */
    static final String MAIL_BY_ADDRESS =
            "DELETE FROM mail_outbox WHERE LOWER(to_address) = ? AND template <> 'ACCOUNT_DELETED'";

    private final JdbcTemplate jdbc;

    /** Kesfet gonderi/yorum/begeni/medya temizligi (post paketi); testlerde yoksa atlanir. */
    private PostAccountPurger postPurger;

    /** Akademik (ders programi/sinav/duyuru okundu) temizligi; testlerde yoksa atlanir. */
    private edu.bingol.backend.academic.AcademicAccountPurger academicPurger;

    /** Silinen kullanici kimligi yedek disi deftere yazilir (T-064); testlerde yoksa atlanir. */
    private DeletionLedger ledger;

    public AccountDataPurger(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Autowired(required = false)
    void setPostPurger(PostAccountPurger postPurger) {
        this.postPurger = postPurger;
    }

    @Autowired(required = false)
    void setAcademicPurger(edu.bingol.backend.academic.AcademicAccountPurger academicPurger) {
        this.academicPurger = academicPurger;
    }

    @Autowired(required = false)
    void setLedger(DeletionLedger ledger) {
        this.ledger = ledger;
    }

    /** Adres bilinmiyorsa e-posta kuyrugu temizligi atlanir (kod kalintisini gece isi yine siler). */
    public void purge(Long userId) {
        purge(userId, null);
    }

    /**
     * @param oldEmail anonimlestirmeden ONCEKI e-posta (kuyrukta adres eslesmeli silme icin); null olabilir
     */
    public void purge(Long userId, String oldEmail) {
        if (academicPurger != null) {
            academicPurger.purge(userId);
        }
        if (postPurger != null) {
            postPurger.purge(userId);
        }
        DELETES.forEach(sql -> jdbc.update(sql, userId));
        SCRUBS.forEach(sql -> jdbc.update(sql, userId));
        jdbc.update(LEAVE_ROOMS, userId);
        if (oldEmail != null && !oldEmail.isBlank()) {
            jdbc.update(MAIL_BY_ADDRESS, oldEmail.trim().toLowerCase(Locale.ROOT));
        }
        if (ledger != null) {
            // COMMIT sonrasi: islem geri alinirsa canli hesap deftere dusmesin (geri yukleme sonrasi yanlis silme)
            edu.bingol.backend.common.AfterCommit.run(() -> ledger.record(userId));
        }
    }
}
