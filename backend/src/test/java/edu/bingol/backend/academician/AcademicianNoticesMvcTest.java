package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.user.User;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.mock.web.MockMultipartFile;

/** Ders duyurulari (7 sabit tur), sinirlar, Derslerim uclari ve duyuru dosyalari (yukleme, yetkili indirme, silme). */
class AcademicianNoticesMvcTest extends AcademicianMvcBase {

    @Autowired AcNoticeFileRepository fileRepo;
    @Autowired AcNoticeRepository noticeRepo;
    @Autowired PrivateMediaStore store;

    private static final Instant FUTURE = Instant.now().plusSeconds(7 * 86400);

    private JsonNode notice(User l, long courseId, ObjectNode body) {
        return call(l, postJson("/api/academician/courses/" + courseId + "/notices", body), 201);
    }

    private JsonNode upload(User l, long courseId, String name, byte[] bytes, int expected) {
        return call(l, multipart("/api/academician/courses/" + courseId + "/notice-files")
                .file(new MockMultipartFile("file", name, "application/octet-stream", bytes)), expected);
    }

    // ---- duyurular ----

    @Test
    void allSevenTypesWorkAndOnlyEnrolledStudentsAreNotifiedAndCanRead() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Kayitli");
        User out = student("Kayitsiz");
        enrol(l, courseId, s);

        notice(l, courseId, obj().put("type", "LESSON_STARTED"));
        notice(l, courseId, obj().put("type", "ATTENDANCE_STARTED"));
        notice(l, courseId, obj().put("type", "EXAM").put("title", "Vize").put("eventAt", FUTURE.toString()).put("note", "Salon A"));
        notice(l, courseId, obj().put("type", "ASSIGNMENT").put("title", "Odev 1").put("eventAt", FUTURE.plusSeconds(3600).toString()));
        notice(l, courseId, obj().put("type", "MATERIAL").put("title", "Hafta 1 notlari").put("note", "pdf ekte"));
        notice(l, courseId, obj().put("type", "LESSON_CANCELLED").put("eventAt", FUTURE.toString()).put("note", "hasta"));
        notice(l, courseId, obj().put("type", "ROOM_CHANGED").put("title", "B-204"));

        for (String k : List.of("lessonStarted", "attendanceStarted", "exam", "assignment", "material", "lessonCancelled", "roomChanged")) {
            assertEquals(1, countTitle(s, "notif.academician." + k + ".title"), k);
            assertEquals(0, countTitle(out, "notif.academician." + k + ".title"), k);
        }
        for (String k : List.of("lessonStarted", "attendanceStarted", "exam", "assignment", "material", "lessonCancelled", "roomChanged")) {
            assertCourseTarget(s, "notif.academician." + k + ".title", courseId);
        }
        JsonNode list = call(s, get("/api/my-courses/" + courseId + "/notices"), 200);
        assertEquals(7, list.get("items").size());
        assertEquals("ROOM_CHANGED", list.get("items").get(0).get("type").asText()); // en yeni once
        assertTrue(list.get("items").get(0).get("files").isArray());
        // kayitli olmayan ogrenci: 403
        expectError(out, get("/api/my-courses/" + courseId + "/notices"), 403, "ATTENDANCE_NOT_ENROLLED");
        // imec
        JsonNode p1 = call(l, get("/api/academician/courses/" + courseId + "/notices?size=3"), 200);
        assertEquals(3, p1.get("items").size());
        JsonNode p2 = call(l, get("/api/academician/courses/" + courseId + "/notices?size=50&cursor=" + p1.get("nextCursor").asLong()), 200);
        assertEquals(4, p2.get("items").size());
        // silinen duyuru ogrenci listesinden kalkar
        long examId = 0;
        for (JsonNode n : list.get("items")) {
            if (n.get("type").asText().equals("EXAM")) {
                examId = n.get("id").asLong();
            }
        }
        call(l, delete("/api/academician/notices/" + examId), 204);
        assertEquals(6, call(s, get("/api/my-courses/" + courseId + "/notices"), 200).get("items").size());
        // baska hoca silemez
        User other = lecturer("Baska");
        expectError(other, delete("/api/academician/notices/" + noticeRepo.findAll().stream().filter(n -> n.getCourseId().equals(courseId)).findFirst().orElseThrow().getId()),
                404, "AC_COURSE_NOT_FOUND");
        // yonetici salt okunur
        assertEquals(6, call(admin(), get("/api/admin/academicians/courses/" + courseId + "/notices?size=50"), 200).get("items").size());
    }

    @Test
    void perTypeFieldValidationAndNoFreeFormBroadcast() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        String url = "/api/academician/courses/" + courseId + "/notices";
        expectError(l, postJson(url, obj().put("type", "EXAM").put("title", "Vize")), 400, "AC_FIELD_INVALID"); // tarih yok
        expectError(l, postJson(url, obj().put("type", "EXAM").put("eventAt", FUTURE.toString())), 400, "AC_FIELD_INVALID"); // baslik yok
        expectError(l, postJson(url, obj().put("type", "LESSON_STARTED").put("title", "Serbest metin")), 400, "AC_FIELD_INVALID");
        expectError(l, postJson(url, obj().put("type", "MATERIAL").put("title", "x").put("eventAt", FUTURE.toString())), 400, "AC_FIELD_INVALID");
        expectError(l, postJson(url, obj().put("type", "ROOM_CHANGED")), 400, "AC_FIELD_INVALID");
        expectError(l, postJson(url, obj().put("type", "LESSON_CANCELLED")), 400, "AC_FIELD_INVALID");
        expectError(l, postJson(url, obj().put("type", "SERBEST")), 400, "MALFORMED_REQUEST");
        expectError(l, postJson(url, obj().put("title", "tip yok")), 400, "VALIDATION_ERROR");
        assertEquals(0, noticeRepo.findAll().stream().filter(n -> n.getCourseId().equals(courseId)).count());
    }

    @Test
    void frequencyAndDailyLimits() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        String url = "/api/academician/courses/" + courseId + "/notices";
        notice(l, courseId, obj().put("type", "LESSON_STARTED"));
        expectError(l, postJson(url, obj().put("type", "LESSON_STARTED")), 429, "NOTICE_TOO_FREQUENT");
        notice(l, courseId, obj().put("type", "ATTENDANCE_STARTED")); // ayri tur: serbest
        expectError(l, postJson(url, obj().put("type", "ATTENDANCE_STARTED")), 429, "NOTICE_TOO_FREQUENT");
        // 10 dakika gecince yeniden
        for (AcNotice n : noticeRepo.findAll()) {
            if (n.getCourseId().equals(courseId)) {
                n.setCreatedAt(Instant.now().minusSeconds(11 * 60));
                noticeRepo.save(n);
            }
        }
        notice(l, courseId, obj().put("type", "LESSON_STARTED"));
        // gunluk 20 sinir: bugune ait 3 var; 17 tane daha
        for (int i = 0; i < 17; i++) {
            notice(l, courseId, obj().put("type", "MATERIAL").put("title", "Not " + i));
        }
        expectError(l, postJson(url, obj().put("type", "MATERIAL").put("title", "21.")), 429, "NOTICE_DAILY_LIMIT");
    }

    @Test
    void notifyOnOpenSendsExactlyOneAttendanceStarted() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s1 = student("Bir");
        User s2 = student("Iki");
        enrol(l, courseId, s1, s2);
        // notify verilmezse bildirim yok
        long first = openSession(l, courseId);
        assertEquals(0, countTitle(s1, "notif.academician.attendanceStarted.title"));
        call(l, postJson("/api/academician/sessions/" + first + "/close", null), 200);
        call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj().put("notify", true)), 201);
        for (User s : List.of(s1, s2)) {
            assertEquals(1, countTitle(s, "notif.academician.attendanceStarted.title"));
        }
        List<AcNotice> rows = noticeRepo.findAll().stream().filter(n -> n.getCourseId().equals(courseId)).toList();
        assertEquals(1, rows.size());
        assertEquals(AcNotice.Type.ATTENDANCE_STARTED, rows.get(0).getType());
        // 10 dakika icinde tekrar: oturum acilir ama ikinci bildirim yok (429 yutulur)
        call(l, postJson("/api/academician/courses/" + courseId + "/sessions", obj().put("notify", true).put("lessonDate",
                java.time.LocalDate.now().minusDays(1).toString())), 201);
        assertEquals(1, countTitle(s1, "notif.academician.attendanceStarted.title"));
        assertEquals(1, noticeRepo.findAll().stream().filter(n -> n.getCourseId().equals(courseId)).count());
    }

    @Test
    void upcomingListsOnlyFutureItemsOfOwnCoursesSoonestFirst() throws Exception {
        User l = lecturer("Hoca");
        long mine = course(l);
        long theirs = course(l);
        User s = student("Ben");
        User other = student("Baskasi");
        enrol(l, mine, s);
        enrol(l, theirs, other);
        notice(l, mine, obj().put("type", "EXAM").put("title", "Final").put("eventAt", FUTURE.plusSeconds(86400 * 5).toString()));
        notice(l, mine, obj().put("type", "ASSIGNMENT").put("title", "Odev").put("eventAt", FUTURE.toString()));
        notice(l, mine, obj().put("type", "EXAM").put("title", "Gecmis sinav").put("eventAt", Instant.now().minusSeconds(3600).toString()));
        notice(l, mine, obj().put("type", "ROOM_CHANGED").put("title", "C-1").put("eventAt", FUTURE.plusSeconds(100).toString()));
        notice(l, mine, obj().put("type", "ROOM_CHANGED").put("title", "C-2")); // tarihsiz: yaklasanda yok
        notice(l, mine, obj().put("type", "MATERIAL").put("title", "Materyal")); // tarih yok
        notice(l, theirs, obj().put("type", "EXAM").put("title", "Baska ders sinavi").put("eventAt", FUTURE.toString()));
        JsonNode up = call(s, get("/api/my-courses/upcoming"), 200);
        List<String> titles = new ArrayList<>();
        up.forEach(n -> titles.add(n.get("title").asText()));
        assertEquals(List.of("Odev", "C-1", "Final"), titles);
        assertEquals("Veri Yapıları", up.get(0).get("courseName").asText());
        assertEquals(mine, up.get(0).get("courseId").asLong());
        assertTrue(up.get(0).get("files").isArray());
        assertEquals(List.of("Baska ders sinavi"), titlesOf(call(other, get("/api/my-courses/upcoming"), 200)));
        assertEquals(0, call(student("Kayitsiz"), get("/api/my-courses/upcoming"), 200).size());
    }

    private static List<String> titlesOf(JsonNode arr) {
        List<String> t = new ArrayList<>();
        arr.forEach(n -> t.add(n.get("title").asText()));
        return t;
    }

    // ---- dosyalar ----

    @Test
    void everyAllowedTypeUploadsAndRejectedOnesGetOneCode() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        // izinli turler (her cagri bekleyen dosya; en cok 5 oldugundan once baglayip bosaltiriz)
        byte[][] oks = {NoticeFileSnifferTest.pdf(), NoticeFileSnifferTest.png(), NoticeFileSnifferTest.jpg(),
                "duz metin".getBytes(StandardCharsets.UTF_8), NoticeFileSnifferTest.ole("WordDocument")};
        String[] names = {"a.pdf", "b.png", "c.jpg", "d.txt", "e.doc"};
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < oks.length; i++) {
            JsonNode f = upload(l, courseId, names[i], oks[i], 201);
            assertEquals(names[i], f.get("name").asText());
            assertEquals(oks[i].length, f.get("sizeBytes").asLong());
            ids.add(f.get("id").asLong());
        }
        // altinci bekleyen dosya
        expectCode(upload(l, courseId, "f.pdf", NoticeFileSnifferTest.pdf(), 422), "NOTICE_FILE_LIMIT");
        ArrayNode arr = OM.createArrayNode();
        ids.forEach(arr::add);
        JsonNode n = notice(l, courseId, (ObjectNode) obj().put("type", "MATERIAL").put("title", "Paket").set("fileIds", arr));
        assertEquals(5, n.get("files").size());
        // ayni dosya iki kez baglanamaz
        expectError(l, postJson("/api/academician/courses/" + courseId + "/notices",
                obj().put("type", "MATERIAL").put("title", "Tekrar").set("fileIds", OM.createArrayNode().add(ids.get(0)))), 400, "AC_FIELD_INVALID");

        byte[] docx = NoticeFileSnifferTest.ooxml("word/", "<Types/>");
        byte[] xlsx = NoticeFileSnifferTest.ooxml("xl/", "<Types/>");
        byte[] pptx = NoticeFileSnifferTest.ooxml("ppt/", "<Types/>");
        for (Object[] c : new Object[][] {{"g.docx", docx}, {"h.xlsx", xlsx}, {"i.pptx", pptx}, {"j.xls", NoticeFileSnifferTest.ole("Workbook")},
                {"k.ppt", NoticeFileSnifferTest.ole("PowerPoint Document")}}) {
            JsonNode f = upload(l, courseId, (String) c[0], (byte[]) c[1], 201);
            call(l, delete("/api/academician/notice-files/" + f.get("id").asLong()), 204);
        }

        // reddedilenler
        byte[] exe = {'M', 'Z', (byte) 0x90, 0, 3, 0, 0, 0};
        String macro = "<Types><Override ContentType=\"application/vnd.ms-word.document.macroEnabled.main+xml\"/></Types>";
        List<Object[]> bad = List.of(new Object[] {"evil.pdf", exe}, new Object[] {"x.exe", exe},
                new Object[] {"m.docm", NoticeFileSnifferTest.ooxml("word/", macro)},
                new Object[] {"m2.docx", NoticeFileSnifferTest.ooxml("word/", macro)},
                new Object[] {"p.html", "<html><script>1</script></html>".getBytes(StandardCharsets.UTF_8)},
                new Object[] {"p.svg", "<svg onload=alert(1)/>".getBytes(StandardCharsets.UTF_8)},
                new Object[] {"p.txt", "<!doctype html><html>".getBytes(StandardCharsets.UTF_8)},
                new Object[] {"z.zip", new byte[] {'P', 'K', 3, 4}}, new Object[] {"s.sh", "echo".getBytes(StandardCharsets.UTF_8)},
                new Object[] {"t.pdf", NoticeFileSnifferTest.png()}, new Object[] {"empty.pdf", new byte[0]});
        // once bekleyenleri bosalt (5 dosya)
        for (Long id : ids) {
            // baglananlar silinemez (duyuruya bagli): kalan bekleyen yok
            assertEquals(404, raw(l, delete("/api/academician/notice-files/" + id)).getStatus());
        }
        for (Object[] c : bad) {
            expectCode(upload(l, courseId, (String) c[0], (byte[]) c[1], 422), "NOTICE_FILE_TYPE_NOT_ALLOWED");
        }
        // dosya kabul edilmeyen turlere baglanamaz; baskasinin dosyasi baglanamaz
        JsonNode mine = upload(l, courseId, "ok.pdf", NoticeFileSnifferTest.pdf(), 201);
        expectError(l, postJson("/api/academician/courses/" + courseId + "/notices", obj().put("type", "LESSON_CANCELLED")
                .put("eventAt", FUTURE.toString()).set("fileIds", OM.createArrayNode().add(mine.get("id").asLong()))), 400, "AC_FIELD_INVALID");
        User other = lecturer("Baska");
        long otherCourse = course(other);
        expectError(other, postJson("/api/academician/courses/" + otherCourse + "/notices", obj().put("type", "MATERIAL").put("title", "x")
                .set("fileIds", OM.createArrayNode().add(mine.get("id").asLong()))), 400, "AC_FIELD_INVALID");
        // 6 kimlik: limit
        expectError(l, postJson("/api/academician/courses/" + courseId + "/notices", obj().put("type", "MATERIAL").put("title", "x")
                .set("fileIds", OM.createArrayNode().add(1).add(2).add(3).add(4).add(5).add(6))), 422, "NOTICE_FILE_LIMIT");
        // yukleme hiz siniri baglantisi
        verify(limiter, atLeastOnce()).check(eq("acad-upload:user:" + l.getId()), eq(30), eq(Duration.ofMinutes(1)));
    }

    private void expectCode(JsonNode body, String code) {
        assertEquals(code, body.get("code").asText(), String.valueOf(body));
    }

    @Test
    void oversizeFileIsRejected() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        byte[] big = new byte[(20 << 20) + 1];
        System.arraycopy(NoticeFileSnifferTest.pdf(), 0, big, 0, 8);
        expectCode(upload(l, courseId, "big.pdf", big, 413), "NOTICE_FILE_TOO_LARGE");
        assertEquals(0, fileRepo.findAll().stream().filter(f -> f.getCourseId().equals(courseId)).count());
    }

    @Test
    void courseStorageCapIsEnforced() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        AcNoticeFile fat = new AcNoticeFile();
        fat.setCourseId(courseId);
        fat.setStorageKey("fake-" + rnd() + ".bin");
        fat.setOriginalName("kapasite.pdf");
        fat.setContentType("application/pdf");
        fat.setSizeBytes(500L * 1024 * 1024 - 10);
        fat.setUploadedBy(l.getId());
        fileRepo.save(fat);
        expectCode(upload(l, courseId, "tasan.pdf", NoticeFileSnifferTest.pdf(), 422), "NOTICE_STORAGE_CAP");
    }

    @Test
    void downloadIsAuthorisedExactAndSafeAndDeletionRemovesStoredObjects() throws Exception {
        User l = lecturer("Hoca");
        User other = lecturer("Baska");
        User member = student("Kayitli");
        User outsider = student("Kayitsiz");
        User adm = admin();
        long courseId = course(l);
        enrol(l, courseId, member);

        byte[] content = NoticeFileSnifferTest.pdf();
        // yol gezintisi ve kontrol karakterli ad temizlenir
        JsonNode f1 = upload(l, courseId, "../../etc/pass\u0000wd\r\n.pdf", content, 201);
        assertEquals("passwd.pdf", f1.get("name").asText());
        assertEquals("application/pdf", f1.get("contentType").asText());
        JsonNode f2 = upload(l, courseId, "Sinav \"notu\".txt", "merhaba".getBytes(StandardCharsets.UTF_8), 201);
        ObjectNode body = obj().put("type", "ASSIGNMENT").put("title", "Odev").put("eventAt", FUTURE.toString());
        body.set("fileIds", OM.createArrayNode().add(f1.get("id").asLong()).add(f2.get("id").asLong()));
        JsonNode n = notice(l, courseId, body);
        long noticeId = n.get("id").asLong();
        assertEquals(2, n.get("files").size());
        long fileId = n.get("files").get(0).get("id").asLong();
        assertEquals(Set3.of("id", "name", "contentType", "sizeBytes"), Set3.names(n.get("files").get(0)));
        String studentUrl = "/api/my-courses/" + courseId + "/notices/" + noticeId + "/files/" + fileId;
        String ownerUrl = "/api/academician/notices/" + noticeId + "/files/" + fileId;
        String adminUrl = "/api/admin/academicians/notices/" + noticeId + "/files/" + fileId;

        // kayitli ogrenci birebir ayni baytlari alir; basliklar guvenli
        MockHttpServletResponse res = raw(member, get(studentUrl));
        assertEquals(200, res.getStatus());
        assertArrayEquals(content, res.getContentAsByteArray());
        assertEquals("application/pdf", res.getContentType());
        assertTrue(res.getHeader("Content-Disposition").startsWith("attachment"), res.getHeader("Content-Disposition"));
        assertTrue(res.getHeader("Content-Disposition").contains("passwd.pdf"));
        assertEquals("nosniff", res.getHeader("X-Content-Type-Options"));
        assertTrue(res.getHeader("Cache-Control").contains("no-store"));
        assertFalse(res.getHeader("Cache-Control").contains("public"));
        // sahibi ve yonetici de indirir
        assertArrayEquals(content, raw(l, get(ownerUrl)).getContentAsByteArray());
        assertEquals(200, raw(adm, get(adminUrl)).getStatus());
        // diger herkes 404 (varlik sizmaz)
        assertEquals(404, raw(outsider, get(studentUrl)).getStatus());
        assertEquals(404, raw(other, get(ownerUrl)).getStatus());
        assertEquals(403, raw(member, get(ownerUrl)).getStatus()); // akademisyen degil
        assertEquals(404, raw(member, get("/api/my-courses/" + (courseId + 999) + "/notices/" + noticeId + "/files/" + fileId)).getStatus());
        assertEquals(404, raw(member, get("/api/my-courses/" + courseId + "/notices/" + noticeId + "/files/" + (fileId + 999))).getStatus());
        assertEquals(403, raw(student("x"), get(adminUrl)).getStatus());
        // herkese acik URL yok: depo anahtari /files altinda servis edilmez
        List<AcNoticeFile> rows = fileRepo.findAll().stream().filter(f -> f.getCourseId().equals(courseId)).toList();
        assertEquals(2, rows.size());
        for (AcNoticeFile f : rows) {
            assertNotNull(store.read("acnotice", f.getStorageKey()));
            assertFalse(n.toString().contains(f.getStorageKey()), "depo anahtari API'ye sizdi");
        }
        List<String> keys = rows.stream().map(AcNoticeFile::getStorageKey).toList();

        // duyuru silinince satirlar VE depodaki nesneler gider
        call(l, delete("/api/academician/notices/" + noticeId), 204);
        for (String k : keys) {
            assertNull(store.read("acnotice", k));
        }
        assertEquals(0, fileRepo.findAll().stream().filter(f -> f.getCourseId().equals(courseId)).count());
        assertEquals(404, raw(member, get(studentUrl)).getStatus());

        // ders silinince de nesneler gider
        JsonNode f3 = upload(l, courseId, "c.pdf", content, 201);
        notice(l, courseId, (ObjectNode) obj().put("type", "MATERIAL").put("title", "m").set("fileIds", OM.createArrayNode().add(f3.get("id").asLong())));
        AcNoticeFile stored = fileRepo.findAll().stream().filter(f -> f.getCourseId().equals(courseId)).findFirst().orElseThrow();
        assertNotNull(store.read("acnotice", stored.getStorageKey()));
        call(l, delete("/api/academician/courses/" + courseId), 204);
        assertNull(store.read("acnotice", stored.getStorageKey()));
        assertEquals(0, fileRepo.findAll().stream().filter(f -> f.getCourseId().equals(courseId)).count());
    }

    /** Kucuk yardimci: alan adlari kumesi. */
    static final class Set3 {
        static java.util.Set<String> of(String... a) {
            return java.util.Set.of(a);
        }

        static java.util.Set<String> names(JsonNode n) {
            java.util.Set<String> s = new java.util.HashSet<>();
            n.fieldNames().forEachRemaining(s::add);
            return s;
        }
    }
}
