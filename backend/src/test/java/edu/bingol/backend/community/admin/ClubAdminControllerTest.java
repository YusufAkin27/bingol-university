package edu.bingol.backend.community.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verify;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.admin.AdminReasonFilter;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityPost;
import edu.bingol.backend.community.CommunityPostRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.moderation.ReportRepository;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Yonetici kulup yonetimi + kulup icerigi moderasyonu (HTTP sozlesmesi, H2): yetki, liste/suzgec/siralama/CSV,
 * ayrinti, duzenleme, kapat/yeniden ac, silme, uye cikarma/rol, zorla devir, katilim istegi, gonderi/duyuru
 * gizle/duzenle/sil ve denetim hedefi (COMMUNITY / COMMUNITY_POST). Sebep zorunlulugu ClubAdminReasonTest'tedir.
 */
@SpringBootTest
class ClubAdminControllerTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final long ADMIN_ID = 990001L;

    @Autowired WebApplicationContext ctx;
    @Autowired UserRepository users;
    @Autowired CommunityRepository communities;
    @Autowired CommunityMemberRepository members;
    @Autowired CommunityPostRepository posts;
    @Autowired ReportRepository reports;
    /** Testlerde Redis yok: hiz siniri sahte. */
    @MockitoBean RateLimiter limiter;
    /** Sohbet odasi ve rapor kararlari PostgreSQL'e ozel SQL (ON CONFLICT) kullanir: H2'de sahte (duman betigi dogrular). */
    @MockitoBean RoomConversations rooms;
    @MockitoBean ReportService reportService;
    MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(ctx).addFilters(ctx.getBean(AdminReasonFilter.class)).apply(springSecurity()).build();
    }

    // ---- yardimcilar ----

    private static UsernamePasswordAuthenticationToken admin() {
        return new UsernamePasswordAuthenticationToken(ADMIN_ID, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static UsernamePasswordAuthenticationToken plainUser() {
        return new UsernamePasswordAuthenticationToken(990002L, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    }

    private MvcResult run(MockHttpServletRequestBuilder b) throws Exception {
        return mvc.perform(b.with(authentication(admin()))).andReturn();
    }

    private JsonNode json(MvcResult r, int status) throws Exception {
        MockHttpServletResponse res = r.getResponse();
        assertEquals(status, res.getStatus(), res.getContentAsString());
        String body = res.getContentAsString();
        return body.isEmpty() ? null : OM.readTree(body);
    }

    private static String code(MvcResult r) throws Exception {
        return OM.readTree(r.getResponse().getContentAsString()).get("code").asText();
    }

    private static String tag() {
        return UUID.randomUUID().toString().substring(0, 8);
    }

    private User user(String name) {
        User u = new User();
        u.setEmail(name.toLowerCase().replace(' ', '.') + "." + tag() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.save(u);
    }

    private Community club(String name, User owner, Community.Status status) {
        Community c = new Community();
        c.setName(name);
        c.setSlug("p06-" + tag());
        c.setOwnerId(owner.getId());
        c.setStatus(status);
        c.setCategory("Spor");
        communities.save(c);
        members.save(new CommunityMember(c.getId(), owner.getId(), Role.OWNER, CommunityMember.Status.ACTIVE));
        return c;
    }

    private CommunityMember join(Community c, User u, Role role, CommunityMember.Status st) {
        return members.save(new CommunityMember(c.getId(), u.getId(), role, st));
    }

    private CommunityPost newPost(Community c, User author, String text, boolean announcement) {
        CommunityPost p = new CommunityPost();
        p.setCommunityId(c.getId());
        p.setAuthorId(author.getId());
        p.setContent(text);
        p.setAnnouncement(announcement);
        return posts.save(p);
    }

    private static AuditContext.Data audit(MvcResult r) {
        return AuditContext.of(r.getRequest());
    }

    // ---- yetki ----

    @Test
    void everyEndpointRejectsAnonymousAndPlainUsers() throws Exception {
        List<MockHttpServletRequestBuilder> reqs = List.of(
                get("/api/admin/communities").param("page", "0"),
                get("/api/admin/communities/export.csv"),
                get("/api/admin/communities/1"),
                patch("/api/admin/communities/1").contentType("application/json").content("{\"name\":\"Yeni ad\"}"),
                post("/api/admin/communities/1/close").contentType("application/json").content("{}"),
                post("/api/admin/communities/1/reopen").contentType("application/json").content("{}"),
                delete("/api/admin/communities/1"),
                get("/api/admin/communities/1/members"),
                delete("/api/admin/communities/1/members/2"),
                patch("/api/admin/communities/1/members/2/role").contentType("application/json").content("{\"role\":\"MEMBER\"}"),
                post("/api/admin/communities/1/transfer-ownership").contentType("application/json").content("{\"targetUserId\":2}"),
                get("/api/admin/communities/1/join-requests"),
                post("/api/admin/communities/1/join-requests/2/approve"),
                get("/api/admin/communities/1/invites"),
                get("/api/admin/communities/1/club-audit"),
                get("/api/admin/community-posts"),
                get("/api/admin/community-posts/1"),
                patch("/api/admin/community-posts/1").contentType("application/json").content("{\"text\":\"x\"}"),
                post("/api/admin/community-posts/1/hide").contentType("application/json").content("{}"),
                delete("/api/admin/community-posts/1"));
        for (MockHttpServletRequestBuilder b : reqs) {
            assertEquals(401, mvc.perform(b).andReturn().getResponse().getStatus(), b.toString());
        }
        for (MockHttpServletRequestBuilder b : reqs) {
            assertEquals(403, mvc.perform(b.with(authentication(plainUser()))).andReturn().getResponse().getStatus(), b.toString());
        }
    }

    // ---- liste / suzgec / siralama / eski uc ----

    @Test
    void listIsPagedFilteredSortedAndLegacyQueueStillWorks() throws Exception {
        String m = "Liste" + tag();
        User owner = user("Sahip Bir");
        Community active = club(m + " Aktif", owner, Community.Status.ACTIVE);
        Community pending = club(m + " Bekleyen", owner, Community.Status.PENDING_REVIEW);
        Community gone = club(m + " Silinmis", owner, Community.Status.DELETED);
        join(active, user("Uye Bir"), Role.MEMBER, CommunityMember.Status.ACTIVE);

        JsonNode all = json(run(get("/api/admin/communities").param("page", "0").param("q", m)), 200);
        assertEquals(2, all.get("total").asLong(), "silinmisler varsayilan listede yok");
        assertEquals(0, all.get("page").asInt());
        for (String f : List.of("id", "name", "slug", "status", "visibility", "joinPolicy", "ownerId", "ownerName",
                "ownerEmail", "memberCount", "pendingCount", "openReportCount", "eventCount", "createdAt")) {
            assertTrue(all.get("items").get(0).has(f), "ClubRow." + f);
        }
        JsonNode withDeleted = json(run(get("/api/admin/communities").param("page", "0").param("q", m).param("status", "ALL")), 200);
        assertEquals(3, withDeleted.get("total").asLong());
        JsonNode onlyPending = json(run(get("/api/admin/communities").param("page", "0").param("q", m)
                .param("status", "PENDING_REVIEW")), 200);
        assertEquals(1, onlyPending.get("total").asLong());
        assertEquals(pending.getId(), onlyPending.get("items").get(0).get("id").asLong());

        JsonNode byCount = json(run(get("/api/admin/communities").param("page", "0").param("q", m)
                .param("sort", "memberCount").param("dir", "desc").param("size", "1")), 200);
        assertEquals(1, byCount.get("items").size());
        assertEquals(active.getId(), byCount.get("items").get(0).get("id").asLong(), "2 uyeli kulup basta");
        assertEquals(2, byCount.get("totalPages").asInt());

        assertEquals("VALIDATION_ERROR", code(run(get("/api/admin/communities").param("page", "0").param("sort", "owner_id; DROP"))));
        assertEquals(400, run(get("/api/admin/communities").param("page", "0").param("status", "NOPE")).getResponse().getStatus());
        assertEquals(1, json(run(get("/api/admin/communities").param("page", "0").param("q", m)
                .param("category", "Spor").param("status", "ACTIVE")), 200).get("total").asLong());
        assertEquals(0, json(run(get("/api/admin/communities").param("page", "0").param("q", m)
                .param("category", "Yok")), 200).get("total").asLong());
        // LIKE ozel karakterleri kacirilir: '%' tum satirlari getirmez
        assertEquals(0, json(run(get("/api/admin/communities").param("page", "0").param("q", "%" + m)), 200).get("total").asLong());

        // eski imecli onay kuyrugu ucu degismedi (page yok): items + nextCursor
        JsonNode legacy = json(run(get("/api/admin/communities").param("status", "PENDING_REVIEW").param("size", "50")), 200);
        assertTrue(legacy.has("nextCursor") && legacy.has("items"));
        assertTrue(gone.getId() > 0);
    }

    // ---- ayrinti ----

    @Test
    void detailShowsStaffCapabilitiesAndNotFound() throws Exception {
        User owner = user("Detay Sahip");
        Community c = club("Detay " + tag(), owner, Community.Status.ACTIVE);
        User mod = user("Detay Mod");
        join(c, mod, Role.MODERATOR, CommunityMember.Status.ACTIVE);
        join(c, user("Detay Banli"), Role.MEMBER, CommunityMember.Status.BANNED);

        MvcResult res = run(get("/api/admin/communities/" + c.getId()));
        JsonNode d = json(res, 200);
        assertEquals(c.getId(), d.get("club").get("id").asLong());
        assertEquals(2, d.get("staff").size());
        assertEquals("OWNER", d.get("staff").get(0).get("role").asText());
        assertEquals(1, d.get("bannedCount").asLong());
        assertTrue(d.get("capabilities").get("canClose").asBoolean());
        assertFalse(d.get("capabilities").get("canReopen").asBoolean());
        assertTrue(d.get("statusHistory").isArray() && d.get("openReports").isArray());

        assertEquals("COMMUNITY_NOT_FOUND", code(run(get("/api/admin/communities/987654321"))));
    }

    // ---- duzenleme ----

    @Test
    void patchEditsFieldsAuditsTargetAndRejectsEmptyAndInvalid() throws Exception {
        User owner = user("Duzen Sahip");
        Community c = club("Duzen " + tag(), owner, Community.Status.ACTIVE);
        String newName = "Yeni Ad " + tag();

        MvcResult res = run(patch("/api/admin/communities/" + c.getId()).contentType("application/json")
                .content("{\"name\":\"" + newName + "\",\"description\":\"Aciklama\",\"joinPolicy\":\"APPROVAL\",\"visibility\":\"PRIVATE\"}"));
        JsonNode d = json(res, 200);
        assertEquals(newName, d.get("club").get("name").asText());
        assertEquals("APPROVAL", d.get("club").get("joinPolicy").asText());
        assertEquals("PRIVATE", d.get("club").get("visibility").asText());
        assertEquals("Aciklama", d.get("description").asText());
        assertEquals("COMMUNITY", audit(res).targetType());
        assertEquals(String.valueOf(c.getId()), audit(res).targetId());
        assertTrue(audit(res).summary().contains("name"));

        assertEquals("VALIDATION_ERROR", code(run(patch("/api/admin/communities/" + c.getId()).contentType("application/json").content("{}"))));
        assertEquals(400, run(patch("/api/admin/communities/" + c.getId()).contentType("application/json")
                .content("{\"name\":\"ab\"}")).getResponse().getStatus());
        assertEquals(404, run(patch("/api/admin/communities/987654321").contentType("application/json")
                .content("{\"name\":\"Yok kulup\"}")).getResponse().getStatus());
    }

    // ---- kapat / yeniden ac ----

    @Test
    void closeThenReopenChangesStatusNotifiesAndGuardsStates() throws Exception {
        User owner = user("Kapat Sahip");
        Community c = club("Kapat " + tag(), owner, Community.Status.ACTIVE);
        join(c, user("Kapat Uye"), Role.MEMBER, CommunityMember.Status.ACTIVE);
        String base = "/api/admin/communities/" + c.getId();

        assertEquals("CLUB_ADMIN_STATE_INVALID", code(run(post(base + "/reopen").contentType("application/json").content("{}"))));

        MvcResult closed = run(post(base + "/close").contentType("application/json").content("{\"reason\":\"kurallara aykiri\"}"));
        JsonNode r = json(closed, 200);
        assertEquals("HIDDEN", r.get("status").asText());
        assertFalse(r.get("irreversible").asBoolean());
        assertEquals(2, r.get("notified").asInt());
        assertEquals("COMMUNITY", audit(closed).targetType());
        assertEquals("kurallara aykiri", communities.findById(c.getId()).orElseThrow().getReviewNote());
        assertEquals(Community.Status.HIDDEN, communities.findById(c.getId()).orElseThrow().getStatus());

        assertEquals(409, run(post(base + "/close").contentType("application/json").content("{}")).getResponse().getStatus());
        JsonNode d = json(run(get(base)), 200);
        assertTrue(d.get("capabilities").get("canReopen").asBoolean());
        assertFalse(d.get("capabilities").get("canClose").asBoolean());
        assertEquals("ADMIN_CLUB_CLOSED", d.get("statusHistory").get(0).get("action").asText());

        JsonNode reopened = json(run(post(base + "/reopen").contentType("application/json").content("{\"reason\":\"duzeltildi\"}")), 200);
        assertEquals("ACTIVE", reopened.get("status").asText());
        Community after = communities.findById(c.getId()).orElseThrow();
        assertEquals(Community.Status.ACTIVE, after.getStatus());
        assertEquals(null, after.getReviewNote());
    }

    // ---- silme ----

    @Test
    void deleteIsSoftIrreversibleAndSecondDeleteIs404() throws Exception {
        User owner = user("Sil Sahip");
        Community c = club("Sil " + tag(), owner, Community.Status.ACTIVE);
        join(c, user("Sil Uye"), Role.MEMBER, CommunityMember.Status.ACTIVE);

        MvcResult res = run(delete("/api/admin/communities/" + c.getId()).contentType("application/json")
                .content("{\"reason\":\"yinelenen ihlal\"}"));
        JsonNode r = json(res, 200);
        assertEquals("DELETED", r.get("status").asText());
        assertTrue(r.get("irreversible").asBoolean());
        assertEquals("COMMUNITY", audit(res).targetType());
        assertEquals(Community.Status.DELETED, communities.findById(c.getId()).orElseThrow().getStatus());

        assertEquals(404, run(delete("/api/admin/communities/" + c.getId())).getResponse().getStatus());
        // yonetici silinmis kulubu de gorur (denetim/inceleme); eylem yetenekleri kapali
        JsonNode view = json(run(get("/api/admin/communities/" + c.getId())), 200);
        assertEquals("DELETED", view.get("club").get("status").asText());
        assertFalse(view.get("capabilities").get("canEdit").asBoolean());
        assertFalse(view.get("capabilities").get("canDelete").asBoolean());
        assertEquals(404, run(post("/api/admin/communities/" + c.getId() + "/close").contentType("application/json").content("{}"))
                .getResponse().getStatus());
    }

    // ---- uyeler / rol ----

    @Test
    void membersListFiltersAndRemoveRoleRulesAreEnforced() throws Exception {
        User owner = user("Uye Sahip");
        Community c = club("Uyeler " + tag(), owner, Community.Status.ACTIVE);
        User a = user("Aday Bir");
        User b = user("Aday Iki");
        join(c, a, Role.MEMBER, CommunityMember.Status.ACTIVE);
        join(c, b, Role.MEMBER, CommunityMember.Status.PENDING);
        String base = "/api/admin/communities/" + c.getId();

        JsonNode all = json(run(get(base + "/members")), 200);
        assertEquals(3, all.get("total").asLong());
        assertEquals("OWNER", all.get("items").get(0).get("role").asText(), "sahip basta");
        assertEquals(1, json(run(get(base + "/members").param("status", "PENDING")), 200).get("total").asLong());
        assertEquals(1, json(run(get(base + "/members").param("role", "OWNER")), 200).get("total").asLong());
        assertEquals(1, json(run(get(base + "/members").param("q", "Aday Bir")), 200).get("total").asLong());
        assertEquals(400, run(get(base + "/members").param("role", "KING")).getResponse().getStatus());

        // rol: MEMBER -> MODERATOR
        MvcResult roleRes = run(patch(base + "/members/" + a.getId() + "/role").contentType("application/json")
                .content("{\"role\":\"MODERATOR\",\"reason\":\"yeni moderator\"}"));
        assertEquals("MODERATOR", json(roleRes, 200).get("result").asText());
        assertEquals(Role.MODERATOR, members.findByCommunityIdAndUserId(c.getId(), a.getId()).orElseThrow().getRole());
        assertEquals("COMMUNITY", audit(roleRes).targetType());

        // OWNER rolu verilemez; sahibin rolu dusurulemez (son sahip korunur)
        assertEquals("CLUB_ADMIN_USE_TRANSFER", code(run(patch(base + "/members/" + a.getId() + "/role")
                .contentType("application/json").content("{\"role\":\"OWNER\"}"))));
        assertEquals("CLUB_LAST_OWNER", code(run(patch(base + "/members/" + owner.getId() + "/role")
                .contentType("application/json").content("{\"role\":\"MEMBER\"}"))));
        assertEquals(404, run(patch(base + "/members/987654/role").contentType("application/json")
                .content("{\"role\":\"MEMBER\"}")).getResponse().getStatus());

        // sahip cikarilamaz
        MvcResult ownerRm = run(delete(base + "/members/" + owner.getId()));
        assertEquals(403, ownerRm.getResponse().getStatus());
        assertEquals("OWNER_PROTECTED", code(ownerRm));

        // uye cikar / yasakla
        assertEquals("REMOVED", json(run(delete(base + "/members/" + a.getId())), 200).get("result").asText());
        assertTrue(members.findByCommunityIdAndUserId(c.getId(), a.getId()).isEmpty());
        assertEquals("BANNED", json(run(delete(base + "/members/" + b.getId()).param("ban", "true")), 200).get("result").asText());
        assertEquals(CommunityMember.Status.BANNED, members.findByCommunityIdAndUserId(c.getId(), b.getId()).orElseThrow().getStatus());
        assertEquals(404, run(delete(base + "/members/" + a.getId())).getResponse().getStatus());
    }

    // ---- zorla devir ----

    @Test
    void forcedTransferMovesOwnershipAndEnforcesRules() throws Exception {
        User owner = user("Devir Sahip");
        User target = user("Devir Hedef");
        User outsider = user("Devir Disari");
        Community c = club("Devir " + tag(), owner, Community.Status.ACTIVE);
        join(c, target, Role.MEMBER, CommunityMember.Status.ACTIVE);
        String url = "/api/admin/communities/" + c.getId() + "/transfer-ownership";

        // uye olmayan / sahibin kendisi / bekleyen uye gecersiz
        assertEquals("TRANSFER_TARGET_INVALID", code(run(post(url).contentType("application/json")
                .content("{\"targetUserId\":" + outsider.getId() + "}"))));
        assertEquals("TRANSFER_TARGET_INVALID", code(run(post(url).contentType("application/json")
                .content("{\"targetUserId\":" + owner.getId() + "}"))));

        MvcResult res = run(post(url).contentType("application/json").content("{\"targetUserId\":" + target.getId() + ",\"reason\":\"sahip ulasilamiyor\"}"));
        JsonNode r = json(res, 200);
        assertTrue(r.get("irreversible").asBoolean());
        assertEquals("COMMUNITY", audit(res).targetType());
        assertEquals(target.getId(), communities.findById(c.getId()).orElseThrow().getOwnerId());
        assertEquals(Role.OWNER, members.findByCommunityIdAndUserId(c.getId(), target.getId()).orElseThrow().getRole());
        assertEquals(Role.ADMIN, members.findByCommunityIdAndUserId(c.getId(), owner.getId()).orElseThrow().getRole(),
                "keepAsAdmin varsayilan: eski sahip yonetici kalir");

        // geri: eski sahibe, keepAsAdmin=false -> yeni sahip (eski hedef) yonetici kalmaz, uyelikten cikar
        JsonNode back = json(run(post(url).contentType("application/json")
                .content("{\"targetUserId\":" + owner.getId() + ",\"keepAsAdmin\":false}")), 200);
        assertTrue(back.get("irreversible").asBoolean());
        assertTrue(members.findByCommunityIdAndUserId(c.getId(), target.getId()).isEmpty());
        assertEquals(owner.getId(), communities.findById(c.getId()).orElseThrow().getOwnerId());
        long owners = members.findAll().stream().filter(m -> m.getCommunityId().equals(c.getId()) && m.getRole() == Role.OWNER).count();
        assertEquals(1, owners, "kulupte her zaman tek sahip");
    }

    @Test
    void forcedTransferRespectsThreeClubOwnerLimitAndClubState() throws Exception {
        User owner = user("Sinir Sahip");
        User target = user("Sinir Hedef");
        Community c = club("Sinir " + tag(), owner, Community.Status.ACTIVE);
        join(c, target, Role.ADMIN, CommunityMember.Status.ACTIVE);
        for (int i = 0; i < 3; i++) {
            club("Hedefin kulubu " + i + tag(), target, Community.Status.ACTIVE);
        }
        MvcResult res = run(post("/api/admin/communities/" + c.getId() + "/transfer-ownership")
                .contentType("application/json").content("{\"targetUserId\":" + target.getId() + "}"));
        assertEquals(409, res.getResponse().getStatus());
        assertEquals("COMMUNITY_LIMIT", code(res));
        assertEquals(owner.getId(), communities.findById(c.getId()).orElseThrow().getOwnerId(), "reddedilen devir hicbir sey degistirmez");

        Community rejected = club("Reddedilmis " + tag(), owner, Community.Status.REJECTED);
        join(rejected, user("Reddedilmis Uye"), Role.MEMBER, CommunityMember.Status.ACTIVE);
        Long someMember = members.findAll().stream().filter(m -> m.getCommunityId().equals(rejected.getId())
                && m.getRole() == Role.MEMBER).findFirst().orElseThrow().getUserId();
        assertEquals("CLUB_ADMIN_STATE_INVALID", code(run(post("/api/admin/communities/" + rejected.getId() + "/transfer-ownership")
                .contentType("application/json").content("{\"targetUserId\":" + someMember + "}"))));
    }

    // ---- katilim istekleri ----

    @Test
    void joinRequestsCanBeForceApprovedOrRejected() throws Exception {
        User owner = user("Istek Sahip");
        Community c = club("Istek " + tag(), owner, Community.Status.ACTIVE);
        User a = user("Istek Bir");
        User b = user("Istek Iki");
        join(c, a, Role.MEMBER, CommunityMember.Status.PENDING);
        join(c, b, Role.MEMBER, CommunityMember.Status.PENDING);
        String base = "/api/admin/communities/" + c.getId() + "/join-requests";

        assertEquals(2, json(run(get(base)), 200).get("total").asLong());
        assertEquals("APPROVED", json(run(post(base + "/" + a.getId() + "/approve")), 200).get("result").asText());
        assertEquals(CommunityMember.Status.ACTIVE, members.findByCommunityIdAndUserId(c.getId(), a.getId()).orElseThrow().getStatus());
        assertEquals("REJECTED", json(run(post(base + "/" + b.getId() + "/reject")), 200).get("result").asText());
        assertTrue(members.findByCommunityIdAndUserId(c.getId(), b.getId()).isEmpty());
        assertEquals(404, run(post(base + "/" + a.getId() + "/approve")).getResponse().getStatus(), "artik bekleyen degil");
        assertEquals(0, json(run(get(base)), 200).get("total").asLong());
    }

    // ---- CSV ----

    @Test
    void csvExportEscapesFormulasHasBomAndIsAudited() throws Exception {
        String m = "Csv" + tag();
        User owner = user("Csv Sahip");
        club("=HYPERLINK(\"http://x\")" + m, owner, Community.Status.ACTIVE);
        club("+cmd " + m, owner, Community.Status.ACTIVE);

        MvcResult res = run(get("/api/admin/communities/export.csv").param("q", m));
        MockHttpServletResponse r = res.getResponse();
        assertEquals(200, r.getStatus());
        assertTrue(r.getContentType().startsWith("text/csv"));
        String csv = r.getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertTrue(csv.startsWith("﻿id,ad,slug"));
        assertTrue(csv.contains("\"'=HYPERLINK("), "formul onekli hucre kacirilir: " + csv);
        assertTrue(csv.contains("'+cmd"), csv);
        assertFalse(csv.contains(",=HYPERLINK"));
        assertEquals(3, csv.split("\r\n").length, "baslik + 2 satir");
        assertEquals("COMMUNITY", audit(res).targetType());
        assertEquals("csv satir=2", audit(res).summary());
    }

    // ---- kulup denetimi / davetler ----

    @Test
    void clubAuditAndInvitesAreReadableByAdmin() throws Exception {
        User owner = user("Dnt Sahip");
        Community c = club("Denetim " + tag(), owner, Community.Status.ACTIVE);
        String base = "/api/admin/communities/" + c.getId();
        run(post(base + "/close").contentType("application/json").content("{\"reason\":\"deneme kapatma\"}"));

        JsonNode audit = json(run(get(base + "/club-audit")), 200);
        assertTrue(audit.has("items"));
        assertEquals("ADMIN_CLUB_CLOSED", audit.get("items").get(0).get("action").asText());
        assertEquals(0, json(run(get(base + "/invites")), 200).size());
        assertEquals(404, run(delete(base + "/invites/12345")).getResponse().getStatus());
    }

    // ---- gonderi / duyuru moderasyonu ----

    @Test
    void contentListFiltersByKindStatusReportsAndSorts() throws Exception {
        String m = "Icerik" + tag();
        User owner = user("Ic Sahip");
        User author = user("Ic Yazar");
        Community c = club("Icerik " + tag(), owner, Community.Status.ACTIVE);
        CommunityPost p1 = newPost(c, author, m + " normal gonderi", false);
        CommunityPost p2 = newPost(c, author, m + " duyuru", true);
        CommunityPost p3 = newPost(c, author, m + " silinmis", false);
        p3.setDeleted(true);
        posts.save(p3);
        Report rep = new Report();
        rep.setReporterId(owner.getId());
        rep.setTargetType(ReportTargetType.POST);
        rep.setTargetId(p1.getId());
        rep.setReason(ReportReason.SPAM);
        reports.save(rep);

        JsonNode all = json(run(get("/api/admin/community-posts").param("q", m)), 200);
        assertEquals(3, all.get("total").asLong());
        for (String f : List.of("id", "communityId", "communityName", "kind", "state", "author", "text", "openReportCount", "createdAt")) {
            assertTrue(all.get("items").get(0).has(f), "PostRow." + f);
        }
        assertEquals(1, json(run(get("/api/admin/community-posts").param("q", m).param("kind", "ANNOUNCEMENT")), 200).get("total").asLong());
        assertEquals(1, json(run(get("/api/admin/community-posts").param("q", m).param("status", "DELETED")), 200).get("total").asLong());
        assertEquals(2, json(run(get("/api/admin/community-posts").param("q", m).param("status", "VISIBLE")), 200).get("total").asLong());
        JsonNode reported = json(run(get("/api/admin/community-posts").param("q", m).param("minReports", "1")), 200);
        assertEquals(1, reported.get("total").asLong());
        assertEquals(p1.getId(), reported.get("items").get(0).get("id").asLong());
        assertEquals(1, reported.get("items").get(0).get("openReportCount").asInt());
        JsonNode bySort = json(run(get("/api/admin/community-posts").param("q", m).param("sort", "reports")), 200);
        assertEquals(p1.getId(), bySort.get("items").get(0).get("id").asLong(), "raporlu once");
        assertEquals(0, json(run(get("/api/admin/community-posts").param("communityId", String.valueOf(c.getId()))
                .param("q", m).param("authorId", String.valueOf(author.getId())).param("status", "HIDDEN")), 200).get("total").asLong());
        assertEquals(3, json(run(get("/api/admin/community-posts").param("communityId", String.valueOf(c.getId()))
                .param("authorId", String.valueOf(author.getId())).param("from", "2020-01-01").param("to", "2099-12-31")), 200).get("total").asLong());
        assertEquals(400, run(get("/api/admin/community-posts").param("kind", "X")).getResponse().getStatus());
        assertEquals(400, run(get("/api/admin/community-posts").param("from", "bugun")).getResponse().getStatus());
        assertEquals(400, run(get("/api/admin/community-posts").param("sort", "id; drop")).getResponse().getStatus());
        assertEquals(p2.getId().longValue(), json(run(get("/api/admin/community-posts/" + p2.getId())), 200).get("post").get("id").asLong());
        JsonNode detail = json(run(get("/api/admin/community-posts/" + p1.getId())), 200);
        assertEquals(1, detail.get("reports").size());
    }

    @Test
    void hideUnhideEditAndDeleteWorkAndAreAuditedByPostTarget() throws Exception {
        User owner = user("Mod Sahip");
        User author = user("Mod Yazar");
        Community c = club("Moderasyon " + tag(), owner, Community.Status.ACTIVE);
        CommunityPost p = newPost(c, author, "Duzenlenecek metin", false);
        CommunityPost ann = newPost(c, author, "Gizlenecek duyuru", true);
        String base = "/api/admin/community-posts/";

        // duzenle
        MvcResult edit = run(patch(base + p.getId()).contentType("application/json").content("{\"text\":\"  Temiz metin  \"}"));
        assertEquals("Temiz metin", json(edit, 200).get("text").asText());
        assertEquals("COMMUNITY_POST", audit(edit).targetType());
        assertEquals(String.valueOf(p.getId()), audit(edit).targetId());
        assertTrue(posts.findById(p.getId()).orElseThrow().getEditedAt() != null);
        assertEquals(400, run(patch(base + p.getId()).contentType("application/json").content("{\"text\":\"   \"}")).getResponse().getStatus());

        // gizle -> akistan ve duyurulardan dusur; geri al -> yeniden gorunur
        posts.findById(p.getId()).ifPresent(x -> { x.setPinned(true); posts.save(x); });
        MvcResult hide = run(post(base + p.getId() + "/hide").contentType("application/json").content("{\"reason\":\"spam suphesi\"}"));
        JsonNode hidden = json(hide, 200);
        assertEquals("HIDDEN", hidden.get("state").asText());
        assertEquals("spam suphesi", hidden.get("hiddenReason").asText());
        assertEquals("COMMUNITY_POST", audit(hide).targetType());
        assertFalse(posts.pinned(c.getId(), Set.of(-1L)).stream().anyMatch(x -> x.getId().equals(p.getId())), "gizli yazi sabitlilerde de yok");
        assertFalse(feedIds(c).contains(p.getId()));
        assertEquals("HIDDEN", json(run(post(base + p.getId() + "/hide").contentType("application/json").content("{}")), 200).get("state").asText(), "idempotent");
        assertEquals("VISIBLE", json(run(post(base + p.getId() + "/unhide").contentType("application/json").content("{}")), 200).get("state").asText());
        assertTrue(feedIds(c).contains(p.getId()));

        json(run(post(base + ann.getId() + "/hide").contentType("application/json").content("{}")), 200);
        assertTrue(posts.findById(ann.getId()).orElseThrow().isHidden());

        // sil: yumusak, ikinci kez 404, duzenleme/gizleme de 404
        MvcResult del = run(delete(base + p.getId()).contentType("application/json").content("{\"reason\":\"ihlal\"}"));
        JsonNode dj = json(del, 200);
        assertEquals("DELETED", dj.get("state").asText());
        assertTrue(dj.get("irreversible").asBoolean());
        assertEquals("COMMUNITY_POST", audit(del).targetType());
        assertTrue(posts.findById(p.getId()).orElseThrow().isDeleted());
        assertEquals(404, run(delete(base + p.getId())).getResponse().getStatus());
        assertEquals(404, run(post(base + p.getId() + "/hide").contentType("application/json").content("{}")).getResponse().getStatus());
        assertEquals(404, run(patch(base + p.getId()).contentType("application/json").content("{\"text\":\"x\"}")).getResponse().getStatus());
        // silinmis gonderi detayda "DELETED" gorunur (yonetici icin kisit yok)
        assertEquals("DELETED", json(run(get(base + p.getId())), 200).get("post").get("state").asText());
    }

    @Test
    void deletingAReportedPostResolvesItsOpenReports() throws Exception {
        User owner = user("Rapor Sahip");
        User author = user("Rapor Yazar");
        Community c = club("Rapor " + tag(), owner, Community.Status.ACTIVE);
        CommunityPost p = newPost(c, author, "Raporlu yazi", false);
        Report rep = new Report();
        rep.setReporterId(owner.getId());
        rep.setTargetType(ReportTargetType.POST);
        rep.setTargetId(p.getId());
        rep.setReason(ReportReason.HARASSMENT);
        reports.save(rep);

        json(run(delete("/api/admin/community-posts/" + p.getId()).contentType("application/json").content("{\"reason\":\"taciz\"}")), 200);
        // acik rapor ReportService.resolve(HIDE) ile sonuclandirilir (gercek kapanis PostgreSQL smoke'unda); yazi silinmis olur
        verify(reportService).resolve(eq(rep.getId()), eq(ADMIN_ID), eq(Report.Resolution.HIDE), eq("taciz"), isNull());
        assertTrue(posts.findById(p.getId()).orElseThrow().isDeleted());
    }

    private List<Long> feedIds(Community c) {
        return posts.feed(c.getId(), Long.MAX_VALUE, Set.of(-1L), PageRequest.of(0, 50)).stream().map(CommunityPost::getId).toList();
    }
}
