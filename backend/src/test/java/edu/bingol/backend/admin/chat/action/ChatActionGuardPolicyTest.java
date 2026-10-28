package edu.bingol.backend.admin.chat.action;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.admin.AdminGuardPolicy;
import org.junit.jupiter.api.Test;

/** P08: sohbet mudahalesi yazma uclari sebep ister ve yikici (saatlik siki sinir) sayilir; okumalar sayilmaz. */
class ChatActionGuardPolicyTest {

    @Test
    void chatWritesNeedReason() {
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/messages/12/hide"));
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/messages/12/unhide"));
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/messages/bulk-hide"));
        assertEquals(5, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/messages/12"));
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/conversations/3/close"));
        assertEquals(5, AdminGuardPolicy.reasonMin("POST", "/api/admin/conversations/3/reopen"));
        assertEquals(5, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/conversations/3/members/9"));
    }

    @Test
    void chatWritesAreDestructive() {
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/messages/12/hide"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/messages/12"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/messages/bulk-hide"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/conversations/3/close"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/conversations/3/members/9"));
    }

    @Test
    void readsAndUnrelatedPathsAreNotAffected() {
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/conversations/3"));
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/conversations/3/export"));
        assertEquals(0, AdminGuardPolicy.reasonMin("GET", "/api/admin/messages/12"));
        assertFalse(AdminGuardPolicy.destructive("GET", "/api/admin/conversations/3"));
        assertEquals(0, AdminGuardPolicy.reasonMin("POST", "/api/admin/messages/12/other"));
        assertEquals(0, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/messages/12/extra"));
        assertEquals(0, AdminGuardPolicy.reasonMin("POST", "/api/admin/users/3/conversations"));
    }
}
