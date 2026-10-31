package edu.bingol.backend.notification.campaign;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.notification.campaign.CampaignDtos.Audience;
import edu.bingol.backend.notification.campaign.CampaignDtos.AudiencePreview;
import edu.bingol.backend.notification.campaign.CampaignDtos.Content;
import edu.bingol.backend.notification.campaign.CampaignDtos.CreateCampaignRequest;
import edu.bingol.backend.notification.campaign.CampaignDtos.SendRequest;
import edu.bingol.backend.notification.campaign.CampaignDtos.Target;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Yonetici bildirim gonderimi: kitle cozumleme, secili kullanicilar, tercih/askida atlama, tekillestirme, zamanlama (H2). */
@SpringBootTest
class CampaignAdminSendTest {

    @Autowired CampaignService service;
    @Autowired PushCampaignRepository campaigns;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;

    private User user(String faculty, String lang) {
        User u = new User();
        u.setEmail("c" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Kisi " + u.getEmail().substring(0, 4));
        u.setEmailVerified(true);
        u.setFaculty(faculty);
        u.setLanguage(lang);
        return users.saveAndFlush(u);
    }

    private static CreateCampaignRequest req(Audience a, String title) {
        return new CreateCampaignRequest(NotificationType.ANNOUNCEMENT, a, new Content(title, "Govde"), null, null,
                null, null);
    }

    private void pref(User u, boolean announcements) {
        jdbc.update("INSERT INTO notification_pref (user_id, news, announcements, events, messages, communities,"
                + " quiet_enabled, quiet_start, quiet_end, timezone) VALUES (?, ?, ?, ?, ?, ?, false, 1320, 420,"
                + " 'Europe/Istanbul')", u.getId(), announcements, announcements, announcements, announcements,
                announcements);
    }

    private int inbox(User u) {
        return jdbc.queryForObject("SELECT count(*) FROM notification WHERE user_id = ?", Integer.class, u.getId());
    }

    @Test
    void selectedUsersEmailsAndIdsAreResolvedDedupedAndPinnedToIds() {
        User admin = user("F", "tr");
        User a = user("F", "tr");
        User b = user("F", "en");
        String list = a.getEmail().toUpperCase() + "\n" + b.getEmail() + ", " + a.getEmail() + " " + b.getId()
                + " yok@bingol.edu.tr bozuk";
        AudiencePreview p = service.preview(admin.getId(), new Audience(PushCampaign.AudienceType.EMAILS, list), null);
        assertEquals(2, p.count()); // e-posta + numara + tekrar -> tekil 2 kisi
        assertEquals(1, p.byLanguage().get("en"));
        assertEquals(1, p.byLanguage().get("tr"));
        assertTrue(p.notFound().contains("yok@bingol.edu.tr"));
        assertTrue(p.notFound().contains("bozuk"));

        PushCampaign c = service.create(admin.getId(), req(new Audience(PushCampaign.AudienceType.EMAILS, list), "T1"));
        assertEquals(PushCampaign.AudienceType.USERS, c.getAudienceType()); // e-postalar kimliklere sabitlendi
        assertEquals(a.getId() < b.getId() ? a.getId() + "," + b.getId() : b.getId() + "," + a.getId(),
                c.getAudienceValue());
    }

    @Test
    void dispatchSkipsOptedOutSuspendedAndDeletedAndCountsSkipped() {
        User admin = user("F2", "tr");
        User ok = user("F2", "tr");
        User optedOut = user("F2", "tr");
        User suspended = user("F2", "tr");
        suspended.setStatus(UserStatus.SUSPENDED);
        users.saveAndFlush(suspended);
        User deleted = user("F2", "tr");
        deleted.setStatus(UserStatus.DELETED);
        users.saveAndFlush(deleted);
        pref(optedOut, false);

        PushCampaign c = service.create(admin.getId(), req(new Audience(PushCampaign.AudienceType.FACULTY, "F2"), "T2"));
        AudiencePreview p = service.preview(admin.getId(), new Audience(PushCampaign.AudienceType.FACULTY, "F2"), null);
        assertEquals(3, p.count()); // admin + ok + optedOut (askida/silinmis yok)
        assertEquals(1, p.optedOut());

        service.dispatch(c.getId());
        PushCampaign done = campaigns.findById(c.getId()).orElseThrow();
        assertEquals(PushCampaign.Status.SENT, done.getStatus());
        assertEquals(3, done.getAudienceSize());
        assertEquals(2, done.getRecipientCount());
        assertEquals(1, inbox(ok));
        assertEquals(0, inbox(optedOut));
        assertEquals(0, inbox(suspended));
        assertEquals(0, inbox(deleted));
    }

    @Test
    void systemTypeBypassesPreferences() {
        User admin = user("F3", "tr");
        User optedOut = user("F3", "tr");
        pref(optedOut, false);
        AudiencePreview p = service.preview(admin.getId(), new Audience(PushCampaign.AudienceType.FACULTY, "F3"),
                NotificationType.SYSTEM);
        assertEquals(0, p.optedOut());
        PushCampaign c = service.create(admin.getId(), new CreateCampaignRequest(NotificationType.SYSTEM,
                new Audience(PushCampaign.AudienceType.FACULTY, "F3"), new Content("Sistem", "G"), null, null, null, null));
        service.dispatch(c.getId());
        assertEquals(1, inbox(optedOut));
    }

    @Test
    void languageAudienceAndInvalidValues() {
        User admin = user("F4", "tr");
        user("F4", "ar");
        AudiencePreview p = service.preview(admin.getId(), new Audience(PushCampaign.AudienceType.LANGUAGE, "AR"), null);
        assertTrue(p.count() >= 1);
        assertEquals(p.count(), p.byLanguage().get("ar"));
        ApiException e = assertThrows(ApiException.class,
                () -> service.preview(admin.getId(), new Audience(PushCampaign.AudienceType.LANGUAGE, "de"), null));
        assertEquals("INVALID_AUDIENCE", e.code());
        assertThrows(ApiException.class,
                () -> service.preview(admin.getId(), new Audience(PushCampaign.AudienceType.FACULTY, " "), null));
        assertThrows(ApiException.class,
                () -> service.preview(admin.getId(), new Audience(PushCampaign.AudienceType.EMAILS, "   "), null));
    }

    @Test
    void duplicateCampaignIsRejectedWithinWindowButNotAfterCancel() {
        User admin = user("F5", "tr");
        user("F5", "tr");
        Audience a = new Audience(PushCampaign.AudienceType.FACULTY, "F5");
        PushCampaign first = service.create(admin.getId(), req(a, "Ayni"));
        ApiException e = assertThrows(ApiException.class, () -> service.create(admin.getId(), req(a, "Ayni")));
        assertEquals("CAMPAIGN_DUPLICATE", e.code());
        service.cancel(first.getId());
        assertNotNull(service.create(admin.getId(), req(a, "Ayni")));
    }

    @Test
    void emptyAudienceIsRejected() {
        User admin = user("F6", "tr");
        ApiException e = assertThrows(ApiException.class, () -> service.create(admin.getId(),
                req(new Audience(PushCampaign.AudienceType.FACULTY, "YOK-FAKULTE"), "X")));
        assertEquals("NO_RECIPIENTS", e.code());
    }

    @Test
    void scheduleWindowAndPauseResumeCancelRules() {
        User admin = user("F7", "tr");
        user("F7", "tr");
        Audience a = new Audience(PushCampaign.AudienceType.FACULTY, "F7");
        CreateCampaignRequest tooFar = new CreateCampaignRequest(null, a, new Content("Z", "Z"), null, null, null,
                Instant.now().plus(31, ChronoUnit.DAYS));
        assertEquals("VALIDATION_ERROR",
                assertThrows(ApiException.class, () -> service.create(admin.getId(), tooFar)).code());

        CreateCampaignRequest later = new CreateCampaignRequest(null, a, new Content("Sonra", "Z"), null, null, null,
                Instant.now().plus(2, ChronoUnit.DAYS));
        PushCampaign c = service.create(admin.getId(), later);
        assertEquals(PushCampaign.Status.SCHEDULED, c.getStatus());
        assertTrue(c.getScheduledAt().isAfter(Instant.now().plus(1, ChronoUnit.DAYS)));

        service.pause(c.getId());
        assertEquals(PushCampaign.Status.PAUSED, campaigns.findById(c.getId()).orElseThrow().getStatus());
        assertEquals("CAMPAIGN_NOT_PAUSABLE", assertThrows(ApiException.class, () -> service.pause(c.getId())).code());
        service.resume(c.getId());
        assertEquals("CAMPAIGN_NOT_RESUMABLE", assertThrows(ApiException.class, () -> service.resume(c.getId())).code());
        service.pause(c.getId());
        service.cancel(c.getId()); // duraklatilmis da iptal edilebilir
        assertEquals(PushCampaign.Status.CANCELLED, campaigns.findById(c.getId()).orElseThrow().getStatus());
    }

    @Test
    void targetsMustBeHttpsOrNumericIds() {
        User admin = user("F8", "tr");
        user("F8", "tr");
        Audience a = new Audience(PushCampaign.AudienceType.FACULTY, "F8");
        Target[] bads = {new Target(PushCampaign.TargetType.URL, "http://x.com"),
                new Target(PushCampaign.TargetType.URL, "javascript:alert(1)"),
                new Target(PushCampaign.TargetType.POLL, "abc"), new Target(PushCampaign.TargetType.EVENT, null)};
        for (Target bad : bads) {
            CreateCampaignRequest r = new CreateCampaignRequest(null, a, new Content("H" + bad.type(), "G"), null,
                    null, bad, null);
            assertEquals("VALIDATION_ERROR",
                    assertThrows(ApiException.class, () -> service.create(admin.getId(), r)).code());
        }
        CreateCampaignRequest ok = new CreateCampaignRequest(null, a, new Content("Anket", "G"), null, null,
                new Target(PushCampaign.TargetType.POLL, "12"), null);
        assertEquals(PushCampaign.TargetType.POLL, service.create(admin.getId(), ok).getTargetType());
    }

    @Test
    void testSendGoesOnlyToAdminAndQuickSendOnlyToChosenUser() {
        User admin = user("F9", "tr");
        User other = user("F9", "tr");
        SendRequest sr = new SendRequest(null, new Content("Deneme", "Metin"), null, null, null);

        PushCampaign t = service.createTest(admin.getId(), sr);
        assertEquals(PushCampaign.Source.TEST, t.getSource());
        assertEquals(PushCampaign.AudienceType.SELF, t.getAudienceType());
        service.dispatch(t.getId());
        assertEquals(1, inbox(admin));
        assertEquals(0, inbox(other));
        assertNotNull(service.createTest(admin.getId(), sr)); // test tekrar edilebilir (cift gonderim korumasi yok)

        PushCampaign q = service.createQuick(admin.getId(), other.getId(), sr);
        assertEquals(PushCampaign.Source.QUICK, q.getSource());
        service.dispatch(q.getId());
        assertEquals(1, inbox(other));
        assertEquals(1, inbox(admin));

        ApiException e = assertThrows(ApiException.class, () -> service.createQuick(admin.getId(), 99999999L, sr));
        assertEquals("NO_RECIPIENTS", e.code());
    }

    @Test
    void listFiltersByStatus() {
        User admin = user("F10", "tr");
        admin.setRole(Role.ADMIN);
        users.saveAndFlush(admin);
        PushCampaign c = service.create(admin.getId(),
                req(new Audience(PushCampaign.AudienceType.ADMINS, null), "Yonetici"));
        service.cancel(c.getId());
        var page = service.list(null, 50, PushCampaign.Status.CANCELLED);
        assertTrue(page.items().stream().anyMatch(v -> v.id().equals(c.getId())));
        assertTrue(page.items().stream().allMatch(v -> v.status() == PushCampaign.Status.CANCELLED));
    }
    // ---- W2-C / A14-09: eszamanli ayni kampanya -> tam 1 basari + 1 CAMPAIGN_DUPLICATE; https dogrulamasi once ----

    @Test
    void concurrentIdenticalCampaignsCreateExactlyOne() throws Exception {
        User admin = user("F", "tr");
        user("F", "tr");
        CreateCampaignRequest r = req(new Audience(PushCampaign.AudienceType.ALL, null), "Cift " + UUID.randomUUID());
        int n = 6;
        java.util.concurrent.ExecutorService pool = java.util.concurrent.Executors.newFixedThreadPool(n);
        java.util.concurrent.CountDownLatch start = new java.util.concurrent.CountDownLatch(1);
        java.util.List<java.util.concurrent.Future<String>> res = new java.util.ArrayList<>();
        for (int i = 0; i < n; i++) {
            res.add(pool.submit(() -> {
                start.await();
                try {
                    service.create(admin.getId(), r);
                    return "OK";
                } catch (ApiException e) {
                    return e.code();
                }
            }));
        }
        start.countDown();
        int ok = 0;
        int dup = 0;
        for (var f : res) {
            String v = f.get(30, java.util.concurrent.TimeUnit.SECONDS);
            if (v.equals("OK")) {
                ok++;
            } else if (v.equals("CAMPAIGN_DUPLICATE")) {
                dup++;
            }
        }
        pool.shutdownNow();
        assertEquals(1, ok);
        assertEquals(n - 1, dup);
        assertEquals(1L, jdbc.queryForObject("SELECT count(*) FROM push_campaign WHERE created_by = ?", Long.class,
                admin.getId()));
    }

    @Test
    void invalidHttpTargetIsRejectedBeforeDuplicateCheck() {
        User admin = user("F", "tr");
        user("F", "tr");
        String title = "Url " + UUID.randomUUID();
        service.create(admin.getId(), req(new Audience(PushCampaign.AudienceType.ALL, null), title));
        CreateCampaignRequest bad = new CreateCampaignRequest(NotificationType.ANNOUNCEMENT,
                new Audience(PushCampaign.AudienceType.ALL, null), new Content(title, "Govde"), null, null,
                new Target(PushCampaign.TargetType.URL, "http://x.example"), null);

        ApiException e = assertThrows(ApiException.class, () -> service.create(admin.getId(), bad));

        assertEquals("VALIDATION_ERROR", e.code()); // 409 (duplicate) ile maskelenmez
    }
}
