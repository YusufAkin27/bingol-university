package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import edu.bingol.backend.academician.AcademicianDtos.ScanRequest;
import edu.bingol.backend.academician.AcademicianDtos.ScanResult;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/** Basvuru -> onay -> ders -> kayit -> oturum -> doner kod -> tarama akisi; rehber gizliligi; yonetici karari; esizamanlilik. */
class AcademicianFlowMvcTest extends AcademicianMvcBase {

    @Autowired AttendanceScanService scanService;
    @Autowired AcScanRequestRepository scanRequests;

    @Test
    void fullFlowFromApplicationToScan() throws Exception {
        User admin = admin();
        User l = plainUser("hoca." + rnd() + "@bingol.edu.tr", "Hoca");
        assertEquals("NONE", call(l, get("/api/academician/me"), 200).get("status").asText());
        assertEquals("APPROVED", call(l, postJson("/api/academician/apply",
                obj().put("title", "Dr.").put("firstName", "Ali").put("lastName", "Veli")), 200).get("status").asText());
        JsonNode me = call(l, get("/api/academician/me"), 200);
        assertEquals("AUTO", me.get("approvalMode").asText());
        assertEquals("Veli", me.get("lastName").asText());
        // her otomatik onay yoneticilere bildirilir
        assertTrue(countTitle(admin, "notif.academician.autoApproved.title") >= 1);

        long courseId = course(l);
        JsonNode slots = call(l, putJsonArray("/api/academician/courses/" + courseId + "/slots",
                "[{\"dayOfWeek\":1,\"startTime\":\"09:00\",\"endTime\":\"11:00\",\"room\":\"A-101\"},"
                        + "{\"dayOfWeek\":3,\"startTime\":\"13:30\",\"endTime\":\"15:00\"}]"), 200);
        assertEquals(2, slots.size());
        assertEquals("09:00", slots.get(0).get("startTime").asText());
        JsonNode detail = call(l, get("/api/academician/courses/" + courseId), 200);
        assertEquals(2, detail.get("slots").size());
        assertEquals(0, detail.get("enrolledCount").asInt());
        // bitis baslangictan sonra olmali
        expectError(l, putJsonArray("/api/academician/courses/" + courseId + "/slots",
                "[{\"dayOfWeek\":1,\"startTime\":\"11:00\",\"endTime\":\"09:00\"}]"), 400, "AC_FIELD_INVALID");

        User s1 = student("Ayşe Demir");
        User s2 = student("Mehmet Kaya");
        User outsider = student("Kayitsiz Ogrenci");
        enrol(l, courseId, s1, s2);
        assertEquals(1, countTitle(s1, "notif.academician.enrolled.title"));
        assertCourseTarget(s1, "notif.academician.enrolled.title", courseId);

        long sid = openSession(l, courseId);
        JsonNode lv = live(l, sid);
        assertEquals("OPEN", lv.get("status").asText());
        assertEquals(3, lv.get("codes").size());
        assertEquals(5, lv.get("stepSeconds").asInt());
        assertEquals(0, lv.get("presentCount").asInt());
        assertEquals(2, lv.get("enrolledCount").asInt());
        JsonNode c0 = lv.get("codes").get(0);
        assertEquals(c0.get("untilMs").asLong(), lv.get("codes").get(1).get("fromMs").asLong());
        long now = lv.get("serverNowMs").asLong();
        assertTrue(c0.get("fromMs").asLong() <= now && now < c0.get("untilMs").asLong());

        String code = c0.get("code").asText();
        JsonNode r1 = scan(s1, code);
        assertEquals("MARKED", r1.get("status").asText());
        assertEquals("Veri Yapıları", r1.get("courseName").asText());
        assertNotNull(r1.get("lessonDate"));
        assertEquals("ALREADY", scan(s1, code).get("status").asText());
        assertEquals(1, attendRepo.countActive(sid));
        // sonraki iki kod (ekranin onceden aldigi) ve onceki adim kabul edilir
        assertEquals("ALREADY", scan(s1, lv.get("codes").get(0).get("code").asText()).get("status").asText());

        // kayitli olmayan ogrenci gecerli kod okutunca reddedilmez: hocaya sunulur (bolum 15)
        assertEquals("PENDING", scan(outsider, code).get("status").asText());

        // oturum kapaninca eski kod gecersiz
        call(l, postJson("/api/academician/sessions/" + sid + "/close", null), 200);
        expectError(s2, scanReq(code), 422, "ATTENDANCE_CODE_INVALID");
        JsonNode closed = live(l, sid);
        assertEquals("CLOSED", closed.get("status").asText());
        assertEquals(0, closed.get("codes").size());
        // yeniden ac
        call(l, postJson("/api/academician/sessions/" + sid + "/reopen", null), 200);
        assertEquals("MARKED", scan(s2, code(l, sid)).get("status").asText());
        assertEquals(2, live(l, sid).get("presentCount").asInt());
    }

    @Test
    void malformedUnknownAndExpiredCodesAreOneGenericError() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        enrol(l, courseId, s);
        long sid = openSession(l, courseId);
        String good = code(l, sid);
        for (String bad : new String[] {"nonsense", "bingol-lesson:1.2.3", good + "x", "", "bingol-lesson:" + sid + ".1.AAAAAAAAAAAAAAAAAAAAAA"}) {
            expectError(s, scanReq(bad.isEmpty() ? "x" : bad), 422, "ATTENDANCE_CODE_INVALID");
        }
        // suresi dolmus oturum
        AcSession ses = sessionRepo.findById(sid).orElseThrow();
        ses.setExpiresAt(Instant.now().minusSeconds(5));
        sessionRepo.save(ses);
        expectError(s, scanReq(good), 422, "ATTENDANCE_CODE_INVALID");
        assertEquals("CLOSED", call(l, get("/api/academician/sessions/" + sid), 200).get("status").asText());
        assertEquals(0, attendRepo.countActive(sid));
        // yeniden acilinca calisir
        call(l, postJson("/api/academician/sessions/" + sid + "/reopen", null), 200);
        assertEquals("MARKED", scan(s, code(l, sid)).get("status").asText());
    }

    @Test
    void scanRateLimitIsTenPerMinutePerUser() throws Exception {
        User s = student("Hizli");
        AtomicInteger n = new AtomicInteger();
        doAnswer(inv -> {
            String key = inv.getArgument(0);
            if (key.startsWith("attendance-scan:user:")) {
                assertEquals(10, (int) inv.getArgument(1));
                assertEquals(Duration.ofMinutes(1), inv.getArgument(2));
                if (n.incrementAndGet() > 10) {
                    throw new RateLimitedException(60);
                }
            }
            return null;
        }).when(limiter).check(anyString(), anyInt(), any(Duration.class));
        for (int i = 0; i < 10; i++) {
            expectError(s, scanReq("bingol-lesson:1.1.x"), 422, "ATTENDANCE_CODE_INVALID");
        }
        assertEquals(429, raw(s, scanReq("bingol-lesson:1.1.x")).getStatus());
    }

    @Test
    void nonApprovedAcademiciansAreBlockedEverywhereExceptMeAndApply() throws Exception {
        User admin = admin();
        User pending = plainUser("biri." + rnd() + "@gmail.com", "Gmail Hoca");
        assertEquals("PENDING", call(pending, postJson("/api/academician/apply",
                obj().put("title", "Dr.").put("firstName", "G").put("lastName", "H")), 200).get("status").asText());
        User none = student("Basvurmamis");
        User rejected = plainUser("red." + rnd() + "@gmail.com", "Reddedilen");
        call(rejected, postJson("/api/academician/apply", obj().put("title", "Dr.").put("firstName", "R").put("lastName", "R")), 200);
        call(admin, postJson("/api/admin/academicians/" + rejected.getId() + "/reject", obj().put("reason", "Kurum disi")), 200);
        User revoked = lecturer("Iptal");
        call(admin, postJson("/api/admin/academicians/" + revoked.getId() + "/revoke", obj().put("reason", "Ayrildi")), 200);

        for (User u : List.of(pending, none, rejected, revoked)) {
            for (var b : List.of(get("/api/academician/courses"), get("/api/academician/courses/1"),
                    get("/api/academician/students?q=ab"), get("/api/academician/sessions/1"), get("/api/academician/sessions/1/live"),
                    get("/api/academician/courses/1/attendance"), get("/api/academician/courses/1/attendance.csv"),
                    get("/api/academician/courses/1/enrollments"), get("/api/academician/courses/1/notices"),
                    postJson("/api/academician/courses", obj().put("name", "x").put("term", "t").put("department", DEPT)),
                    postJson("/api/academician/courses/1/sessions", obj()),
                    postJson("/api/academician/courses/1/enrollments", obj().set("studentIds", OM.createArrayNode().add(1))),
                    postJson("/api/academician/sessions/1/close", null),
                    postJson("/api/academician/sessions/1/pending/1/accept", null),
                    postJson("/api/academician/courses/1/notices", obj().put("type", "LESSON_STARTED")),
                    delete("/api/academician/courses/1"), delete("/api/academician/sessions/1/records/1"))) {
                expectError(u, b, 403, "ACADEMICIAN_NOT_APPROVED");
            }
            assertNotNull(call(u, get("/api/academician/me"), 200).get("status"));
        }
        assertEquals("PENDING", call(pending, get("/api/academician/me"), 200).get("status").asText());
        assertEquals("REJECTED", call(rejected, get("/api/academician/me"), 200).get("status").asText());
        assertEquals("Kurum disi", call(rejected, get("/api/academician/me"), 200).get("rejectReason").asText());
        assertEquals("REVOKED", call(revoked, get("/api/academician/me"), 200).get("status").asText());
        // iptal edilen yeniden basvuramaz; bekleyen tekrar basvurunca ayni durum doner
        expectError(revoked, postJson("/api/academician/apply", obj().put("title", "D").put("firstName", "a").put("lastName", "b")),
                403, "ACADEMICIAN_REVOKED");
        assertEquals("PENDING", call(pending, postJson("/api/academician/apply",
                obj().put("title", "D").put("firstName", "a").put("lastName", "b")), 200).get("status").asText());
        // reddedilen yeniden basvurabilir; otomatik onaya DUSMEZ
        assertEquals("PENDING", call(rejected, postJson("/api/academician/apply",
                obj().put("title", "D").put("firstName", "a").put("lastName", "b")), 200).get("status").asText());
    }

    @Test
    void otherLecturersCourseAndSessionAre404() throws Exception {
        User a = lecturer("A");
        User b = lecturer("B");
        long courseId = course(a);
        User s = student("S");
        enrol(a, courseId, s);
        long sid = openSession(a, courseId);
        for (var req : List.of(get("/api/academician/courses/" + courseId), get("/api/academician/courses/" + courseId + "/enrollments"),
                get("/api/academician/courses/" + courseId + "/attendance"), get("/api/academician/courses/" + courseId + "/attendance.csv"),
                get("/api/academician/courses/" + courseId + "/sessions"), delete("/api/academician/courses/" + courseId))) {
            expectError(b, req, 404, "AC_COURSE_NOT_FOUND");
        }
        expectError(b, postJson("/api/academician/courses/" + courseId + "/sessions", obj()), 404, "AC_COURSE_NOT_FOUND");
        expectError(b, postJson("/api/academician/courses/" + courseId + "/enrollments", obj().set("studentIds", OM.createArrayNode().add(s.getId()))),
                404, "AC_COURSE_NOT_FOUND");
        expectError(b, postJson("/api/academician/courses/" + courseId + "/notices", obj().put("type", "LESSON_STARTED")), 404, "AC_COURSE_NOT_FOUND");
        for (var req : List.of(get("/api/academician/sessions/" + sid), get("/api/academician/sessions/" + sid + "/live"),
                postJson("/api/academician/sessions/" + sid + "/close", null), postJson("/api/academician/sessions/" + sid + "/reopen", null),
                org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/academician/sessions/" + sid + "/records/" + s.getId()),
                delete("/api/academician/sessions/" + sid + "/records/" + s.getId()),
                postJson("/api/academician/sessions/" + sid + "/pending/" + s.getId() + "/accept", null))) {
            expectError(b, req, 404, "AC_SESSION_NOT_FOUND");
        }
        // sahibi etkilenmedi
        assertEquals(courseId, call(a, get("/api/academician/courses/" + courseId), 200).get("id").asLong());
    }

    @Test
    void directoryExposesOnlyEligibleStudentsAndNeverEmail() throws Exception {
        User l = lecturer("Hoca");
        String tag = "Zzehra" + rnd();
        User ok1 = student(tag + " Bir");
        User ok2 = student(tag + " Iki");
        User unverified = student(tag + " Dogrulanmamis");
        unverified.setEmailVerified(false);
        users.save(unverified);
        User deferred = student(tag + " Ertelenmis");
        deferred.setVerificationDeferred(true);
        users.save(deferred);
        User suspended = student(tag + " Askida");
        suspended.setStatus(UserStatus.SUSPENDED);
        users.save(suspended);
        User deleted = student(tag + " Silinmis");
        deleted.setDeletedAt(Instant.now());
        users.save(deleted);
        User adm = student(tag + " Yonetici");
        adm.setRole(edu.bingol.backend.user.Role.ADMIN);
        users.save(adm);
        User otherLecturer = student(tag + " Akademisyen");
        call(otherLecturer, postJson("/api/academician/apply", obj().put("title", "Dr.").put("firstName", "a").put("lastName", "b")), 200);
        User gmail = plainUser("kisi." + rnd() + "@gmail.com", tag + " Gmail");
        gmail.setDepartment(DEPT);
        users.save(gmail);

        JsonNode res = call(l, get("/api/academician/students?q=" + tag.toLowerCase() + "&size=50"), 200);
        List<Long> ids = new ArrayList<>();
        res.get("items").forEach(n -> ids.add(n.get("id").asLong()));
        assertTrue(ids.containsAll(List.of(ok1.getId(), ok2.getId(), gmail.getId())), ids.toString());
        for (User excluded : List.of(unverified, deferred, suspended, deleted, adm, otherLecturer)) {
            assertFalse(ids.contains(excluded.getId()), excluded.getDisplayName());
        }
        String body = res.toString();
        assertFalse(body.contains("@"), "e-posta sizdi: " + body);
        assertFalse(body.toLowerCase().contains("email"));
        JsonNode first = null;
        for (JsonNode n : res.get("items")) {
            if (n.get("id").asLong() == ok1.getId()) {
                first = n;
            }
            assertEquals(Set.of("id", "displayName", "studentNo", "faculty", "department", "grade"),
                    Set.copyOf(iterate(n)), "yalniz izinli alanlar");
        }
        assertNotNull(first);
        assertEquals(ok1.getEmail().split("@")[0], first.get("studentNo").asText());
        // gmail adresinin ogrenci numarasi yoktur
        for (JsonNode n : res.get("items")) {
            if (n.get("id").asLong() == gmail.getId()) {
                assertTrue(n.get("studentNo").isNull());
            }
        }
        // Turkce harf duyarsiz + imec
        JsonNode page1 = call(l, get("/api/academician/students?q=ZZEHRA" + tag.substring(6).toUpperCase() + "&size=1"), 200);
        assertEquals(1, page1.get("items").size());
        assertNotNull(page1.get("nextCursor").asText());
        // yalnizca onaylilar rehberi kullanir (bu ogrenci basvurusu bekleyen/onayli degil)
        expectError(ok1, get("/api/academician/students?q=ab"), 403, "ACADEMICIAN_NOT_APPROVED");
    }

    private static List<String> iterate(JsonNode n) {
        List<String> out = new ArrayList<>();
        n.fieldNames().forEachRemaining(out::add);
        return out;
    }

    @Test
    void enrolmentSkipsIneligibleDuplicatesAndBulkIsCapped() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Ogr");
        User unverified = student("Dogrulanmamis");
        unverified.setEmailVerified(false);
        users.save(unverified);
        ArrayNode ids = OM.createArrayNode().add(s.getId()).add(s.getId()).add(unverified.getId()).add(987654321L);
        assertEquals(1, call(l, postJson("/api/academician/courses/" + courseId + "/enrollments", obj().set("studentIds", ids)), 200)
                .get("added").asInt());
        assertEquals(0, call(l, postJson("/api/academician/courses/" + courseId + "/enrollments", obj().set("studentIds", ids)), 200)
                .get("added").asInt());
        assertEquals(1, enrollRepo.countByCourseId(courseId));
        // 100'den fazla kimlik dogrulama hatasi
        ArrayNode many = OM.createArrayNode();
        for (int i = 0; i < 101; i++) {
            many.add(i + 1);
        }
        expectError(l, postJson("/api/academician/courses/" + courseId + "/enrollments", obj().set("studentIds", many)), 400, "VALIDATION_ERROR");

        // toplu: bolumdeki tum ogrenciler; 500 siniri asilirsa hicbiri eklenmez
        String bigDept = "Kapasite Bolumu " + rnd();
        List<User> crowd = new ArrayList<>();
        for (int i = 0; i < 501; i++) {
            User u = new User();
            u.setEmail((300_000_000L + i) + rnd() + "@bingol.edu.tr");
            u.setPasswordHash("x");
            u.setDisplayName("Kalabalik " + i);
            u.setEmailVerified(true);
            u.setDepartment(bigDept);
            crowd.add(u);
        }
        users.saveAll(crowd);
        expectError(l, postJson("/api/academician/courses/" + courseId + "/enrollments/bulk", obj().put("department", bigDept)),
                422, "AC_BULK_TOO_LARGE");
        assertEquals(1, enrollRepo.countByCourseId(courseId));
        users.deleteAll(crowd.subList(0, 498)); // 3 kisi kalir
        assertEquals(3, call(l, postJson("/api/academician/courses/" + courseId + "/enrollments/bulk", obj().put("department", bigDept)), 200)
                .get("added").asInt());
        assertEquals(4, enrollRepo.countByCourseId(courseId));
        // cikarma idempotent
        call(l, delete("/api/academician/courses/" + courseId + "/enrollments/" + s.getId()), 204);
        call(l, delete("/api/academician/courses/" + courseId + "/enrollments/" + s.getId()), 204);
        assertEquals(3, enrollRepo.countByCourseId(courseId));
    }

    @Test
    void adminApproveRejectRevokeNotifyTheApplicant() throws Exception {
        User admin = admin();
        User p1 = plainUser("a." + rnd() + "@gmail.com", "Aday Bir");
        User p2 = plainUser("b." + rnd() + "@gmail.com", "Aday Iki");
        for (User p : List.of(p1, p2)) {
            assertEquals("PENDING", call(p, postJson("/api/academician/apply",
                    obj().put("title", "Dr.").put("firstName", "X").put("lastName", "Y")), 200).get("status").asText());
        }
        JsonNode pend = call(admin, get("/api/admin/academicians?status=PENDING&size=50"), 200);
        List<Long> ids = new ArrayList<>();
        pend.get("items").forEach(n -> ids.add(n.get("userId").asLong()));
        assertTrue(ids.containsAll(List.of(p1.getId(), p2.getId())));
        assertEquals(p1.getEmail(), findEmail(pend, p1.getId())); // FULL yonetici maskesiz gorur

        JsonNode approved = call(admin, post("/api/admin/academicians/" + p1.getId() + "/approve"), 200);
        assertEquals("APPROVED", approved.get("status").asText());
        assertEquals("ADMIN", approved.get("approvalMode").asText());
        assertEquals(admin.getId(), approved.get("reviewedBy").asLong());
        assertEquals(1, countTitle(p1, "notif.academician.approved.title"));
        assertEquals("[]", call(p1, get("/api/academician/courses"), 200).toString()); // artik panel acik
        expectError(admin, post("/api/admin/academicians/" + p1.getId() + "/approve"), 409, "ACADEMICIAN_BAD_STATE");

        // ret: gerekce zorunlu
        expectError(admin, postJson("/api/admin/academicians/" + p2.getId() + "/reject", obj()), 400, "VALIDATION_ERROR");
        JsonNode rejected = call(admin, postJson("/api/admin/academicians/" + p2.getId() + "/reject", obj().put("reason", "Kurum disi")), 200);
        assertEquals("REJECTED", rejected.get("status").asText());
        assertEquals(1, countTitle(p2, "notif.academician.rejected.title"));
        expectError(admin, postJson("/api/admin/academicians/" + p2.getId() + "/reject", obj().put("reason", "tekrar")), 409, "ACADEMICIAN_BAD_STATE");

        // iptal: yalniz onayli; panel kapanir ama dersler silinmez
        long courseId = course(p1);
        JsonNode revoked = call(admin, postJson("/api/admin/academicians/" + p1.getId() + "/revoke", obj().put("reason", "Ayrildi")), 200);
        assertEquals("REVOKED", revoked.get("status").asText());
        assertEquals(1, countTitle(p1, "notif.academician.revoked.title"));
        expectError(p1, get("/api/academician/courses"), 403, "ACADEMICIAN_NOT_APPROVED");
        assertTrue(courseRepo.findById(courseId).isPresent());
        // yonetici ders okumasi (salt okunur)
        assertEquals(1, call(admin, get("/api/admin/academicians/" + p1.getId() + "/courses"), 200).size());
        assertEquals(courseId, call(admin, get("/api/admin/academicians/courses/" + courseId), 200).get("id").asLong());
        assertNotNull(call(admin, get("/api/admin/academicians/courses/" + courseId + "/attendance"), 200).get("sessions"));
        // yeniden onay
        assertEquals("APPROVED", call(admin, post("/api/admin/academicians/" + p1.getId() + "/approve"), 200).get("status").asText());
        // yonetici olmayan yonetici uclarini kullanamaz
        assertEquals(403, raw(student("x"), get("/api/admin/academicians")).getStatus());
        // otomatik onaylananlar filtrelenebilir
        User auto = lecturer("Otomatik");
        JsonNode autos = call(admin, get("/api/admin/academicians?approvalMode=AUTO&size=50"), 200);
        List<Long> autoIds = new ArrayList<>();
        autos.get("items").forEach(n -> autoIds.add(n.get("userId").asLong()));
        assertTrue(autoIds.contains(auto.getId()));
        assertFalse(autoIds.contains(p1.getId()));
    }

    @Test
    void viewerAdminReadsMaskedEmailsButCannotDecide() throws Exception {
        User viewer = admin();
        viewer.setAdminProfile(edu.bingol.backend.admin.rbac.AdminProfile.VIEWER);
        users.save(viewer);
        User p = plainUser("aday." + rnd() + "@gmail.com", "Aday");
        call(p, postJson("/api/academician/apply", obj().put("title", "Dr.").put("firstName", "X").put("lastName", "Y")), 200);
        JsonNode page = call(viewer, get("/api/admin/academicians?status=PENDING&size=50"), 200);
        String email = findEmail(page, p.getId());
        assertNotNull(email);
        assertTrue(email.contains("***"), "e-posta maskeli olmali: " + email);
        assertFalse(email.equals(p.getEmail()));
        // yazma izni yok (users.write): onay/ret/iptal 403 ADMIN_PERMISSION_DENIED
        expectError(viewer, post("/api/admin/academicians/" + p.getId() + "/approve"), 403, "ADMIN_PERMISSION_DENIED");
        expectError(viewer, postJson("/api/admin/academicians/" + p.getId() + "/reject", obj().put("reason", "x")), 403, "ADMIN_PERMISSION_DENIED");
        assertEquals("PENDING", academicianRepo.findById(p.getId()).orElseThrow().getStatus().name());
    }

    @Test
    void adminListSearchStatusFilterAndLifecycleFacts() throws Exception {
        User admin = admin();
        String tag = "Qwxyz" + rnd();
        User a = plainUser("ara." + rnd() + "@gmail.com", "Aday A");
        User b = plainUser("bul." + rnd() + "@gmail.com", "Aday B");
        User c = plainUser("cok." + rnd() + "@gmail.com", "Aday C");
        for (User u : List.of(a, b, c)) {
            call(u, postJson("/api/academician/apply", obj().put("title", "Dr.").put("firstName", u == a ? tag : "Diger")
                    .put("lastName", u == b ? tag + "oglu" : "Soyad")), 200);
        }
        // ad / soyad eslesmesi (buyuk-kucuk harf duyarsiz), imec korunur
        JsonNode r = call(admin, get("/api/admin/academicians?q=" + tag.toUpperCase() + "&size=50"), 200);
        List<Long> ids = new ArrayList<>();
        r.get("items").forEach(n -> ids.add(n.get("userId").asLong()));
        assertEquals(List.of(b.getId(), a.getId()), ids); // userId'ye gore azalan
        JsonNode p1 = call(admin, get("/api/admin/academicians?q=" + tag + "&size=1"), 200);
        assertEquals(1, p1.get("items").size());
        assertEquals(b.getId(), p1.get("nextCursor").asLong());
        JsonNode p2 = call(admin, get("/api/admin/academicians?q=" + tag + "&size=1&cursor=" + p1.get("nextCursor").asLong()), 200);
        assertEquals(a.getId(), p2.get("items").get(0).get("userId").asLong());
        assertTrue(p2.get("nextCursor").isNull());
        // e-posta ile arama yalniz users.pii'li yoneticide
        String mailPart = c.getEmail().substring(0, c.getEmail().indexOf('@'));
        assertEquals(1, call(admin, get("/api/admin/academicians?q=" + mailPart), 200).get("items").size());
        User viewer = admin();
        viewer.setAdminProfile(edu.bingol.backend.admin.rbac.AdminProfile.VIEWER);
        users.save(viewer);
        assertEquals(0, call(viewer, get("/api/admin/academicians?q=" + mailPart), 200).get("items").size()); // e-posta oracle'i yok
        assertEquals(2, call(viewer, get("/api/admin/academicians?q=" + tag), 200).get("items").size()); // ad aranabilir
        expectError(viewer, get("/api/admin/academicians?q=ab"), 400, "VALIDATION_ERROR"); // maskeli: en az 3 karakter
        assertEquals(0, call(admin, get("/api/admin/academicians?q=" + tag + "%25nope"), 200).get("items").size()); // LIKE kacisi
        assertEquals(0, call(admin, get("/api/admin/academicians?q=" + tag + "_"), 200).get("items").size());
        // durum + mod suzgecleri birlikte
        assertEquals(0, call(admin, get("/api/admin/academicians?q=" + tag + "&approvalMode=AUTO"), 200).get("items").size());

        // yasam dongusu gercekleri (admin sayfasi buna dayanir)
        User auto = lecturer("Otomatik");
        JsonNode autoRow = call(admin, get("/api/admin/academicians/" + auto.getId()), 200);
        assertEquals("AUTO", autoRow.get("approvalMode").asText());
        assertTrue(autoRow.get("reviewedBy").isNull());
        call(admin, postJson("/api/admin/academicians/" + a.getId() + "/reject", obj().put("reason", "Eksik belge")), 200);
        JsonNode revoked = call(admin, postJson("/api/admin/academicians/" + auto.getId() + "/revoke", obj().put("reason", "Ayrildi")), 200);
        assertEquals("Ayrildi", revoked.get("rejectReason").asText());
        assertEquals("REVOKED", revoked.get("status").asText());
        JsonNode multi = call(admin, get("/api/admin/academicians?status=REJECTED,REVOKED&size=50"), 200);
        List<String> st = new ArrayList<>();
        multi.get("items").forEach(n -> st.add(n.get("status").asText()));
        assertTrue(st.contains("REJECTED") && st.contains("REVOKED"));
        assertFalse(st.contains("PENDING") || st.contains("APPROVED"));
        // reddedilenden ve iptal edilenden onay mumkun, ADMIN moduyla
        for (User u : List.of(a, auto)) {
            JsonNode ok = call(admin, post("/api/admin/academicians/" + u.getId() + "/approve"), 200);
            assertEquals("ADMIN", ok.get("approvalMode").asText());
            assertTrue(ok.get("rejectReason").isNull());
        }
        expectError(admin, post("/api/admin/academicians/" + a.getId() + "/approve"), 409, "ACADEMICIAN_BAD_STATE");
    }

    private static String findEmail(JsonNode page, long userId) {
        for (JsonNode n : page.get("items")) {
            if (n.get("userId").asLong() == userId) {
                return n.get("email").asText();
            }
        }
        return null;
    }

    @Test
    void twoSimultaneousScansOfTheSameStudentProduceExactlyOneRow() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Cift Tarama");
        enrol(l, courseId, s);
        long sid = openSession(l, courseId);
        String code = code(l, sid);

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<ScanResult>> fs = new ArrayList<>();
        for (int i = 0; i < 2; i++) {
            fs.add(pool.submit(() -> {
                go.await();
                return scanService.scan(s.getId(), new ScanRequest(code));
            }));
        }
        go.countDown();
        List<String> statuses = new ArrayList<>();
        for (Future<ScanResult> f : fs) {
            statuses.add(f.get(30, TimeUnit.SECONDS).status());
        }
        pool.shutdown();
        assertTrue(statuses.contains("MARKED"), statuses.toString());
        assertEquals(1, statuses.stream().filter("MARKED"::equals).count(), statuses.toString());
        assertEquals(1, attendRepo.countActive(sid));
        assertEquals(1, attendRepo.findAll().stream().filter(a -> a.getSessionId().equals(sid)).count());

        // tekil kisit yolu belirleyici olarak: satir varken dogrudan ekleme hataya degil false'a doner
        assertFalse(scanService.tryInsert(sid, s.getId(), Instant.now()));
        assertEquals(1, attendRepo.countActive(sid));
    }

    @Test
    void pendingScanFlowAcceptDismissAndGuards() throws Exception {
        User l = lecturer("Hoca");
        User other = lecturer("Baska Hoca");
        long courseId = course(l);
        User member = student("Uye");
        enrol(l, courseId, member);
        long sid = openSession(l, courseId);
        String code = code(l, sid);

        // gecersiz kod istek OLUSTURMAZ
        User out1 = student("Kayitsiz Bir");
        long base = scanRequests.count();
        expectError(out1, scanReq("bingol-lesson:" + sid + ".1.AAAAAAAAAAAAAAAAAAAAAA"), 422, "ATTENDANCE_CODE_INVALID");
        assertEquals(base, scanRequests.count());

        assertEquals("PENDING", scan(out1, code).get("status").asText());
        assertEquals("PENDING", scan(out1, code).get("status").asText()); // idempotent
        assertEquals(base + 1, scanRequests.count());
        JsonNode lv = live(l, sid);
        assertEquals(1, lv.get("pendingScans").size());
        JsonNode p = lv.get("pendingScans").get(0);
        assertEquals(out1.getId(), p.get("studentId").asLong());
        assertEquals("Kayitsiz Bir", p.get("displayName").asText());
        assertEquals(out1.getEmail().split("@")[0], p.get("studentNo").asText());
        assertEquals(DEPT, p.get("department").asText());
        assertNotNull(p.get("scannedAt"));
        assertEquals(0, lv.get("presentCount").asInt());   // bekleyen sayilmaz
        assertEquals(1, lv.get("enrolledCount").asInt());
        assertEquals(1, call(l, get("/api/academician/sessions/" + sid), 200).get("pendingScans").size());
        assertTrue(call(l, get("/api/academician/sessions/" + sid + "/live"), 200).get("newRecords").isEmpty());

        // baska hoca dokunamaz
        expectError(other, postJson("/api/academician/sessions/" + sid + "/pending/" + out1.getId() + "/accept", null), 404, "AC_SESSION_NOT_FOUND");
        expectError(other, postJson("/api/academician/sessions/" + sid + "/pending/" + out1.getId() + "/dismiss", null), 404, "AC_SESSION_NOT_FOUND");
        // bilinmeyen istek
        expectError(l, postJson("/api/academician/sessions/" + sid + "/pending/999999/accept", null), 404, "AC_SCAN_REQUEST_NOT_FOUND");

        Instant scannedAt = scanRequests.findBySessionIdAndStudentId(sid, out1.getId()).orElseThrow().getScannedAt();
        call(l, postJson("/api/academician/sessions/" + sid + "/close", null), 200); // kapaliyken de calisir
        JsonNode rec = call(l, postJson("/api/academician/sessions/" + sid + "/pending/" + out1.getId() + "/accept", null), 200);
        assertEquals("QR", rec.get("method").asText());
        assertTrue(enrollRepo.existsByCourseIdAndStudentId(courseId, out1.getId()));
        AcAttendance row = attendRepo.findBySessionIdAndStudentId(sid, out1.getId()).orElseThrow();
        assertEquals(AcAttendance.Method.QR, row.getMethod());
        assertEquals(scannedAt, row.getMarkedAt());
        assertEquals(1, countTitle(out1, "notif.academician.enrolled.title"));
        assertEquals(AcScanRequest.Status.ACCEPTED, scanRequests.findBySessionIdAndStudentId(sid, out1.getId()).orElseThrow().getStatus());
        assertEquals(0, call(l, get("/api/academician/sessions/" + sid), 200).get("pendingScans").size());
        // idempotent: ikinci kabul ne cift satir ne cift bildirim
        call(l, postJson("/api/academician/sessions/" + sid + "/pending/" + out1.getId() + "/accept", null), 200);
        assertTrue(attendRepo.countActive(sid) >= 1);
        assertEquals(1, attendRepo.findAll().stream().filter(a -> a.getSessionId().equals(sid) && a.getStudentId().equals(out1.getId())).count());
        assertEquals(1, countTitle(out1, "notif.academician.enrolled.title"));

        // reddet: ayni oturumda tekrar tarayan 403 alir
        call(l, postJson("/api/academician/sessions/" + sid + "/reopen", null), 200);
        String code2 = code(l, sid);
        User out2 = student("Kayitsiz Iki");
        assertEquals("PENDING", scan(out2, code2).get("status").asText());
        call(l, postJson("/api/academician/sessions/" + sid + "/pending/" + out2.getId() + "/dismiss", null), 204);
        call(l, postJson("/api/academician/sessions/" + sid + "/pending/" + out2.getId() + "/dismiss", null), 204); // idempotent
        expectError(out2, scanReq(code2), 403, "ATTENDANCE_NOT_ENROLLED");
        assertFalse(enrollRepo.existsByCourseIdAndStudentId(courseId, out2.getId()));
        assertEquals(0, countTitle(out2, "notif.academician.enrolled.title"));

        // admin ve akademisyen hesaplari istek olusturmaz
        long before = scanRequests.count();
        expectError(admin(), scanReq(code2), 403, "ATTENDANCE_NOT_ENROLLED");
        expectError(other, scanReq(code2), 403, "ATTENDANCE_NOT_ENROLLED");
        assertEquals(before, scanRequests.count());

        // ogrenci arada elle eklenmisse kabul yalniz yoklamayi isler
        User out3 = student("Kayitsiz Uc");
        assertEquals("PENDING", scan(out3, code2).get("status").asText());
        enrol(l, courseId, out3);
        call(l, postJson("/api/academician/sessions/" + sid + "/pending/" + out3.getId() + "/accept", null), 200);
        assertEquals(1, enrollRepo.findAll().stream().filter(e -> e.getCourseId().equals(courseId) && e.getStudentId().equals(out3.getId())).count());
        assertTrue(attendRepo.existsBySessionIdAndStudentId(sid, out3.getId()));
    }

    @Test
    void pendingCapStopsFurtherRequests() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        long sid = openSession(l, courseId);
        String code = code(l, sid);
        for (int i = 0; i < 200; i++) {
            AcScanRequest r = new AcScanRequest();
            r.setSessionId(sid);
            r.setStudentId(900_000_000L + i);
            r.setScannedAt(Instant.now());
            scanRequests.save(r);
        }
        User late = student("Gec Kalan");
        long before = scanRequests.count();
        expectError(late, scanReq(code), 403, "ATTENDANCE_NOT_ENROLLED");
        assertEquals(before, scanRequests.count());
        assertNull(scanRequests.findBySessionIdAndStudentId(sid, late.getId()).orElse(null));
    }

    private static org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder putJsonArray(String url, String json) {
        return org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put(url).contentType("application/json").content(json);
    }
}
