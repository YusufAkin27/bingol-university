package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import com.fasterxml.jackson.databind.JsonNode;
import edu.bingol.backend.user.User;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/** Tarama kontrol sirasi, arsivli ders, hoca elle kayit sonrasi tarama ve hiz siniri anahtarlari: ek yoklama testleri. */
class AcademicianScanOrderProbeMvcTest extends AcademicianMvcBase {

    @Autowired AcScanRequestRepository scanRequests;

    @Test
    void archivedCourseScanIsTheGenericInvalidErrorAndCreatesNoRequest() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User member = student("Uye");
        User outsider = student("Disarida");
        enrol(l, courseId, member);
        long sid = openSession(l, courseId);
        String code = code(l, sid);
        call(l, MockMvcRequestBuilders.patch("/api/academician/courses/" + courseId).contentType("application/json")
                .content("{\"status\":\"ARCHIVED\"}"), 200);
        long before = scanRequests.count();
        expectError(member, scanReq(code), 422, "ATTENDANCE_CODE_INVALID");
        expectError(outsider, scanReq(code), 422, "ATTENDANCE_CODE_INVALID");
        assertEquals(before, scanRequests.count());
        assertEquals(0, attendRepo.countActive(sid));
    }

    @Test
    void closedSessionChecksComeBeforeEnrolmentSoOutsiderCreatesNoRequest() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User member = student("Uye");
        User outsider = student("Disarida");
        enrol(l, courseId, member);
        long sid = openSession(l, courseId);
        String code = code(l, sid);
        call(l, postJsonNoBody("/api/academician/sessions/" + sid + "/close"), 200);
        long before = scanRequests.count();
        expectError(outsider, scanReq(code), 422, "ATTENDANCE_CODE_INVALID");
        expectError(member, scanReq(code), 422, "ATTENDANCE_CODE_INVALID");
        assertEquals(before, scanRequests.count());
    }

    @Test
    void dismissedStudentEnrolledManuallyLaterCanScanAndIsMarked() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        long sid = openSession(l, courseId);
        String code = code(l, sid);
        User s = student("Reddedilen");
        assertEquals("PENDING", scan(s, code).get("status").asText());
        call(l, postJsonNoBody("/api/academician/sessions/" + sid + "/pending/" + s.getId() + "/dismiss"), 204);
        expectError(s, scanReq(code), 403, "ATTENDANCE_NOT_ENROLLED");
        enrol(l, courseId, s);
        assertEquals("MARKED", scan(s, code).get("status").asText());
        assertEquals(1, attendRepo.countActive(sid));
    }

    @Test
    void studentRemovedFromCourseLosesNoticeAndFileAccessAndScansBecomePending() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Cikarilan");
        enrol(l, courseId, s);
        JsonNode n = call(l, postJson("/api/academician/courses/" + courseId + "/notices",
                obj().put("type", "MATERIAL").put("title", "Ders notu")), 201);
        long noticeId = n.get("id").asLong();
        assertEquals(200, raw(s, get("/api/my-courses/" + courseId + "/notices")).getStatus());
        call(l, delete("/api/academician/courses/" + courseId + "/enrollments/" + s.getId()), 204);
        expectError(s, get("/api/my-courses/" + courseId + "/notices"), 403, "ATTENDANCE_NOT_ENROLLED");
        assertFalse(call(s, get("/api/my-courses/upcoming"), 200).toString().contains("\"id\":" + noticeId));
        long sid = openSession(l, courseId);
        assertEquals("PENDING", scan(s, code(l, sid)).get("status").asText());
    }

    @Test
    void scanUploadAndNoticeEndpointsUseTheSpecifiedRateLimitKeysAndBudgets() throws Exception {
        User l = lecturer("Hoca");
        long courseId = course(l);
        User s = student("Okutan");
        enrol(l, courseId, s);
        long sid = openSession(l, courseId);
        scan(s, code(l, sid));
        verify(limiter, atLeastOnce()).check(eq("attendance-scan:user:" + s.getId()), eq(10), eq(Duration.ofMinutes(1)));
        verify(limiter, atLeastOnce()).check(startsWith("attendance-scan:ip:"), eq(60), eq(Duration.ofMinutes(1)));
        call(l, postJson("/api/academician/courses/" + courseId + "/notices", obj().put("type", "LESSON_STARTED")), 201);
        verify(limiter, atLeastOnce()).check(eq("acad-notice:user:" + l.getId()), eq(60), eq(Duration.ofMinutes(1)));
        raw(l, MockMvcRequestBuilders.multipart("/api/academician/courses/" + courseId + "/notice-files")
                .file(new org.springframework.mock.web.MockMultipartFile("file", "a.pdf", "application/pdf", NoticeFileSnifferTest.pdf())));
        verify(limiter, atLeastOnce()).check(eq("acad-upload:user:" + l.getId()), eq(30), eq(Duration.ofMinutes(1)));
        // yanlis sinir degeri kabul edilmez: 10/dk disinda bir tarama kovasi yok
        verify(limiter, org.mockito.Mockito.never()).check(startsWith("attendance-scan:user:"), eq(60), any(Duration.class));
        verify(limiter, org.mockito.Mockito.never()).check(startsWith("attendance-scan:ip:"), eq(10), any(Duration.class));
    }

    private static org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder postJsonNoBody(String url) {
        return postJson(url, null);
    }
}
