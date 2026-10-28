package edu.bingol.backend.community.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminGuardPolicy;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityPost;
import edu.bingol.backend.community.CommunityPostRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/** Yikici kulup islemleri SEBEP ister (400 REASON_REQUIRED); sebep basliktan ya da govdeden kabul edilir. */
@SpringBootTest(properties = "app.admin.require-reason=true")
class ClubAdminReasonTest {

    private static final ObjectMapper OM = new ObjectMapper();

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired CommunityRepository communities;
    @Autowired CommunityMemberRepository members;
    @Autowired CommunityPostRepository posts;
    @MockitoBean RateLimiter limiter;
    /** Sohbet odasi SQL'i PostgreSQL'e ozeldir (H2'de calismaz). */
    @MockitoBean RoomConversations rooms;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class)).apply(springSecurity()).build();
    }

    private MockHttpServletResponse call(MockHttpServletRequestBuilder b) throws Exception {
        var admin = new UsernamePasswordAuthenticationToken(990001L, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        return mvc.perform(b.with(authentication(admin))).andReturn().getResponse();
    }

    private User user(String name) {
        User u = new User();
        u.setEmail(name.toLowerCase() + "." + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private Community club(User owner) {
        Community c = new Community();
        c.setName("Sebep " + UUID.randomUUID().toString().substring(0, 6));
        c.setSlug("p06r-" + UUID.randomUUID().toString().substring(0, 8));
        c.setOwnerId(owner.getId());
        c.setStatus(Community.Status.ACTIVE);
        communities.save(c);
        members.save(new CommunityMember(c.getId(), owner.getId(), Role.OWNER, CommunityMember.Status.ACTIVE));
        return c;
    }

    private static String code(MockHttpServletResponse r) throws Exception {
        return OM.readTree(r.getContentAsString()).get("code").asText();
    }

    @Test
    void destructiveClubActionsRequireAReason() throws Exception {
        User owner = user("Sebep");
        User other = user("Sebep Uye");
        Community c = club(owner);
        members.save(new CommunityMember(c.getId(), other.getId(), Role.MEMBER, CommunityMember.Status.ACTIVE));
        String base = "/api/admin/communities/" + c.getId();

        List<MockHttpServletRequestBuilder> noReason = List.of(
                post(base + "/close").contentType("application/json").content("{}"),
                post(base + "/reopen").contentType("application/json").content("{}"),
                post(base + "/transfer-ownership").contentType("application/json").content("{\"targetUserId\":" + other.getId() + "}"),
                patch(base + "/members/" + other.getId() + "/role").contentType("application/json").content("{\"role\":\"MODERATOR\"}"),
                delete(base + "/members/" + other.getId()),
                delete(base + "/invites/1"),
                delete(base));
        for (MockHttpServletRequestBuilder b : noReason) {
            MockHttpServletResponse r = call(b);
            assertEquals(400, r.getStatus(), b.toString() + " " + r.getContentAsString());
            assertEquals("REASON_REQUIRED", code(r), b.toString());
        }
        // kisa sebep (5 karakterden az) de reddedilir
        assertEquals("REASON_REQUIRED", code(call(post(base + "/close").contentType("application/json").content("{\"reason\":\"ab\"}"))));

        // hicbiri uygulanmadi
        assertEquals(Community.Status.ACTIVE, communities.findById(c.getId()).orElseThrow().getStatus());
        assertEquals(owner.getId(), communities.findById(c.getId()).orElseThrow().getOwnerId());

        // govdeden sebep: kabul
        assertEquals(200, call(post(base + "/close").contentType("application/json").content("{\"reason\":\"yeterli sebep\"}")).getStatus());
        // basliktan sebep (yuzde-kodlu Turkce): kabul
        MockHttpServletResponse reopen = call(post(base + "/reopen").header("X-Admin-Reason", "%C3%A7ok%20iyi%20sebep"));
        assertEquals(200, reopen.getStatus(), reopen.getContentAsString());
    }

    @Test
    void postDeletionRequiresReasonButHideAndEditDoNot() throws Exception {
        User owner = user("Gonderi Sebep");
        Community c = club(owner);
        CommunityPost p = new CommunityPost();
        p.setCommunityId(c.getId());
        p.setAuthorId(owner.getId());
        p.setContent("Metin");
        posts.save(p);
        String base = "/api/admin/community-posts/" + p.getId();

        assertEquals("REASON_REQUIRED", code(call(delete(base))));
        assertFalse(posts.findById(p.getId()).orElseThrow().isDeleted());
        assertEquals(200, call(post(base + "/hide").contentType("application/json").content("{}")).getStatus());
        assertEquals(200, call(patch(base).contentType("application/json").content("{\"text\":\"Yeni\"}")).getStatus());
        assertEquals(200, call(delete(base).contentType("application/json").content("{\"reason\":\"gecerli sebep\"}")).getStatus());
        assertTrue(posts.findById(p.getId()).orElseThrow().isDeleted());
    }

    @Test
    void policyTableMarksClubActionsDestructiveAndLeavesReadsAlone() {
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/communities/5/close"));
        assertTrue(AdminGuardPolicy.destructive("POST", "/api/admin/communities/5/transfer-ownership"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/communities/5"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/communities/5/members/9"));
        assertTrue(AdminGuardPolicy.destructive("PATCH", "/api/admin/communities/5/members/9/role"));
        assertTrue(AdminGuardPolicy.destructive("DELETE", "/api/admin/community-posts/5"));
        assertEquals(AdminGuardPolicy.DEFAULT_MIN_REASON, AdminGuardPolicy.reasonMin("DELETE", "/api/admin/communities/5"));
        assertFalse(AdminGuardPolicy.destructive("PATCH", "/api/admin/communities/5"));
        assertFalse(AdminGuardPolicy.destructive("GET", "/api/admin/communities/5"));
        assertFalse(AdminGuardPolicy.destructive("POST", "/api/admin/communities/5/approve"));
        assertFalse(AdminGuardPolicy.destructive("POST", "/api/admin/community-posts/5/hide"));
        assertEquals(0, AdminGuardPolicy.reasonMin("POST", "/api/admin/community-posts/5/unhide"));
    }
}
