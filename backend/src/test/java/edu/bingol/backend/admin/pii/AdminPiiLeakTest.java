package edu.bingol.backend.admin.pii;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;

import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.support.feedback.Feedback;
import edu.bingol.backend.support.feedback.FeedbackRepository;
import edu.bingol.backend.support.ticket.SupportMessage;
import edu.bingol.backend.support.ticket.SupportMessageRepository;
import edu.bingol.backend.support.ticket.SupportTicket;
import edu.bingol.backend.support.ticket.TicketRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

/**
 * T-018 GENEL SIZINTI TESTI: `users.pii` izni olmayan profiller (SUPPORT, EDITOR, VIEWER) kayitli HER
 * `GET /api/admin/**` ucunu (yol sablonu degiskenleri 1 ile doldurulur; CSV dahil) gezerken hicbir yanitta MASKESIZ
 * e-posta bulunmamali. Tohum veri: destek talebi (hesapli + herkese acik), geri bildirim, kulup sahibi/uyesi.
 * FULL profil ayni uclarda tam adresi gorur (maskenin islevi bozmadigi dogrulanir).
 */
@SpringBootTest
class AdminPiiLeakTest {

    /** Maskeli bicim ("a***@alan") eslesmez: yerel kisim yalniz harf/rakam/._%+- ; '*' icermez. */
    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(?:\\.[A-Za-z0-9\\-]+)+");

    @Autowired WebApplicationContext ctx;
    @Autowired @Qualifier("requestMappingHandlerMapping") RequestMappingHandlerMapping mapping;
    @Autowired UserRepository users;
    @Autowired TicketRepository tickets;
    @Autowired SupportMessageRepository messages;
    @Autowired FeedbackRepository feedback;
    @Autowired CommunityRepository communities;
    @Autowired CommunityMemberRepository members;
    @MockitoBean RateLimiter limiter;
    @MockitoBean StringRedisTemplate redis;
    @MockitoBean RoomConversations rooms;
    MockMvc mvc;

    String victimEmail;
    String publicEmail;
    String ownerEmail;
    Long ticketId;
    Long victimId;
    Long communityId;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = org.mockito.Mockito.mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();

        String tag = UUID.randomUUID().toString().substring(0, 8);
        User victim = user("victim.leak." + tag + "@bingol.edu.tr", "Magdur Kisi", edu.bingol.backend.user.Role.USER, null);
        victimEmail = victim.getEmail();
        victimId = victim.getId();
        User owner = user("owner.leak." + tag + "@bingol.edu.tr", "Kulup Sahibi", edu.bingol.backend.user.Role.USER, null);
        ownerEmail = owner.getEmail();

        SupportTicket t = new SupportTicket();
        t.setUserId(victim.getId());
        t.setCategory(SupportTicket.Category.TECHNICAL);
        t.setSubject("Sizinti testi " + tag);
        t = tickets.save(t);
        ticketId = t.getId();
        SupportMessage m = new SupportMessage();
        m.setTicketId(t.getId());
        m.setAuthorId(victim.getId());
        m.setText("Bana " + victimEmail + " adresinden ulasin");
        messages.save(m);

        publicEmail = "misafir.leak." + tag + "@example.com";
        SupportTicket pt = new SupportTicket();
        pt.setPublicTicket(true);
        pt.setEmailVerified(true);
        pt.setContactEmail(publicEmail);
        pt.setContactName("Misafir");
        pt.setCategory(SupportTicket.Category.OTHER);
        pt.setSubject("Herkese acik " + tag);
        tickets.save(pt);

        Feedback f = new Feedback();
        f.setUserId(victim.getId());
        f.setCategory(Feedback.Category.SUGGESTION);
        f.setSubject("Oneri " + tag);
        f.setMessage("mesaj");
        feedback.save(f);

        Community c = new Community();
        c.setName("Sizinti Kulubu " + tag);
        c.setSlug("leak-" + tag);
        c.setOwnerId(owner.getId());
        c.setStatus(Community.Status.ACTIVE);
        c.setCategory("Spor");
        communities.save(c);
        communityId = c.getId();
        members.save(new CommunityMember(c.getId(), owner.getId(), Role.OWNER, CommunityMember.Status.ACTIVE));
        members.save(new CommunityMember(c.getId(), victim.getId(), Role.MEMBER, CommunityMember.Status.ACTIVE));
    }

    private User user(String email, String name, edu.bingol.backend.user.Role role, AdminProfile profile) {
        User u = new User();
        u.setEmail(email);
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        u.setRole(role);
        u.setStatus(UserStatus.ACTIVE);
        u.setAdminProfile(profile);
        return users.save(u);
    }

    private MockHttpServletResponse fetch(User admin, String path) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(admin.getId(), null,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        return mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get(path).with(authentication(token))).andReturn().getResponse();
    }

    private User admin(AdminProfile p) {
        return user("adm." + p.name().toLowerCase() + "." + UUID.randomUUID().toString().substring(0, 8)
                + "@bingol.edu.tr", "Yonetici " + p, edu.bingol.backend.user.Role.ADMIN, p);
    }

    /** Kayitli tum GET /api/admin yol sablonlari (degiskenler 1). */
    private Set<String> adminGetPaths() {
        Set<String> out = new TreeSet<>();
        for (RequestMappingInfo info : mapping.getHandlerMethods().keySet()) {
            if (info.getPathPatternsCondition() == null) {
                continue;
            }
            var methods = info.getMethodsCondition().getMethods();
            if (!methods.isEmpty() && !methods.contains(RequestMethod.GET)) {
                continue;
            }
            for (String pattern : info.getPathPatternsCondition().getPatternValues()) {
                if (pattern.startsWith("/api/admin") && !pattern.contains("*")) {
                    out.add(pattern.replaceAll("\\{[^}]*}", "1"));
                }
            }
        }
        return out;
    }

    @Test
    void maskedProfilesNeverSeeUnmaskedEmailsOnAnyAdminGetEndpoint() throws Exception {
        Set<String> paths = adminGetPaths();
        assertThat(paths).as("tarama calisiyor mu").hasSizeGreaterThan(80);
        // yoklanan uclar tohum veriyle dolu olsun
        paths.add("/api/admin/support/tickets/" + ticketId);
        paths.add("/api/admin/communities/" + communityId);
        paths.add("/api/admin/communities/" + communityId + "/members");

        List<String> leaks = new ArrayList<>();
        int answered = 0;
        for (AdminProfile p : List.of(AdminProfile.SUPPORT, AdminProfile.EDITOR, AdminProfile.VIEWER)) {
            User admin = admin(p);
            for (String path : paths) {
                MockHttpServletResponse r;
                try {
                    r = fetch(admin, path);
                } catch (Exception e) {
                    continue; // H2'de calismayan PostgreSQL'e ozel uclar: sizinti yok
                }
                if (r.getStatus() == 200) {
                    answered++;
                }
                String body = r.getContentAsString(StandardCharsets.UTF_8);
                Matcher m = EMAIL.matcher(body);
                while (m.find()) {
                    leaks.add(p + " " + path + " -> " + m.group());
                }
            }
        }
        assertThat(answered).as("en az bir kac uc 200 donmeli (test bos gecmesin)").isGreaterThan(30);
        assertThat(leaks).as("users.pii olmayan profile maskesiz e-posta").isEmpty();
    }

    @Test
    void supportSeesMaskedAddressesOnTicketAndClubEndpointsWhileFullSeesThem() throws Exception {
        User support = admin(AdminProfile.SUPPORT);
        User full = admin(AdminProfile.FULL);

        for (String path : List.of("/api/admin/support/tickets", "/api/admin/support/tickets/" + ticketId,
                "/api/admin/support/tickets/export.csv", "/api/admin/communities/" + communityId,
                "/api/admin/communities/" + communityId + "/members")) {
            MockHttpServletResponse s = fetch(support, path);
            assertThat(s.getStatus()).as(path).isEqualTo(200);
            String sb = s.getContentAsString(StandardCharsets.UTF_8);
            assertThat(sb).as(path).doesNotContain(victimEmail).doesNotContain(publicEmail).doesNotContain(ownerEmail);

            MockHttpServletResponse f = fetch(full, path);
            assertThat(f.getStatus()).as(path).isEqualTo(200);
            String fb = f.getContentAsString(StandardCharsets.UTF_8);
            assertThat(fb).as("FULL tam adresi gorur: " + path)
                    .containsAnyOf(victimEmail, publicEmail, ownerEmail);
        }
        // maskeli bicim biciminde gelir (ilk harf + ***)
        String list = fetch(support, "/api/admin/support/tickets").getContentAsString(StandardCharsets.UTF_8);
        assertThat(list).contains(victimEmail.charAt(0) + "***@bingol.edu.tr");
    }

    @Test
    void audiencePreviewSamplesAreMaskedForNonPiiProfiles() throws Exception {
        String body = "{\"audience\":{\"type\":\"USERS\",\"value\":\"" + victimId + "\"},\"type\":\"ANNOUNCEMENT\"}";
        for (AdminProfile p : List.of(AdminProfile.SUPPORT, AdminProfile.EDITOR, AdminProfile.VIEWER)) {
            String out = post(admin(p), "/api/admin/push/audience/preview", body);
            assertThat(out).as(p + " kitle onizleme").contains("\"sample\"").doesNotContain(victimEmail);
            assertThat(out).contains(victimEmail.charAt(0) + "***@bingol.edu.tr");
        }
        assertThat(post(admin(AdminProfile.FULL), "/api/admin/push/audience/preview", body)).contains(victimEmail);
    }

    private String post(User admin, String path, String json) throws Exception {
        var token = new UsernamePasswordAuthenticationToken(admin.getId(), null,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
        MockHttpServletResponse r = mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .post(path).contentType("application/json").content(json).with(authentication(token)))
                .andReturn().getResponse();
        assertThat(r.getStatus()).as(r.getContentAsString()).isEqualTo(200);
        return r.getContentAsString(StandardCharsets.UTF_8);
    }
}
