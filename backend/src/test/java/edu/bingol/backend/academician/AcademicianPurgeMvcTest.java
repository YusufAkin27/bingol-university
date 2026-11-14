package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.JsonNode;
import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.user.User;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;

/** Hesap silme (AcademicianAccountPurger; genel AccountDataPurger bagi ayri testte) (satirlar silinir, "kim yapti" izleri bosalir, depo nesneleri gider) ve KVKK disa aktarimi (yalniz kendi satirlari). */
class AcademicianPurgeMvcTest extends AcademicianMvcBase {

    @Autowired AcademicianAccountPurger purger;
    @Autowired AcScanRequestRepository scanRequests;
    @Autowired AcNoticeRepository noticeRepo;
    @Autowired AcNoticeFileRepository fileRepo;
    @Autowired AcCourseSlotRepository slotRepo;
    @Autowired PrivateMediaStore store;
    @Autowired List<DataExporter> exporters;

    private DataExporter exporter(String section) {
        return exporters.stream().filter(e -> e.section().equals(section)).findFirst().orElseThrow();
    }

    @Test
    void purgingALecturerRemovesEverythingAndNullsTraceColumnsInOthersData() throws Exception {
        User admin = admin();
        User l = plainUser("hoca." + rnd() + "@gmail.com", "Silinecek Hoca");
        call(l, postJson("/api/academician/apply", obj().put("title", "Dr.").put("firstName", "A").put("lastName", "B")), 200);
        call(admin, post("/api/admin/academicians/" + l.getId() + "/approve"), 200);
        assertEquals(admin.getId(), academicianRepo.findById(l.getId()).orElseThrow().getReviewedBy());

        long courseId = course(l);
        call(l, org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/academician/courses/" + courseId + "/slots")
                .contentType("application/json").content("[{\"dayOfWeek\":2,\"startTime\":\"10:00\",\"endTime\":\"12:00\"}]"), 200);
        User s = student("Ogrenci");
        User pendingStudent = student("Bekleyen");
        enrol(l, courseId, s);
        long sid = openSession(l, courseId);
        scan(s, code(l, sid));
        scan(pendingStudent, code(l, sid)); // bekleyen istek
        JsonNode f = call(l, multipart("/api/academician/courses/" + courseId + "/notice-files")
                .file(new MockMultipartFile("file", "a.pdf", "application/pdf", NoticeFileSnifferTest.pdf())), 201);
        ObjectNode n = obj().put("type", "MATERIAL").put("title", "M");
        n.set("fileIds", OM.createArrayNode().add(f.get("id").asLong()));
        call(l, postJson("/api/academician/courses/" + courseId + "/notices", n), 201);
        String key = fileRepo.findAll().stream().filter(x -> x.getCourseId().equals(courseId)).findFirst().orElseThrow().getStorageKey();
        assertNotNull(store.read("acnotice", key));

        // BASKASININ verisindeki izler: bu hocanin id'si marked_by/revoked_by/created_by/decided_by/uploaded_by
        User otherLecturer = lecturer("Baska Hoca");
        long otherCourse = course(otherLecturer);
        User os = student("Baskasinin Ogrencisi");
        enrol(otherLecturer, otherCourse, os);
        long otherSession = openSession(otherLecturer, otherCourse);
        AcAttendance att = new AcAttendance();
        att.setSessionId(otherSession);
        att.setStudentId(os.getId());
        att.setMethod(AcAttendance.Method.MANUAL);
        att.setMarkedBy(l.getId());
        att.setRevokedAt(Instant.now());
        att.setRevokedBy(l.getId());
        att = attendRepo.save(att);
        AcNotice other = new AcNotice();
        other.setCourseId(otherCourse);
        other.setType(AcNotice.Type.MATERIAL);
        other.setTitle("x");
        other.setCreatedBy(l.getId());
        other = noticeRepo.save(other);
        AcScanRequest req = new AcScanRequest();
        req.setSessionId(otherSession);
        req.setStudentId(os.getId());
        req.setScannedAt(Instant.now());
        req.setStatus(AcScanRequest.Status.DISMISSED);
        req.setDecidedBy(l.getId());
        req = scanRequests.save(req);
        AcNoticeFile of = new AcNoticeFile();
        of.setCourseId(otherCourse);
        of.setNoticeId(other.getId());
        of.setStorageKey("nobody-" + rnd() + ".bin");
        of.setOriginalName("o.pdf");
        of.setContentType("application/pdf");
        of.setSizeBytes(1);
        of.setUploadedBy(l.getId());
        of = fileRepo.save(of);

        purger.purge(l.getId());

        assertTrue(academicianRepo.findById(l.getId()).isEmpty());
        assertTrue(courseRepo.findById(courseId).isEmpty());
        assertEquals(0, slotRepo.findTop30ByCourseIdOrderByDayOfWeekAscStartTimeAsc(courseId).size());
        assertEquals(0, enrollRepo.countByCourseId(courseId));
        assertEquals(0, sessionRepo.countByCourseId(courseId));
        assertEquals(0, attendRepo.findAll().stream().filter(a -> a.getSessionId().equals(sid)).count());
        assertEquals(0, scanRequests.findAll().stream().filter(r -> r.getSessionId().equals(sid)).count());
        assertEquals(0, noticeRepo.findAll().stream().filter(x -> x.getCourseId().equals(courseId)).count());
        assertEquals(0, fileRepo.findAll().stream().filter(x -> x.getCourseId().equals(courseId)).count());
        assertNull(store.read("acnotice", key), "depo nesnesi silinmeli");
        // baskasinin verisi durur, izler bosalir
        assertNull(attendRepo.findById(att.getId()).orElseThrow().getMarkedBy());
        assertNull(attendRepo.findById(att.getId()).orElseThrow().getRevokedBy());
        assertNull(noticeRepo.findById(other.getId()).orElseThrow().getCreatedBy());
        assertNull(scanRequests.findById(req.getId()).orElseThrow().getDecidedBy());
        assertNull(fileRepo.findById(of.getId()).orElseThrow().getUploadedBy());
        assertTrue(courseRepo.findById(otherCourse).isPresent());
    }

    @Test
    void purgingAStudentRemovesTheirRowsOnlyAndAdminTraceIsNulled() throws Exception {
        User admin = admin();
        User l = plainUser("hoca." + rnd() + "@gmail.com", "Hoca");
        call(l, postJson("/api/academician/apply", obj().put("title", "Dr.").put("firstName", "A").put("lastName", "B")), 200);
        call(admin, post("/api/admin/academicians/" + l.getId() + "/approve"), 200);
        long courseId = course(l);
        User s = student("Silinecek Ogrenci");
        User keep = student("Kalan Ogrenci");
        enrol(l, courseId, s, keep);
        long sid = openSession(l, courseId);
        String code = code(l, sid);
        scan(s, code);
        scan(keep, code);
        User out = student("Kayitsiz");
        scan(out, code);

        purger.purge(s.getId());
        assertFalse(enrollRepo.existsByCourseIdAndStudentId(courseId, s.getId()));
        assertFalse(attendRepo.existsBySessionIdAndStudentId(sid, s.getId()));
        assertTrue(enrollRepo.existsByCourseIdAndStudentId(courseId, keep.getId()));
        assertTrue(attendRepo.existsBySessionIdAndStudentId(sid, keep.getId()));
        purger.purge(out.getId());
        assertTrue(scanRequests.findBySessionIdAndStudentId(sid, out.getId()).isEmpty());

        // karar veren yonetici silinirse reviewed_by bosalir; akademisyen satiri kalir
        purger.purge(admin.getId());
        Academician a = academicianRepo.findById(l.getId()).orElseThrow();
        assertNull(a.getReviewedBy());
        assertEquals(Academician.Status.APPROVED, a.getStatus());
    }

    @Test
    void exportersReturnOnlyTheRequestingUsersRows() throws Exception {
        User l = lecturer("Hoca Bir");
        User l2 = lecturer("Hoca Iki");
        long c1 = course(l);
        long c2 = course(l2);
        User s1 = student("Ogrenci Bir");
        User s2 = student("Ogrenci Iki");
        enrol(l, c1, s1);
        enrol(l, c1, s2);
        enrol(l2, c2, s2);
        long sess1 = openSession(l, c1);
        long sess2 = openSession(l2, c2);
        scan(s1, code(l, sess1));
        scan(s2, code(l, sess1));
        scan(s2, code(l2, sess2));

        @SuppressWarnings("unchecked")
        Map<String, Object> e1 = (Map<String, Object>) exporter("courseAttendance").export(s1.getId());
        assertEquals(1, ((List<?>) e1.get("records")).size());
        assertEquals(1, ((List<?>) e1.get("enrolledCourses")).size());
        String text1 = e1.toString();
        assertFalse(text1.contains("Ogrenci Iki"));
        assertFalse(text1.contains(s2.getEmail()));
        @SuppressWarnings("unchecked")
        Map<String, Object> e2 = (Map<String, Object>) exporter("courseAttendance").export(s2.getId());
        assertEquals(2, ((List<?>) e2.get("records")).size());
        assertEquals(0, ((List<?>) ((Map<?, ?>) exporter("courseAttendance").export(student("Hic").getId())).get("records")).size());

        @SuppressWarnings("unchecked")
        Map<String, Object> a1 = (Map<String, Object>) exporter("academician").export(l.getId());
        assertEquals("APPROVED", a1.get("status"));
        assertEquals(1, ((List<?>) a1.get("courses")).size());
        assertEquals(0, ((Map<?, ?>) exporter("academician").export(s1.getId())).size()); // akademisyen degil
    }
}
