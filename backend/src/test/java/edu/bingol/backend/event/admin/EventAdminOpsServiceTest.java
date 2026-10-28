package edu.bingol.backend.event.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.event.EventAttendance;
import edu.bingol.backend.event.EventAttendanceRepository;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminApplicationPage;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminAttendanceRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminAttendanceView;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminCertificateRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminFeedbackPage;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminFeedbackRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminOrganizerRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.ApplicationDecision;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AttendanceMarkResult;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkAction;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkResult;
import edu.bingol.backend.event.admission.EventAdmission;
import edu.bingol.backend.event.admission.EventAdmissionRepository;
import edu.bingol.backend.event.admission.EventApplication;
import edu.bingol.backend.event.admission.EventApplicationRepository;
import edu.bingol.backend.event.chat.EventChatService;
import edu.bingol.backend.event.extras.CertificateService;
import edu.bingol.backend.event.extras.CoOrganizer;
import edu.bingol.backend.event.extras.CoOrganizerRepository;
import edu.bingol.backend.event.extras.EventAnnouncement;
import edu.bingol.backend.event.extras.EventCertificate;
import edu.bingol.backend.event.extras.EventFeedback;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.io.StringWriter;
import java.lang.reflect.RecordComponent;
import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** P07: yonetici etkinlik derin yonetimi servis kurallari (H2, gercek bean'ler). */
@SpringBootTest
class EventAdminOpsServiceTest {

    @Autowired EventAdminOpsService ops;
    @Autowired EventAdminBulkService bulk;
    @Autowired EventAdminCsvService csv;
    @Autowired CertificateService certificateService;
    @Autowired UserEventRepository events;
    @Autowired UserRepository users;
    @Autowired EventRsvpRepository rsvps;
    @Autowired EventAttendanceRepository attendance;
    @Autowired EventAdmissionRepository admissions;
    @Autowired EventApplicationRepository applications;
    @Autowired AdminCertificateRepository certificates;
    @Autowired AdminFeedbackLookupRepository feedbackRepo;
    @Autowired AdminAnnouncementRepository announcementRepo;
    @Autowired CoOrganizerRepository coOrganizers;

    @MockitoBean NotificationService notifications;
    @MockitoBean RoomConversations rooms;
    @MockitoBean EventChatService chat;

    private static final Long ADMIN = 4242L;

    @BeforeEach
    void resetMocks() {
        reset(notifications, rooms, chat);
    }

    private User user(String name) {
        User u = new User();
        u.setEmail("e" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    /** Baslangici 10 dk once, bitisi 2 saat sonra (yoklama penceresi acik). */
    private UserEvent liveEvent(User owner, Integer capacity) {
        UserEvent e = new UserEvent();
        e.setTitle("Etkinlik " + UUID.randomUUID().toString().substring(0, 6));
        e.setStartsAt(Instant.now().minus(Duration.ofMinutes(10)));
        e.setEndsAt(Instant.now().plus(Duration.ofHours(2)));
        e.setCreatedBy(owner.getId());
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setCapacity(capacity);
        return events.saveAndFlush(e);
    }

    private UserEvent futureEvent(User owner, Integer capacity, boolean approval) {
        UserEvent e = new UserEvent();
        e.setTitle("Gelecek " + UUID.randomUUID().toString().substring(0, 6));
        e.setStartsAt(Instant.now().plus(Duration.ofDays(3)));
        e.setEndsAt(Instant.now().plus(Duration.ofDays(3)).plus(Duration.ofHours(2)));
        e.setCreatedBy(owner.getId());
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setCapacity(capacity);
        UserEvent saved = events.saveAndFlush(e);
        if (approval) {
            EventAdmission cfg = new EventAdmission(saved.getId());
            cfg.setMode(EventAdmission.Mode.APPROVAL);
            admissions.saveAndFlush(cfg);
        }
        return saved;
    }

    private EventApplication apply(UserEvent e, User u, EventApplication.Status st) {
        EventApplication a = new EventApplication(e.getId(), u.getId());
        a.setStatus(st);
        a.setNote("Not " + u.getDisplayName());
        if (st == EventApplication.Status.WAITLISTED) {
            a.setQueuedAt(Instant.now());
        }
        return applications.saveAndFlush(a);
    }

    private static ApiException fail(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    // ---- basvurular ----

    @Test
    void applicationListIsFilteredPagedMaskedAndShowsCapacity() {
        User owner = user("Sahip");
        User a = user("Ayse");
        User b = user("Berk");
        User c = user("Can");
        UserEvent e = futureEvent(owner, 5, true);
        apply(e, a, EventApplication.Status.PENDING);
        apply(e, b, EventApplication.Status.WAITLISTED);
        apply(e, c, EventApplication.Status.REJECTED);

        AdminApplicationPage all = ops.applications(e.getId(), null, null, 50);
        assertEquals(3, all.items().size());
        assertEquals("APPROVAL", all.summary().mode());
        assertEquals(5, all.summary().capacity());
        assertEquals(5, all.summary().seatsLeft());
        assertEquals(1, all.summary().pending());
        assertEquals(1, all.summary().waitlisted());
        assertEquals(1, all.summary().rejected());
        // e-posta HER ZAMAN maskeli
        for (var r : all.items()) {
            assertTrue(r.emailMasked().matches("e\\*\\*\\*@bingol\\.edu\\.tr"), r.emailMasked());
        }
        AdminApplicationPage waiting = ops.applications(e.getId(), "waitlisted", null, 50);
        assertEquals(1, waiting.items().size());
        assertEquals(b.getId(), waiting.items().get(0).userId());
        // sayfalama
        AdminApplicationPage p1 = ops.applications(e.getId(), "ALL", null, 2);
        assertEquals(2, p1.items().size());
        assertTrue(p1.nextCursor() != null);
        AdminApplicationPage p2 = ops.applications(e.getId(), "ALL", p1.nextCursor(), 2);
        assertEquals(1, p2.items().size());
        assertNull(p2.nextCursor());
        assertEquals("VALIDATION_ERROR", fail(() -> ops.applications(e.getId(), "BOGUS", null, 10)).code());
        assertEquals("EVENT_NOT_FOUND", fail(() -> ops.applications(987654321L, null, null, 10)).code());
    }

    @Test
    void forcedAcceptNeverExceedsCapacityAndRejectPromotesWaitlist() {
        User owner = user("Sahip");
        User a = user("Ayse");
        User b = user("Berk");
        User c = user("Can");
        UserEvent e = futureEvent(owner, 1, true);
        apply(e, a, EventApplication.Status.PENDING);
        apply(e, b, EventApplication.Status.PENDING);
        apply(e, c, EventApplication.Status.WAITLISTED);

        ApplicationDecision d = ops.accept(ADMIN, e.getId(), a.getId());
        assertEquals(EventApplication.Status.ACCEPTED, d.status());
        assertEquals(1, d.summary().goingCount());
        assertEquals(0, d.summary().seatsLeft());
        verify(notifications).sendTemplated(eq(a.getId()), eq(NotificationType.EVENT), eq("notif.admission.accepted"),
                anyMap(), eq(e.getTitle()));

        // kapasite dolu: ikinci kabul 409 EVENT_FULL, basvuru PENDING kalir, sayac asilmaz
        ApiException full = fail(() -> ops.accept(ADMIN, e.getId(), b.getId()));
        assertEquals("EVENT_FULL", full.code());
        assertEquals(409, full.status().value());
        assertEquals(EventApplication.Status.PENDING, applications.findByEventIdAndUserId(e.getId(), b.getId()).orElseThrow().getStatus());
        assertEquals(1, events.findById(e.getId()).orElseThrow().getGoingCount());
        // bekleme listesindeki de dolu etkinlikte zorla kabul edilemez
        assertEquals("EVENT_FULL", fail(() -> ops.accept(ADMIN, e.getId(), c.getId())).code());

        // kabul edilmisi zorla reddet: koltuk bosalir, siradaki (bekleme listesi) otomatik terfi eder
        ApplicationDecision r = ops.reject(ADMIN, e.getId(), a.getId());
        assertEquals(EventApplication.Status.REJECTED, r.status());
        assertEquals(EventApplication.Status.ACCEPTED, applications.findByEventIdAndUserId(e.getId(), c.getId()).orElseThrow().getStatus());
        assertEquals(1, events.findById(e.getId()).orElseThrow().getGoingCount());
        assertEquals(1, r.summary().accepted());
        // gecersiz gecis: reddedilmis tekrar kabul edilemez
        assertEquals("INVALID_APPLICATION_STATE", fail(() -> ops.accept(ADMIN, e.getId(), a.getId())).code());
        // olmayan basvuru
        assertEquals("APPLICATION_NOT_FOUND", fail(() -> ops.accept(ADMIN, e.getId(), 987654321L)).code());
    }

    @Test
    void writesNeedARealAdminAccountNotBasicAuth() {
        User owner = user("Sahip");
        User a = user("Ayse");
        UserEvent e = futureEvent(owner, null, true);
        apply(e, a, EventApplication.Status.PENDING);
        ApiException x = fail(() -> ops.accept(null, e.getId(), a.getId()));
        assertEquals("EVENT_ADMIN_ACCOUNT_REQUIRED", x.code());
        assertEquals(403, x.status().value());
        assertEquals("EVENT_ADMIN_ACCOUNT_REQUIRED", fail(() -> ops.reject(null, e.getId(), a.getId())).code());
        assertEquals("EVENT_ADMIN_ACCOUNT_REQUIRED", fail(() -> ops.mark(null, e.getId(), a.getId(), true)).code());
        assertEquals(EventApplication.Status.PENDING, applications.findByEventIdAndUserId(e.getId(), a.getId()).orElseThrow().getStatus());
    }

    // ---- yoklama + sertifika ----

    @Test
    void attendanceListSummaryAndManualCorrection() {
        User owner = user("Sahip");
        User ali = user("Ali");
        User veli = user("Veli");
        User gelmeyen = user("Zeynep");
        User kapidan = user("Kapidan");
        UserEvent e = liveEvent(owner, null);
        for (User u : List.of(ali, veli, gelmeyen)) {
            rsvps.saveAndFlush(new EventRsvp(e.getId(), u.getId(), EventRsvp.Status.GOING));
        }

        AttendanceMarkResult r1 = ops.mark(ADMIN, e.getId(), ali.getId(), true);
        assertTrue(r1.present());
        assertFalse(r1.certificateExists());
        ops.mark(ADMIN, e.getId(), veli.getId(), false);
        ops.mark(ADMIN, e.getId(), kapidan.getId(), true); // RSVP'siz, kapidan (OPEN etkinlik)

        AdminAttendanceView v = ops.attendance(e.getId());
        assertEquals(4, v.rows().size());
        assertEquals(3, v.summary().going());
        assertEquals(2, v.summary().present());
        assertEquals(1, v.summary().absent());
        assertEquals(1, v.summary().unmarked());
        assertEquals(1, v.summary().walkIns());
        assertFalse(v.truncated());
        AdminAttendanceRow aliRow = v.rows().stream().filter(r -> r.userId().equals(ali.getId())).findFirst().orElseThrow();
        assertEquals(Boolean.TRUE, aliRow.present());
        assertEquals(EventAttendance.Method.MANUAL, aliRow.method());
        assertEquals(ADMIN, aliRow.markedBy());
        assertEquals("GOING", aliRow.rsvp());
        assertTrue(aliRow.emailMasked().endsWith("@bingol.edu.tr") && aliRow.emailMasked().contains("***"));
        assertEquals("WALK_IN", v.rows().stream().filter(r -> r.userId().equals(kapidan.getId())).findFirst().orElseThrow().rsvp());
        assertNull(v.rows().stream().filter(r -> r.userId().equals(gelmeyen.getId())).findFirst().orElseThrow().present());

        // duzeltme: ters cevirme
        ops.mark(ADMIN, e.getId(), ali.getId(), false);
        assertEquals(1, ops.attendance(e.getId()).summary().present());
        // pencere kapali (gelecek etkinlik): AttendanceService kurali
        UserEvent later = futureEvent(owner, null, false);
        assertEquals("CHECKIN_CLOSED", fail(() -> ops.mark(ADMIN, later.getId(), ali.getId(), true)).code());
        assertEquals("USER_NOT_FOUND", fail(() -> ops.mark(ADMIN, e.getId(), 987654321L, true)).code());
    }

    @Test
    void attendanceCorrectionAffectsCertificateValidityAndRevokeIsFinalUntilRestored() {
        User owner = user("Sahip");
        User ali = user("Ali");
        UserEvent e = liveEvent(owner, null);
        rsvps.saveAndFlush(new EventRsvp(e.getId(), ali.getId(), EventRsvp.Status.GOING));
        ops.mark(ADMIN, e.getId(), ali.getId(), true);
        EventCertificate c = new EventCertificate();
        c.setEventId(e.getId());
        c.setUserId(ali.getId());
        c.setCode("ABCDEFGHIJKLMNOPQRST");
        c.setHolderName("Ali");
        certificates.saveAndFlush(c);
        assertTrue(certificateService.verify("ABCDEFGHIJKLMNOPQRST").valid());

        // "yok" duzeltmesi sertifikayi gecersiz kilar (kayit silinmez), "var" geri getirir
        AttendanceMarkResult off = ops.mark(ADMIN, e.getId(), ali.getId(), false);
        assertTrue(off.certificateExists());
        assertFalse(off.certificateValid());
        assertFalse(certificateService.verify("ABCDEFGHIJKLMNOPQRST").valid());
        AttendanceMarkResult on = ops.mark(ADMIN, e.getId(), ali.getId(), true);
        assertTrue(on.certificateValid());
        assertTrue(certificateService.verify("ABCDEFGHIJKLMNOPQRST").valid());

        // liste: kod ipucu (tam kod degil), e-posta maskeli
        CursorPage<AdminCertificateRow> page = ops.certificates(e.getId(), null, 50);
        assertEquals(1, page.items().size());
        AdminCertificateRow row = page.items().get(0);
        assertEquals("ABCD...QRST", row.codeHint());
        assertTrue(row.valid());
        assertFalse(row.revoked());

        // iptal: dogrulama gecersiz, kullanici yeniden duzenleyemez, ikinci iptal 409
        AdminCertificateRow revoked = ops.revokeCertificate(ADMIN, e.getId(), ali.getId(), "  sahte katilim ");
        assertTrue(revoked.revoked());
        assertFalse(revoked.valid());
        assertEquals("sahte katilim", revoked.revokeReason().trim());
        assertEquals(ADMIN, revoked.revokedBy());
        assertFalse(certificateService.verify("ABCDEFGHIJKLMNOPQRST").valid());
        assertEquals("CERTIFICATE_REVOKED", fail(() -> certificateService.issue(
                new edu.bingol.backend.community.Actor(ali.getId(), false), e.getId())).code());
        assertEquals("CERTIFICATE_REVOKED", fail(() -> ops.revokeCertificate(ADMIN, e.getId(), ali.getId(), "x")).code());
        // iptal durumunda yoklamayi duzeltmek sertifikayi geri getirmez
        assertFalse(ops.mark(ADMIN, e.getId(), ali.getId(), true).certificateValid());
        assertTrue(ops.attendance(e.getId()).rows().get(0).certificateRevoked());

        // geri al
        AdminCertificateRow back = ops.restoreCertificate(ADMIN, e.getId(), ali.getId());
        assertFalse(back.revoked());
        assertTrue(certificateService.verify("ABCDEFGHIJKLMNOPQRST").valid());
        assertEquals("CERTIFICATE_NOT_REVOKED", fail(() -> ops.restoreCertificate(ADMIN, e.getId(), ali.getId())).code());
        assertEquals("CERTIFICATE_NOT_FOUND", fail(() -> ops.revokeCertificate(ADMIN, e.getId(), 987654321L, "x")).code());
    }

    // ---- geri bildirim ----

    @Test
    void feedbackNeverRevealsTheAuthorAndDeleteIsScopedToTheEvent() {
        User owner = user("Sahip");
        User writer = user("Yazan");
        UserEvent e = liveEvent(owner, null);
        UserEvent other = liveEvent(owner, null);
        EventFeedback f = new EventFeedback();
        f.setEventId(e.getId());
        f.setUserId(writer.getId());
        f.setRating((short) 4);
        f.setComment("Guzeldi");
        feedbackRepo.saveAndFlush(f);

        AdminFeedbackPage p = ops.feedback(e.getId(), null, 50);
        assertEquals(1, p.items().size());
        AdminFeedbackRow row = p.items().get(0);
        assertEquals(4, row.rating());
        assertEquals("Guzeldi", row.comment());
        assertEquals(1, p.summary().total());
        assertEquals(4.0, p.summary().average());
        // anonimlik: kayit yapisinda kimlik alani HIC yok
        Set<String> comps = Arrays.stream(AdminFeedbackRow.class.getRecordComponents()).map(RecordComponent::getName)
                .collect(Collectors.toSet());
        assertEquals(Set.of("id", "rating", "comment", "createdAt"), comps);

        // baska etkinligin altindan silinemez
        assertEquals("FEEDBACK_NOT_FOUND", fail(() -> ops.deleteFeedback(other.getId(), f.getId())).code());
        assertTrue(feedbackRepo.findById(f.getId()).isPresent());
        ops.deleteFeedback(e.getId(), f.getId());
        assertTrue(feedbackRepo.findById(f.getId()).isEmpty());
        assertEquals(0, ops.feedback(e.getId(), null, 50).summary().total());
    }

    // ---- duyurular ----

    @Test
    void announcementRecordsAreListedAndDeletedWithinTheEvent() {
        User owner = user("Sahip");
        UserEvent e = liveEvent(owner, null);
        UserEvent other = liveEvent(owner, null);
        EventAnnouncement a = new EventAnnouncement();
        a.setEventId(e.getId());
        a.setSenderId(owner.getId());
        a.setRecipients(12);
        announcementRepo.saveAndFlush(a);

        CursorPage<AdminEventOpsDtos.AdminAnnouncementRow> p = ops.announcements(e.getId(), null, 50);
        assertEquals(1, p.items().size());
        assertEquals(12, p.items().get(0).recipients());
        assertEquals("Sahip", p.items().get(0).senderName());
        assertEquals("ANNOUNCEMENT_NOT_FOUND", fail(() -> ops.deleteAnnouncement(other.getId(), a.getId())).code());
        ops.deleteAnnouncement(e.getId(), a.getId());
        assertTrue(ops.announcements(e.getId(), null, 50).items().isEmpty());
        assertEquals("ANNOUNCEMENT_NOT_FOUND", fail(() -> ops.deleteAnnouncement(e.getId(), a.getId())).code());
    }

    // ---- duzenleyenler ----

    private CoOrganizer coOrganizer(UserEvent e, User u, User addedBy) {
        CoOrganizer c = new CoOrganizer();
        c.setEventId(e.getId());
        c.setUserId(u.getId());
        c.setAddedBy(addedBy.getId());
        return coOrganizers.saveAndFlush(c);
    }

    @Test
    void ownerIsProtectedAndCoOrganizerCanBeRemoved() {
        User owner = user("Sahip");
        User co1 = user("Ortak1");
        User co2 = user("Ortak2");
        UserEvent e = liveEvent(owner, null);
        coOrganizer(e, co1, owner);
        coOrganizer(e, co2, owner);

        List<AdminOrganizerRow> rows = ops.organizers(e.getId());
        assertEquals(3, rows.size());
        assertEquals("OWNER", rows.get(0).role());
        assertFalse(rows.get(0).removable());
        assertTrue(rows.get(1).removable());
        assertTrue(rows.get(0).emailMasked().contains("***"));

        assertEquals("EVENT_OWNER_PROTECTED", fail(() -> ops.removeOrganizer(e.getId(), owner.getId())).code());
        ops.removeOrganizer(e.getId(), co1.getId());
        assertEquals(2, ops.organizers(e.getId()).size());
        assertEquals("CO_ORGANIZER_NOT_FOUND", fail(() -> ops.removeOrganizer(e.getId(), co1.getId())).code());
        // sahip aktifken son ortak da cikarilabilir (sahip kalir)
        ops.removeOrganizer(e.getId(), co2.getId());
        assertEquals(1, ops.organizers(e.getId()).size());
    }

    @Test
    void lastActiveOrganizerIsProtectedWhenOwnerAccountIsGone() {
        User owner = user("Sahip");
        User co1 = user("Ortak1");
        User co2 = user("Ortak2");
        UserEvent e = liveEvent(owner, null);
        coOrganizer(e, co1, owner);
        coOrganizer(e, co2, owner);
        owner.setStatus(UserStatus.DELETED);
        users.saveAndFlush(owner);

        ops.removeOrganizer(e.getId(), co1.getId()); // co2 hala aktif
        ApiException x = fail(() -> ops.removeOrganizer(e.getId(), co2.getId()));
        assertEquals("EVENT_LAST_ORGANIZER", x.code());
        assertEquals(409, x.status().value());
        assertTrue(coOrganizers.existsByEventIdAndUserId(e.getId(), co2.getId()));
    }

    // ---- toplu islem ----

    @Test
    void bulkReportsPartialSuccessPerItem() {
        User owner = user("Sahip");
        UserEvent a = liveEvent(owner, null);
        UserEvent b = liveEvent(owner, null);
        UserEvent cancelled = liveEvent(owner, null);
        cancelled.setStatus(UserEvent.Status.CANCELLED);
        events.saveAndFlush(cancelled);

        BulkResult r = bulk.run(ADMIN, BulkAction.HIDE, List.of(a.getId(), b.getId(), cancelled.getId(), 987654321L, a.getId()),
                "toplu inceleme");
        assertEquals(4, r.requested()); // yinelenen id tek sayilir
        assertEquals(2, r.done());
        assertEquals(2, r.failed());
        assertEquals(UserEvent.Status.HIDDEN, events.findById(a.getId()).orElseThrow().getStatus());
        assertEquals(UserEvent.Status.HIDDEN, events.findById(b.getId()).orElseThrow().getStatus());
        assertEquals(UserEvent.Status.CANCELLED, events.findById(cancelled.getId()).orElseThrow().getStatus());
        var byId = r.items().stream().collect(Collectors.toMap(AdminEventOpsDtos.BulkItem::id, x -> x));
        assertTrue(byId.get(a.getId()).ok());
        assertEquals("EVENT_INVALID_TRANSITION", byId.get(cancelled.getId()).error());
        assertEquals(409, byId.get(cancelled.getId()).status());
        assertEquals("EVENT_NOT_FOUND", byId.get(987654321L).error());
        assertEquals(404, byId.get(987654321L).status());

        BulkResult c = bulk.run(ADMIN, BulkAction.CANCEL, List.of(a.getId(), b.getId()), "kural ihlali");
        assertEquals(2, c.done());
        assertEquals(UserEvent.Status.CANCELLED, events.findById(a.getId()).orElseThrow().getStatus());
    }

    @Test
    void bulkValidatesLimitReasonAndEmptyInput() {
        List<Long> many = new java.util.ArrayList<>();
        for (long i = 900_000_001L; i <= 900_000_101L; i++) {
            many.add(i);
        }
        ApiException tooMany = fail(() -> bulk.run(ADMIN, BulkAction.HIDE, many, "sebep var"));
        assertEquals("EVENT_BULK_LIMIT", tooMany.code());
        assertEquals(400, tooMany.status().value());
        assertEquals("VALIDATION_ERROR", fail(() -> bulk.run(ADMIN, BulkAction.HIDE, List.of(), "sebep var")).code());
        assertEquals("VALIDATION_ERROR", fail(() -> bulk.run(ADMIN, BulkAction.HIDE, List.of(1L), "  ")).code());
        List<Long> exactly = new java.util.ArrayList<>(many.subList(0, 100));
        assertEquals(100, bulk.run(ADMIN, BulkAction.UNHIDE, exactly, "sebep var").failed()); // hepsi yok -> hepsi basarisiz, 100 sinir ici
    }

    // ---- CSV ----

    @Test
    void csvEscapesFormulasMasksEmailsAndKeepsHeaderOnly() {
        User owner = user("Sahip");
        User evil = user("=HYPERLINK(\"http://x\")");
        UserEvent e = liveEvent(owner, null);
        rsvps.saveAndFlush(new EventRsvp(e.getId(), evil.getId(), EventRsvp.Status.GOING));
        ops.mark(ADMIN, e.getId(), evil.getId(), true);

        StringWriter w = new StringWriter();
        int n = csv.attendance(e.getId(), w);
        String out = w.toString();
        assertEquals(1, n);
        assertTrue(out.startsWith("﻿userId,name,emailMasked"));
        assertTrue(out.contains("\"'=HYPERLINK(\"\"http://x\"\")\""), out); // formul etkisiz, tirnak kacisli
        assertFalse(out.contains(evil.getEmail()), "tam e-posta CSV'de olmamali");
        assertTrue(out.contains("e***@bingol.edu.tr"));
        assertTrue(out.endsWith("\r\n"));

        // basvuru CSV: kullanici yazili not/yanit formul olarak baslarsa kacirilir
        UserEvent ap = futureEvent(owner, null, true);
        EventApplication x = apply(ap, evil, EventApplication.Status.PENDING);
        x.setNote("@SUM(1+1)");
        applications.saveAndFlush(x);
        StringWriter w2 = new StringWriter();
        assertEquals(1, csv.applications(ap.getId(), null, w2));
        assertTrue(w2.toString().contains("'@SUM(1+1)"));
        assertFalse(w2.toString().contains(evil.getEmail()));
        assertEquals("VALIDATION_ERROR", fail(() -> csv.applications(ap.getId(), "BOGUS", new StringWriter())).code());
        assertEquals("EVENT_NOT_FOUND", fail(() -> csv.attendance(987654321L, new StringWriter())).code());

        // etkinlik listesi CSV: baslik + satir, sahip e-postasi maskeli
        StringWriter w3 = new StringWriter();
        int rows = csv.events("ACTIVE", e.getTitle(), null, false, null, null, null, w3);
        assertEquals(1, rows);
        assertTrue(w3.toString().contains(e.getTitle()));
        assertFalse(w3.toString().contains(owner.getEmail()));
        assertTrue(w3.toString().contains("e***@bingol.edu.tr"));
        assertEquals("INVALID_DATES", fail(() -> csv.events(null, null, null, false, null,
                Instant.now(), Instant.now().minusSeconds(60), new StringWriter())).code());
    }
}
