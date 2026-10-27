package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** Kesfet gonderi moderasyonu denetim kapsami: yazmalar ve yonetici medya onizlemesi denetlenir, listeler degil. */
class AuditPostPathsTest {

    @Test
    void writesAndMediaPreviewAreAudited() {
        assertTrue(AuditRecorder.shouldAudit("POST", "/api/admin/posts/1/hide"));
        assertTrue(AuditRecorder.shouldAudit("POST", "/api/admin/posts/1/unhide"));
        assertTrue(AuditRecorder.shouldAudit("DELETE", "/api/admin/posts/1"));
        assertTrue(AuditRecorder.shouldAudit("POST", "/api/admin/comments/9/hide"));
        assertTrue(AuditRecorder.shouldAudit("DELETE", "/api/admin/comments/9"));
        assertTrue(AuditRecorder.shouldAudit("GET", "/api/admin/posts/media/4"));
    }

    @Test
    void plainReadsAreNotAudited() {
        assertFalse(AuditRecorder.shouldAudit("GET", "/api/admin/posts"));
        assertFalse(AuditRecorder.shouldAudit("GET", "/api/admin/posts/stats"));
        assertFalse(AuditRecorder.shouldAudit("GET", "/api/admin/posts/7/comments"));
    }
}
