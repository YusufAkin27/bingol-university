package edu.bingol.backend.mail.campaign;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudiencePreview;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudiencePreviewRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudienceRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.CampaignRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.CampaignView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.Filter;
import edu.bingol.backend.mail.campaign.MailAdminDtos.LangContentRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.PreviewView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.RecipientRow;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TemplateRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TemplateView;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

/** Sablon yasam dongusu, hedef cozumleme, dagitim, tekrar korumasi, duraklat/iptal, saklama (H2, gercek bean'ler). */
@SpringBootTest
@Import(MailCampaignIntegrationTest.GateConfig.class)
class MailCampaignIntegrationTest {

    /** Bastirma kapisi test uygulamasi: BLOCKED icindeki kullanicilar OPTED_OUT sayilir. */
    static final Map<Long, String> BLOCKED = new HashMap<>();

    @TestConfiguration
    static class GateConfig {
        @Bean
        @org.springframework.context.annotation.Primary
        MailSuppressionGate testGate() {
            return (Collection<Long> ids) -> {
                Map<Long, String> out = new HashMap<>();
                ids.stream().filter(BLOCKED::containsKey).forEach(i -> out.put(i, BLOCKED.get(i)));
                return out;
            };
        }
    }

    @Autowired MailTemplateAdminService templates;
    @Autowired MailCampaignAdminService campaigns;
    @Autowired MailCampaignDispatcher dispatcher;
    @Autowired MailCampaignRepository campaignRepo;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;
    @Autowired MailSuppressionGateImpl realGate;
    @Autowired edu.bingol.backend.mail.MailSuppressionService suppression;

    // ---------- yardimcilar ----------

    private User user(String faculty, String lang, UserStatus status, boolean verified) {
        User u = new User();
        u.setEmail("m" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kisi " + lang);
        u.setEmailVerified(verified);
        u.setStatus(status);
        u.setFaculty(faculty);
        u.setDepartment("Bolum A");
        u.setClassYear((short) 2);
        u.setLanguage(lang);
        u.setRole(Role.USER);
        return users.saveAndFlush(u);
    }

    private User user(String faculty, String lang) {
        return user(faculty, lang, UserStatus.ACTIVE, true);
    }

    private static LangContentRequest content(String subject, String html) {
        return new LangContentRequest(subject, html, null);
    }

    private TemplateView publishedTemplate(Long admin, boolean withEn) {
        TemplateView t = templates.create(admin, new TemplateRequest("Duyuru " + UUID.randomUUID(), "aciklama",
                content("Merhaba {{ad}}", "<p>Selam {{ad}} - {{bolum}}</p><script>alert(1)</script>"),
                withEn ? content("Hello {{ad}}", "<p>Hi {{ad}}</p>") : null, null));
        return templates.publish(t.id());
    }

    private CampaignRequest request(Long templateId, Filter filter, Instant when, String key) {
        return new CampaignRequest("Kampanya", templateId, new AudienceRequest(MailCampaign.AudienceType.FILTER, filter, null, null),
                when, key);
    }

    private static Filter faculty(String f) {
        return new Filter(f, null, null, null, null, null);
    }

    private int outboxFor(User u) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM mail_outbox WHERE to_address = ? AND template = 'CUSTOM'",
                Integer.class, u.getEmail());
    }

    private String uniqueFaculty() {
        return "Fak-" + UUID.randomUUID().toString().substring(0, 8);
    }

    // ---------- sablon ----------

    @Test
    void templateIsSanitizedVersionedPublishedAndProtectedFromDeletionWhenUsed() {
        User admin = user(null, "tr");
        TemplateView t = publishedTemplate(admin.getId(), true);
        assertEquals(MailCustomTemplate.Status.PUBLISHED, t.status());
        assertEquals(1, t.version());
        assertFalse(t.tr().html().contains("script"), t.tr().html());
        assertFalse(t.tr().html().contains("alert"), t.tr().html());
        assertEquals(List.of("tr", "en"), t.languages());
        assertTrue(t.variablesUsed().containsAll(List.of("ad", "bolum")));
        assertTrue(t.tr().text().contains("Selam {{ad}}"), "duz metin HTML'den uretilir: " + t.tr().text());

        // ayni icerik: yeni surum yok; degisen icerik: surum 2
        TemplateRequest same = new TemplateRequest("Yeni ad", "x", content("Merhaba {{ad}}", "<p>Selam {{ad}} - {{bolum}}</p>"),
                content("Hello {{ad}}", "<p>Hi {{ad}}</p>"), null);
        assertEquals(1, templates.update(admin.getId(), t.id(), same).version());
        TemplateView v2 = templates.update(admin.getId(), t.id(), new TemplateRequest("Yeni ad", "x",
                content("Degisti {{ad}}", "<p>Yeni {{ad}}</p>"), null, null));
        assertEquals(2, v2.version());
        assertEquals(List.of("tr"), v2.languages());
        assertEquals(2, templates.versions(t.id()).size());
        assertEquals(MailCustomTemplate.Status.PUBLISHED, v2.status());

        // gecersiz icerik reddedilir ve surum olusmaz
        ApiException bad = assertThrows(ApiException.class, () -> templates.update(admin.getId(), t.id(), new TemplateRequest("n", null,
                content("s", "<p>{{telefon}}</p>"), null, null)));
        assertEquals("MAIL_TEMPLATE_VARIABLE_UNKNOWN", bad.code());
        assertEquals(2, templates.get(t.id()).version());

        // kampanyada kullanilmis sablon silinemez; arsivlenince duzenlenemez
        User target = user(uniqueFaculty(), "tr");
        CampaignView c = campaigns.create(admin.getId(), request(t.id(), faculty(target.getFaculty()), null, null));
        assertEquals(2, c.templateVersion());
        assertEquals("MAIL_TEMPLATE_IN_USE", assertThrows(ApiException.class, () -> templates.delete(t.id())).code());
        templates.archive(t.id());
        assertEquals("MAIL_TEMPLATE_NOT_EDITABLE", assertThrows(ApiException.class,
                () -> templates.update(admin.getId(), t.id(), same)).code());
        assertEquals("MAIL_TEMPLATE_NOT_PUBLISHED", assertThrows(ApiException.class,
                () -> campaigns.create(admin.getId(), request(t.id(), faculty("x"), null, null))).code());

        // kullanilmamis sablon silinir
        TemplateView lonely = publishedTemplate(admin.getId(), false);
        templates.delete(lonely.id());
        assertEquals("MAIL_TEMPLATE_NOT_FOUND", assertThrows(ApiException.class, () -> templates.get(lonely.id())).code());
    }

    @Test
    void draftCannotBeDeletedPublishedWithoutTurkishContentAndListFilters() {
        User admin = user(null, "tr");
        TemplateView t = templates.create(admin.getId(), new TemplateRequest("Liste-" + UUID.randomUUID(), null,
                content("S", "<p>x</p>"), null, null));
        assertEquals(MailCustomTemplate.Status.DRAFT, t.status());
        PageResponse<MailAdminDtos.TemplateRow> drafts = templates.list(MailCustomTemplate.Status.DRAFT, t.name().substring(0, 8), 0, 10);
        assertTrue(drafts.items().stream().anyMatch(r -> r.id().equals(t.id())));
        assertTrue(templates.list(MailCustomTemplate.Status.PUBLISHED, "%_zzz", 0, 10).items().isEmpty());
        // LIKE ozel karakterleri kacirilir: yuzde isareti her seyle eslesmez
        assertTrue(templates.list(null, "%", 0, 10).items().stream().noneMatch(r -> !r.name().contains("%")));
    }

    @Test
    void previewRendersRequestedLanguageWithFallbackAndSampleVariables() {
        User admin = user(null, "tr");
        TemplateView t = publishedTemplate(admin.getId(), true);
        PreviewView en = templates.previewStored(t.id(), "en", null);
        assertEquals("en", en.usedLang());
        assertFalse(en.fallback());
        assertEquals("Hello Ayşe Yılmaz", en.subject());
        assertTrue(en.html().contains("<p>Hi Ayşe Yılmaz</p>"));
        PreviewView ar = templates.previewStored(t.id(), "ar", null);
        assertEquals("tr", ar.usedLang());
        assertTrue(ar.fallback());
        assertEquals("Merhaba Ayşe Yılmaz", ar.subject());
        assertTrue(ar.text().contains("Selam Ayşe Yılmaz - Bilgisayar Mühendisliği"));

        PreviewView draft = templates.previewDraft("tr", content("T {{ad}}", "<p onclick=\"x()\">Taslak {{ad}}</p>"));
        assertTrue(draft.html().contains("Taslak Ayşe Yılmaz"));
        assertFalse(draft.html().contains("onclick"));
    }

    @Test
    void testSendGoesOnlyToTheRequestingAdmin() {
        User admin = user(null, "en");
        TemplateView t = publishedTemplate(admin.getId(), true);
        var res = templates.test(admin.getId(), t.id(), "en");
        assertEquals("en", res.usedLang());
        assertTrue(res.to().contains("***@"), res.to());
        assertEquals(1, outboxFor(admin));
    }

    // ---------- hedef cozumleme ----------

    @Test
    void audiencePreviewSkipsInactiveSuppressedAndReportsLanguageDistribution() {
        User admin = user(null, "tr");
        String f = uniqueFaculty();
        User tr1 = user(f, "tr");
        User tr2 = user(f, "tr");
        User en = user(f, "en");
        User ar = user(f, "ar");
        User optedOut = user(f, "tr");
        user(f, "tr", UserStatus.SUSPENDED, true);
        user(f, "tr", UserStatus.ACTIVE, false);
        BLOCKED.put(optedOut.getId(), "OPTED_OUT");
        try {
            TemplateView t = publishedTemplate(admin.getId(), true); // en var, ar yok
            AudiencePreview p = campaigns.previewAudience(new AudiencePreviewRequest(
                    new AudienceRequest(MailCampaign.AudienceType.FILTER, faculty(f), null, null), t.id()));
            assertEquals(5, p.total()); // askidaki ve dogrulanmamis ALL/FILTER'da hic gelmez
            assertEquals(4, p.willSend());
            assertEquals(1, p.skipped());
            assertEquals(1, p.skippedByReason().get("OPTED_OUT"));
            assertEquals(3, p.languages().get("tr")); // tr1, tr2 + ar'den tr'ye dusen
            assertEquals(1, p.languages().get("en"));
            assertEquals(1, p.languageFallback());
            assertNotNull(tr1);
            assertNotNull(tr2);
            assertNotNull(en);
            assertNotNull(ar);
        } finally {
            BLOCKED.remove(optedOut.getId());
        }
    }

    @Test
    void selectedUsersAndEmailsOnlyMatchRegisteredUsersAndMarkIneligibleAsSkipped() {
        User admin = user(null, "tr");
        String f = uniqueFaculty();
        User a = user(f, "tr");
        User suspended = user(f, "tr", UserStatus.SUSPENDED, true);
        AudiencePreview byIds = campaigns.previewAudience(new AudiencePreviewRequest(new AudienceRequest(
                MailCampaign.AudienceType.USERS, null, List.of(a.getId(), suspended.getId(), a.getId(), 99999999L), null), null));
        assertEquals(2, byIds.total());
        assertEquals(1, byIds.willSend());
        assertEquals(1, byIds.skippedByReason().get("INACTIVE"));
        assertEquals(1, byIds.unmatched());

        AudiencePreview byMail = campaigns.previewAudience(new AudiencePreviewRequest(new AudienceRequest(
                MailCampaign.AudienceType.EMAILS, null, null, List.of(a.getEmail().toUpperCase(), " " + a.getEmail() + " ",
                "kayitsiz@bingol.edu.tr", "bozuk-adres", suspended.getEmail())), null));
        assertEquals(2, byMail.total());
        assertEquals(1, byMail.willSend());
        assertEquals(2, byMail.unmatched()); // kayitsiz + bozuk biçim
        // yalniz kayitsiz adres: alici yok
        ApiException none = assertThrows(ApiException.class, () -> campaigns.previewAudience(new AudiencePreviewRequest(
                new AudienceRequest(MailCampaign.AudienceType.EMAILS, null, null, List.of("yok1@bingol.edu.tr")), null)));
        assertEquals("MAIL_CAMPAIGN_NO_RECIPIENTS", none.code());
        // bos filtre gecersiz
        ApiException empty = assertThrows(ApiException.class, () -> campaigns.previewAudience(new AudiencePreviewRequest(
                new AudienceRequest(MailCampaign.AudienceType.FILTER, new Filter(null, null, null, null, null, null), null, null), null)));
        assertEquals("MAIL_CAMPAIGN_AUDIENCE_INVALID", empty.code());
        assertNotNull(admin);
    }

    // ---------- dagitim ----------

    @Test
    void dispatchQueuesEachRecipientExactlyOnceWithCountersAndNoDuplicatesOnRepeat() {
        User admin = user(null, "tr");
        String f = uniqueFaculty();
        User tr1 = user(f, "tr");
        User en = user(f, "en");
        User ar = user(f, "ar");
        user(f, "tr", UserStatus.SUSPENDED, true);
        TemplateView t = publishedTemplate(admin.getId(), true);

        CampaignView c = campaigns.create(admin.getId(), request(t.id(), faculty(f), null, null));
        assertEquals(MailCampaign.Status.DRAFT, c.status());
        // cift tiklama: ikinci zamanlama etkisiz
        CampaignView s1 = campaigns.schedule(c.id(), null);
        CampaignView s2 = campaigns.schedule(c.id(), null);
        assertEquals(MailCampaign.Status.SCHEDULED, s1.status());
        assertEquals(MailCampaign.Status.SCHEDULED, s2.status());

        dispatcher.tick();
        dispatcher.tick(); // tekrar tur: yeni e-posta uretmez
        CampaignView done = campaigns.get(c.id());
        assertEquals(MailCampaign.Status.DONE, done.status());
        assertNotNull(done.finishedAt());
        assertEquals(3, done.counters().target());
        assertEquals(3, done.counters().queued());
        assertEquals(0, done.counters().pending());
        assertEquals(0, done.counters().failed());
        assertEquals(100, done.counters().progressPercent());
        assertEquals(2, done.counters().languages().get("tr")); // tr1 + ar->tr
        assertEquals(1, done.counters().languages().get("en"));
        assertEquals(1, done.counters().languageFallback());
        assertEquals(1, outboxFor(tr1));
        assertEquals(1, outboxFor(en));
        assertEquals(1, outboxFor(ar));
        // ar kullanicisinin kuyruk satiri tr icerikle (dil tr) yazilmis
        assertEquals("tr", jdbc.queryForObject("SELECT lang FROM mail_outbox WHERE to_address = ? AND template = 'CUSTOM'",
                String.class, ar.getEmail()));

        // bitmis kampanya yeniden zamanlansa da tekrar gonderilmez
        assertEquals(MailCampaign.Status.DONE, campaigns.schedule(c.id(), null).status());
        dispatcher.tick();
        assertEquals(1, outboxFor(tr1));

        // alici raporu: adres maskeli
        PageResponse<RecipientRow> rows = campaigns.recipients(c.id(), MailCampaignRecipient.Status.QUEUED, 0, 10);
        assertEquals(3, rows.totalItems());
        assertTrue(rows.items().stream().allMatch(r -> r.email().contains("***@")));
        assertTrue(rows.items().stream().noneMatch(r -> r.email().equals(tr1.getEmail())));
    }

    @Test
    void suppressedRecipientIsSkippedAndCountedNotSent() {
        User admin = user(null, "tr");
        String f = uniqueFaculty();
        User ok = user(f, "tr");
        User late = user(f, "tr");
        TemplateView t = publishedTemplate(admin.getId(), false);
        CampaignView c = campaigns.create(admin.getId(), request(t.id(), faculty(f), null, null));
        campaigns.schedule(c.id(), null);
        BLOCKED.put(late.getId(), "SUPPRESSED"); // cozumden sonra abonelikten cikti
        try {
            // cozumleme bu turda yapilir; gonderim kapisi da ayni turda calisir -> ikisi de atlanir/gonderilir tutarli
            dispatcher.tick();
        } finally {
            BLOCKED.remove(late.getId());
        }
        CampaignView done = campaigns.get(c.id());
        assertEquals(1, done.counters().queued());
        assertEquals(1, done.counters().skipped());
        assertEquals(1, done.counters().skippedByReason().get("SUPPRESSED"));
        assertEquals(1, outboxFor(ok));
        assertEquals(0, outboxFor(late));
    }

    @Test
    void futureScheduleIsNotDispatchedAndPauseResumeCancelWork() {
        User admin = user(null, "tr");
        String f = uniqueFaculty();
        User u1 = user(f, "tr");
        TemplateView t = publishedTemplate(admin.getId(), false);

        // ileri tarih: tur gonderim yapmaz
        CampaignView later = campaigns.create(admin.getId(), request(t.id(), faculty(f), Instant.now().plus(2, ChronoUnit.HOURS), null));
        campaigns.schedule(later.id(), null);
        dispatcher.tick();
        assertEquals(MailCampaign.Status.SCHEDULED, campaigns.get(later.id()).status());
        assertEquals(0, outboxFor(u1));

        // duraklat: zamani gelse de gonderilmez; devam: gonderilir
        CampaignView p = campaigns.pause(later.id());
        assertEquals(MailCampaign.Status.PAUSED, p.status());
        assertEquals(MailCampaign.Status.PAUSED, campaigns.pause(later.id()).status()); // idempotent
        jdbc.update("UPDATE mail_campaign SET scheduled_at = ? WHERE id = ?", java.sql.Timestamp.from(Instant.now().minusSeconds(5)), later.id());
        dispatcher.tick();
        assertEquals(0, outboxFor(u1));
        assertEquals(MailCampaign.Status.SCHEDULED, campaigns.resume(later.id()).status()); // cozulmemis: zamanlandiya doner
        dispatcher.tick();
        assertEquals(MailCampaign.Status.DONE, campaigns.get(later.id()).status());
        assertEquals(1, outboxFor(u1));
        assertEquals("MAIL_CAMPAIGN_INVALID_STATE", assertThrows(ApiException.class, () -> campaigns.cancel(later.id())).code());

        // iptal: bekleyen alicilar CANCELLED olur, hicbir sey gonderilmez
        String f2 = uniqueFaculty();
        User u2 = user(f2, "tr");
        CampaignView toCancel = campaigns.create(admin.getId(), request(t.id(), faculty(f2), null, null));
        campaigns.schedule(toCancel.id(), null);
        CampaignView cancelled = campaigns.cancel(toCancel.id());
        assertEquals(MailCampaign.Status.CANCELLED, cancelled.status());
        assertEquals(MailCampaign.Status.CANCELLED, campaigns.cancel(toCancel.id()).status()); // idempotent
        dispatcher.tick();
        assertEquals(0, outboxFor(u2));
        assertEquals("MAIL_CAMPAIGN_INVALID_STATE", assertThrows(ApiException.class, () -> campaigns.resume(toCancel.id())).code());
    }

    @Test
    void sendingCampaignCancelledMidwayLeavesPendingRecipientsCancelled() {
        User admin = user(null, "tr");
        String f = uniqueFaculty();
        User u1 = user(f, "tr");
        User u2 = user(f, "tr");
        TemplateView t = publishedTemplate(admin.getId(), false);
        CampaignView c = campaigns.create(admin.getId(), request(t.id(), faculty(f), null, null));
        campaigns.schedule(c.id(), null);
        // dagiticiyi aliciyi cozdukten hemen sonrasina getir: parti boyutunu atlayip elle durum degistir
        MailCampaign entity = campaignRepo.findById(c.id()).orElseThrow();
        entity.setStatus(MailCampaign.Status.SENDING);
        entity.setStartedAt(Instant.now());
        campaignRepo.save(entity);
        dispatcher.resolve(campaignRepo.findById(c.id()).orElseThrow());
        CampaignView cancelled = campaigns.cancel(c.id());
        assertEquals(2, cancelled.counters().cancelled());
        dispatcher.tick();
        assertEquals(0, outboxFor(u1) + outboxFor(u2));
        assertEquals(MailCampaign.Status.CANCELLED, campaigns.get(c.id()).status());
    }

    // ---------- kayit kurallari ----------

    @Test
    void requestKeyMakesCreateIdempotentAndOnlyDraftsAreEditable() {
        User admin = user(null, "tr");
        String f = uniqueFaculty();
        user(f, "tr");
        TemplateView t = publishedTemplate(admin.getId(), false);
        String key = "k-" + UUID.randomUUID();
        CampaignView a = campaigns.create(admin.getId(), request(t.id(), faculty(f), null, key));
        CampaignView b = campaigns.create(admin.getId(), request(t.id(), faculty(f), null, key));
        assertEquals(a.id(), b.id());

        CampaignView renamed = campaigns.update(a.id(), new CampaignRequest("Yeni ad", t.id(),
                new AudienceRequest(MailCampaign.AudienceType.FILTER, faculty(f), null, null), null, key));
        assertEquals("Yeni ad", renamed.name());
        campaigns.schedule(a.id(), null);
        assertEquals("MAIL_CAMPAIGN_NOT_EDITABLE", assertThrows(ApiException.class, () -> campaigns.update(a.id(),
                new CampaignRequest("x", t.id(), new AudienceRequest(MailCampaign.AudienceType.FILTER, faculty(f), null, null),
                        null, key))).code());
        assertEquals("MAIL_CAMPAIGN_NOT_FOUND", assertThrows(ApiException.class, () -> campaigns.get(987654321L)).code());
        assertEquals("MAIL_CAMPAIGN_SCHEDULE_INVALID", assertThrows(ApiException.class, () -> campaigns.create(admin.getId(),
                request(t.id(), faculty(f), Instant.now().plus(200, ChronoUnit.DAYS), null))).code());
    }

    @Test
    void schedulingWithNoRecipientsIsRejected() {
        User admin = user(null, "tr");
        TemplateView t = publishedTemplate(admin.getId(), false);
        CampaignView c = campaigns.create(admin.getId(), request(t.id(), faculty(uniqueFaculty()), null, null));
        assertEquals("MAIL_CAMPAIGN_NO_RECIPIENTS", assertThrows(ApiException.class, () -> campaigns.schedule(c.id(), null)).code());
        assertEquals(MailCampaign.Status.DRAFT, campaigns.get(c.id()).status());
    }

    // ---------- KVKK ----------

    @Test
    void campaignRowsStoreUserIdsNotEmailsAndAccountPurgeAndRetentionRemoveThem() throws Exception {
        User admin = user(null, "tr");
        String f = uniqueFaculty();
        User u = user(f, "tr");
        TemplateView t = publishedTemplate(admin.getId(), false);
        CampaignView made = campaigns.create(admin.getId(), new CampaignRequest("kvkk", t.id(),
                new AudienceRequest(MailCampaign.AudienceType.EMAILS, null, null, List.of(u.getEmail())), null, null));
        MailCampaign stored = campaignRepo.findById(made.id()).orElseThrow();
        assertEquals(String.valueOf(u.getId()), stored.getAudienceValue()); // e-posta metni degil, kimlik
        assertFalse(stored.getAudienceValue().contains("@"));
        campaigns.schedule(made.id(), null);
        dispatcher.tick();
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM mail_campaign_recipient WHERE user_id = ?", Integer.class, u.getId()));

        // hesap silme SQL'i
        java.lang.reflect.Field fld = edu.bingol.backend.profile.AccountDataPurger.class.getDeclaredField("DELETES");
        fld.setAccessible(true);
        @SuppressWarnings("unchecked")
        List<String> sqls = (List<String>) fld.get(null);
        sqls.stream().filter(s -> s.contains("mail_campaign_recipient")).forEach(s -> jdbc.update(s, u.getId()));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM mail_campaign_recipient WHERE user_id = ?", Integer.class, u.getId()));

        // saklama suresi: 180 gunden eski biten kampanya ve alicilari silinir, yeni olan kalir
        jdbc.update("UPDATE mail_campaign SET finished_at = ? WHERE id = ?", java.sql.Timestamp.from(Instant.now().minus(200, ChronoUnit.DAYS)), made.id());
        int removed = dispatcher.purge(Instant.now());
        assertTrue(removed >= 1);
        assertTrue(campaignRepo.findById(made.id()).isEmpty());
    }

    @Test
    void realGateMapsMailSuppressionListToSuppressed() {
        User a = user(uniqueFaculty(), "tr");
        User b = user(uniqueFaculty(), "tr");
        suppression.suppress(a.getEmail(), edu.bingol.backend.mail.SuppressionReason.UNSUBSCRIBED);
        Map<Long, String> blocked = realGate.blocked(List.of(a.getId(), b.getId()));
        assertEquals(Map.of(a.getId(), "SUPPRESSED"), blocked);
    }
}
