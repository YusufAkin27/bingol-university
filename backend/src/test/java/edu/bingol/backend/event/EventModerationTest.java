package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.event.admission.EventAdmission;
import edu.bingol.backend.event.admission.EventAdmissionRepository;
import edu.bingol.backend.event.admission.EventApplication;
import edu.bingol.backend.event.admission.EventApplicationRepository;
import edu.bingol.backend.event.chat.EventChatService;
import edu.bingol.backend.event.dto.EventAdminDtos.AdminEventDetail;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.search.SearchProvider;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Yonetici etkinlik moderasyonu: gecisler, gorunurluk, iptal yan etkileri, suzme/arama, pendingCount, imec (H2, gercek bean'ler). */
@SpringBootTest
class EventModerationTest {

    @Autowired EventModerationService moderation;
    @Autowired EventService service;
    @Autowired UserEventRepository events;
    @Autowired EventModerationLogRepository logs;
    @Autowired EventRsvpRepository rsvps;
    @Autowired UserRepository users;
    @Autowired CommunityRepository communities;
    @Autowired edu.bingol.backend.community.permissions.ClubMemberGrantRepository grants;
    @Autowired EventAdmissionRepository admissions;
    @Autowired EventApplicationRepository applications;
    @Autowired List<ReportTargetHandler> handlers;
    @Autowired List<SearchProvider> searchProviders;

    @MockitoBean NotificationService notifications;
    @MockitoBean RoomConversations rooms;
    @MockitoBean EventChatService chat;

    private final Instant soon = Instant.now().plus(Duration.ofDays(3));

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

    private UserEvent event(String title, User owner, UserEvent.Status st) {
        UserEvent e = new UserEvent();
        e.setTitle(title);
        e.setStartsAt(soon);
        e.setEndsAt(soon.plus(Duration.ofHours(2)));
        e.setCreatedBy(owner.getId());
        e.setStatus(st);
        return events.saveAndFlush(e);
    }

    private static String token() {
        return "zq" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
    }

    private static ApiException fail(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    // ---- gecisler ----

    @Test
    void hideMakesEventInvisibleEverywhereWithoutNotifyingAndUnhideRestores() {
        User owner = user("Sahip");
        User viewer = user("Izleyici");
        String t = token();
        UserEvent e = event(t + " konser", owner, UserEvent.Status.ACTIVE);
        Actor v = new Actor(viewer.getId(), false);
        Actor o = new Actor(owner.getId(), false);
        assertTrue(service.list(v, null, null, null, null, 50).items().stream().anyMatch(x -> x.id().equals(e.getId())));
        assertEquals(1, searchProviders.stream().filter(p -> p.type().name().equals("EVENT")).findFirst().orElseThrow()
                .search(t, 10).size());

        AdminEventDetail d = moderation.hide(77L, e.getId(), "  Uygunsuz içerik ");
        assertEquals(UserEvent.Status.HIDDEN, d.event().status());
        assertEquals("Uygunsuz içerik", d.moderationReason());
        assertEquals(List.of("unhide", "cancel", "delete"), d.allowedActions());
        assertEquals("HIDE", d.history().get(0).action());
        assertEquals(UserEvent.Status.ACTIVE, d.history().get(0).fromStatus());
        assertEquals(77L, d.history().get(0).adminId());

        assertFalse(service.list(v, null, null, null, null, 50).items().stream().anyMatch(x -> x.id().equals(e.getId())));
        assertTrue(searchProviders.stream().filter(p -> p.type().name().equals("EVENT")).findFirst().orElseThrow()
                .search(t, 10).isEmpty());
        assertEquals("EVENT_NOT_FOUND", fail(() -> service.get(v, e.getId())).code());
        assertEquals("EVENT_NOT_FOUND", fail(() -> service.get(o, e.getId())).code()); // sahibine de 404
        assertEquals("EVENT_NOT_FOUND", fail(() -> service.delete(o, e.getId())).code());
        assertEquals("EVENT_NOT_FOUND", fail(() -> service.rsvp(v, e.getId(), EventRsvp.Status.GOING)).code());
        assertTrue(service.mine(o, "created", null, 50).items().stream().noneMatch(x -> x.id().equals(e.getId())));
        // yonetici gorur
        assertEquals(e.getId(), service.get(new Actor(1L, true), e.getId()).id());
        verify(notifications, never()).sendTemplated(org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.anyString(), anyMap(), org.mockito.ArgumentMatchers.<String>any());

        AdminEventDetail back = moderation.unhide(77L, e.getId(), "Yanlış alarm");
        assertEquals(UserEvent.Status.ACTIVE, back.event().status());
        assertEquals(2, back.history().size());
        assertEquals("UNHIDE", back.history().get(0).action());
        assertEquals(e.getId(), service.get(v, e.getId()).id());
    }

    @Test
    void invalidTransitionsAndMissingReasonAreRejected() {
        User owner = user("S");
        UserEvent active = event(token(), owner, UserEvent.Status.ACTIVE);
        UserEvent cancelled = event(token(), owner, UserEvent.Status.CANCELLED);
        UserEvent rejected = event(token(), owner, UserEvent.Status.REJECTED);
        UserEvent pending = event(token(), owner, UserEvent.Status.PENDING_REVIEW);

        assertEquals("EVENT_INVALID_TRANSITION", fail(() -> moderation.unhide(1L, active.getId(), "x")).code());
        assertEquals("EVENT_INVALID_TRANSITION", fail(() -> moderation.hide(1L, cancelled.getId(), "x")).code());
        assertEquals("EVENT_INVALID_TRANSITION", fail(() -> moderation.hide(1L, pending.getId(), "x")).code());
        assertEquals("EVENT_INVALID_TRANSITION", fail(() -> moderation.cancel(1L, cancelled.getId(), "x")).code());
        assertEquals("EVENT_INVALID_TRANSITION", fail(() -> moderation.cancel(1L, rejected.getId(), "x")).code());
        assertEquals(409, fail(() -> moderation.cancel(1L, rejected.getId(), "x")).status().value());
        assertEquals("VALIDATION_ERROR", fail(() -> moderation.hide(1L, active.getId(), "   ")).code());
        assertEquals("VALIDATION_ERROR", fail(() -> moderation.cancel(1L, active.getId(), null)).code());
        assertEquals(UserEvent.Status.ACTIVE, events.findById(active.getId()).orElseThrow().getStatus());
        assertEquals("EVENT_NOT_FOUND", fail(() -> moderation.detail(987654321L)).code());
        assertEquals(List.of("approve", "reject", "edit", "cancel", "delete"), moderation.detail(pending.getId()).allowedActions());
        assertEquals(List.of(), moderation.detail(cancelled.getId()).allowedActions());
    }

    @Test
    void cancelNotifiesParticipantsApplicantsAndOwnerClosesRoomAndStopsReminders() {
        User owner = user("Sahip");
        User going = user("Katilimci");
        User applicant = user("Basvuran");
        UserEvent e = event(token() + " calistay", owner, UserEvent.Status.ACTIVE);
        rsvps.saveAndFlush(new EventRsvp(e.getId(), going.getId(), EventRsvp.Status.GOING));
        EventAdmission cfg = new EventAdmission(e.getId());
        cfg.setMode(EventAdmission.Mode.APPROVAL);
        admissions.saveAndFlush(cfg);
        applications.saveAndFlush(new EventApplication(e.getId(), applicant.getId()));

        AdminEventDetail d = moderation.cancel(5L, e.getId(), "Sahte etkinlik");

        assertEquals(UserEvent.Status.CANCELLED, d.event().status());
        assertEquals("Sahte etkinlik", d.moderationReason());
        assertEquals("CANCEL", d.history().get(0).action());
        assertEquals(List.of(), d.allowedActions());
        verify(notifications).sendTemplated(eq(going.getId()), eq(NotificationType.EVENT), eq("notif.event.cancelled"),
                anyMap(), eq(e.getTitle()));
        verify(notifications).sendTemplated(eq(applicant.getId()), eq(NotificationType.EVENT), eq("notif.event.cancelled"),
                anyMap(), eq(e.getTitle()));
        verify(notifications).sendTemplated(eq(owner.getId()), eq(NotificationType.EVENT), eq("notif.event.cancelledByAdmin"),
                anyMap(), eq(e.getTitle()), eq("Sahte etkinlik"));
        verify(rooms).closeRoomIsolated(RoomKind.EVENT, e.getId());
        verify(chat).onCancelled(e.getId());
        // ACTIVE disi: hatirlatma sorgulari (ACTIVE filtreli) artik secmez
        assertEquals(UserEvent.Status.CANCELLED, events.findById(e.getId()).orElseThrow().getStatus());
        assertEquals(0, applications.countByEventIdAndStatus(e.getId(), EventApplication.Status.PENDING));
    }

    @Test
    void cancelFromHiddenNotifiesParticipantsAndFromPendingDoesNot() {
        User owner = user("Sahip");
        User going = user("Katilimci");
        UserEvent hidden = event(token(), owner, UserEvent.Status.HIDDEN);
        rsvps.saveAndFlush(new EventRsvp(hidden.getId(), going.getId(), EventRsvp.Status.GOING));
        moderation.cancel(5L, hidden.getId(), "Kural ihlali");
        verify(notifications).sendTemplated(eq(going.getId()), eq(NotificationType.EVENT), eq("notif.event.cancelled"),
                anyMap(), eq(hidden.getTitle()));
        assertEquals(HIDDEN_TO_CANCELLED, logs.recent(hidden.getId(), org.springframework.data.domain.PageRequest.of(0, 5))
                .get(0).getFromStatus() + ">" + logs.recent(hidden.getId(), org.springframework.data.domain.PageRequest.of(0, 5))
                .get(0).getToStatus());

        reset(notifications);
        UserEvent pending = event(token(), owner, UserEvent.Status.PENDING_REVIEW);
        moderation.cancel(5L, pending.getId(), "Uygunsuz");
        verify(notifications, never()).sendTemplated(eq(going.getId()), eq(NotificationType.EVENT), eq("notif.event.cancelled"),
                anyMap(), eq(pending.getTitle()));
        verify(notifications).sendTemplated(eq(owner.getId()), eq(NotificationType.EVENT), eq("notif.event.cancelledByAdmin"),
                anyMap(), eq(pending.getTitle()), eq("Uygunsuz"));
    }

    private static final String HIDDEN_TO_CANCELLED = "HIDDEN>CANCELLED";

    @Test
    void reportHandlerHidesActiveOnlyAndIsReversible() {
        ReportTargetHandler h = handlers.stream().filter(x -> x.type() == ReportTargetType.EVENT).findFirst().orElseThrow();
        User owner = user("S");
        UserEvent active = event(token(), owner, UserEvent.Status.ACTIVE);
        UserEvent pending = event(token(), owner, UserEvent.Status.PENDING_REVIEW);
        assertTrue(h.reversible());
        h.hide(active.getId());
        h.hide(pending.getId());
        assertEquals(UserEvent.Status.HIDDEN, events.findById(active.getId()).orElseThrow().getStatus());
        assertEquals(UserEvent.Status.PENDING_REVIEW, events.findById(pending.getId()).orElseThrow().getStatus());
        assertTrue(h.exists(active.getId()));
        h.unhide(active.getId());
        assertEquals(UserEvent.Status.ACTIVE, events.findById(active.getId()).orElseThrow().getStatus());
        assertEquals("REPORT_UNHIDE", moderation.detail(active.getId()).history().get(0).action());
    }

    // ---- liste / suzme ----

    private List<String> titles(CursorPage<EventView> p) {
        return p.items().stream().map(EventView::title).toList();
    }

    @Test
    void searchIsTurkishCaseInsensitiveAndEscapesLikeWildcards() {
        User owner = user("Sahip");
        String t = token();
        event(t + " İstanbul Gezisi", owner, UserEvent.Status.ACTIVE);
        event(t + " ISPARTA kampı", owner, UserEvent.Status.ACTIVE);
        event(t + " yuzde%100", owner, UserEvent.Status.ACTIVE);
        event(t + " alt_cizgi", owner, UserEvent.Status.ACTIVE);
        event(t + " altXcizgi", owner, UserEvent.Status.ACTIVE);

        assertEquals(1, titles(moderation.list("ALL", t + " istanbul", null, false, null, null, null, null, 50)).size());
        assertEquals(1, titles(moderation.list("ALL", t + " İSTANBUL", null, false, null, null, null, null, 50)).size());
        // ISPARTA <- ısparta (noktasiz ı), ıspar, Isparta
        assertEquals(1, titles(moderation.list("ALL", t + " ısparta", null, false, null, null, null, null, 50)).size());
        assertEquals(1, titles(moderation.list("ALL", t + " Isparta", null, false, null, null, null, null, 50)).size());
        // joker kacisi: '%' yalnizca '%' icereni, '_' yalnizca '_' icereni bulur
        assertEquals(List.of(t + " yuzde%100"),
                titles(moderation.list("ALL", t + " yuzde%", null, false, null, null, null, null, 50)));
        assertEquals(0, moderation.list("ALL", t + "%", null, false, null, null, null, null, 50).items().size());
        assertEquals(List.of(t + " alt_cizgi"),
                titles(moderation.list("ALL", t + " alt_cizgi", null, false, null, null, null, null, 50)));
        assertEquals(5, moderation.list("ALL", t, null, false, null, null, null, null, 50).items().size());
        // bos/bosluk q suzme yapmaz (yalnizca durum)
        assertTrue(moderation.list("ALL", "   ", null, false, null, null, null, null, 50).items().size() >= 5);
    }

    @Test
    void searchMatchesLocationCommunityNameAndOrganizerName() {
        String t = token();
        User owner = user("Organizator " + t);
        Community c = new Community();
        c.setName("Kulup " + t);
        c.setSlug("s-" + t);
        c.setOwnerId(owner.getId());
        c.setStatus(Community.Status.ACTIVE);
        c = communities.saveAndFlush(c);
        UserEvent inClub = event("Baslik A", owner, UserEvent.Status.ACTIVE);
        inClub.setCommunityId(c.getId());
        events.saveAndFlush(inClub);
        UserEvent withPlace = event("Baslik B", user("Baska"), UserEvent.Status.ACTIVE);
        withPlace.setLocation("Salon " + t.toUpperCase());
        events.saveAndFlush(withPlace);

        List<Long> ids = moderation.list("ALL", t, null, false, null, null, null, null, 50).items().stream()
                .map(EventView::id).toList();
        // organizator adi + kulup adi ayni etkinligi (A) bulur, yer adi B'yi bulur
        assertTrue(ids.contains(inClub.getId()));
        assertTrue(ids.contains(withPlace.getId()));
        assertEquals(2, ids.size());
        List<Long> byCommunity = moderation.list("ALL", null, c.getId(), false, null, null, null, null, 50).items().stream()
                .map(EventView::id).toList();
        assertEquals(List.of(inClub.getId()), byCommunity);
        assertEquals(c.getId(), moderation.list("ALL", t, c.getId(), false, null, null, null, null, 50).items().get(0).communityId());
        List<Long> alone = moderation.list("ALL", t, null, true, null, null, null, null, 50).items().stream()
                .map(EventView::id).toList();
        assertEquals(List.of(withPlace.getId()), alone);
    }

    @Test
    void filtersByStatusJoinPolicyAndDateRange() {
        User owner = user("Sahip");
        String t = token();
        UserEvent a = event(t + " a", owner, UserEvent.Status.ACTIVE);
        event(t + " p", owner, UserEvent.Status.PENDING_REVIEW);
        event(t + " h", owner, UserEvent.Status.HIDDEN);
        UserEvent later = event(t + " later", owner, UserEvent.Status.ACTIVE);
        later.setStartsAt(soon.plus(Duration.ofDays(30)));
        later.setEndsAt(soon.plus(Duration.ofDays(30)).plus(Duration.ofHours(1)));
        events.saveAndFlush(later);
        EventAdmission cfg = new EventAdmission(a.getId());
        cfg.setMode(EventAdmission.Mode.APPROVAL);
        admissions.saveAndFlush(cfg);

        // varsayilan (status yok) = PENDING_REVIEW (eski davranis)
        assertEquals(List.of(t + " p"), titles(moderation.list(null, t, null, false, null, null, null, null, 50)));
        assertEquals(List.of(t + " h"), titles(moderation.list("hidden", t, null, false, null, null, null, null, 50)));
        assertEquals(4, moderation.list("ALL", t, null, false, null, null, null, null, 50).items().size());
        assertEquals(List.of(t + " a"),
                titles(moderation.list("ACTIVE", t, null, false, EventAdmission.Mode.APPROVAL, null, null, null, 50)));
        assertEquals(List.of(t + " later"),
                titles(moderation.list("ACTIVE", t, null, false, EventAdmission.Mode.OPEN, null, null, null, 50)));
        // tarih araligi: baslangic [soon+10g, soon+60g) yalnizca "later"
        assertEquals(List.of(t + " later"), titles(moderation.list("ALL", t, null, false, null,
                soon.plus(Duration.ofDays(10)), soon.plus(Duration.ofDays(60)), null, 50)));
        assertEquals(3, moderation.list("ALL", t, null, false, null, null, soon.plus(Duration.ofDays(10)), null, 50).items().size());
        assertEquals("INVALID_DATES", fail(() -> moderation.list("ALL", t, null, false, null, soon, soon, null, 50)).code());
        assertEquals("VALIDATION_ERROR", fail(() -> moderation.list("BOGUS", t, null, false, null, null, null, null, 50)).code());
    }

    @Test
    void adminListFillsPendingCountForApprovalEvents() {
        User owner = user("Sahip");
        String t = token();
        UserEvent approval = event(t + " onayli", owner, UserEvent.Status.ACTIVE);
        UserEvent open = event(t + " acik", owner, UserEvent.Status.ACTIVE);
        EventAdmission cfg = new EventAdmission(approval.getId());
        cfg.setMode(EventAdmission.Mode.APPROVAL);
        admissions.saveAndFlush(cfg);
        applications.saveAndFlush(new EventApplication(approval.getId(), user("A1").getId()));
        applications.saveAndFlush(new EventApplication(approval.getId(), user("A2").getId()));
        EventApplication accepted = new EventApplication(approval.getId(), user("A3").getId());
        accepted.setStatus(EventApplication.Status.ACCEPTED);
        applications.saveAndFlush(accepted);

        List<EventView> items = moderation.list("ALL", t, null, false, null, null, null, null, 50).items();
        EventView a = items.stream().filter(x -> x.id().equals(approval.getId())).findFirst().orElseThrow();
        EventView o = items.stream().filter(x -> x.id().equals(open.getId())).findFirst().orElseThrow();
        assertEquals(2L, a.pendingCount());
        assertEquals(EventAdmission.Mode.APPROVAL, a.joinPolicy());
        assertEquals(0L, o.pendingCount()); // null degil: yonetici her etkinligi yonetir
        assertTrue(a.canManage());

        AdminEventDetail d = moderation.detail(approval.getId());
        assertEquals(2L, d.requests().pending());
        assertEquals(1L, d.requests().accepted());
        assertEquals(2L, d.event().pendingCount());
        assertEquals(owner.getEmail(), d.organizerEmail());
        assertNotNull(d.event().interestedCount());
        assertNull(d.moderationReason());
    }

    @Test
    void cursorPaginationWalksAllWithoutDuplicates() {
        User owner = user("Sahip");
        String t = token();
        List<Long> created = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            created.add(event(t + " n" + i, owner, UserEvent.Status.ACTIVE).getId());
        }
        List<Long> seen = new ArrayList<>();
        Long cursor = null;
        int pages = 0;
        do {
            CursorPage<EventView> p = moderation.list("ALL", t, null, false, null, null, null, cursor, 2);
            assertTrue(p.items().size() <= 2);
            p.items().forEach(x -> seen.add(x.id()));
            cursor = p.nextCursor();
            pages++;
        } while (cursor != null && pages < 10);
        assertEquals(3, pages);
        assertEquals(5, seen.size());
        List<Long> expected = new ArrayList<>(created);
        java.util.Collections.reverse(expected); // id'ye gore azalan
        assertEquals(expected, seen);
    }

    @Autowired edu.bingol.backend.community.CommunityMemberRepository clubMembers;

    private Community club(User owner) {
        Community c = new Community();
        String t = token();
        c.setName("K " + t);
        c.setSlug("k-" + t);
        c.setOwnerId(owner.getId());
        c.setStatus(Community.Status.ACTIVE);
        return communities.saveAndFlush(c);
    }

    private edu.bingol.backend.event.dto.EventDtos.CreateEventRequest createReq(Long communityId) {
        return new edu.bingol.backend.event.dto.EventDtos.CreateEventRequest("Kulup etkinligi " + token(), null, soon,
                soon.plus(Duration.ofHours(1)), null, null, communityId, null);
    }

    @Test
    void createRulesClubRequiredStaffActiveGrantedMemberPendingPlainMemberForbidden() {
        User owner = user("Sahip");
        User mod = user("Mod");
        User granted = user("Yetkili uye");
        User plain = user("Sade");
        Community c = club(owner);
        clubMembers.saveAndFlush(new edu.bingol.backend.community.CommunityMember(c.getId(), owner.getId(),
                edu.bingol.backend.community.CommunityMember.Role.OWNER, edu.bingol.backend.community.CommunityMember.Status.ACTIVE));
        clubMembers.saveAndFlush(new edu.bingol.backend.community.CommunityMember(c.getId(), mod.getId(),
                edu.bingol.backend.community.CommunityMember.Role.MODERATOR, edu.bingol.backend.community.CommunityMember.Status.ACTIVE));
        clubMembers.saveAndFlush(new edu.bingol.backend.community.CommunityMember(c.getId(), plain.getId(),
                edu.bingol.backend.community.CommunityMember.Role.MEMBER, edu.bingol.backend.community.CommunityMember.Status.ACTIVE));
        clubMembers.saveAndFlush(new edu.bingol.backend.community.CommunityMember(c.getId(), granted.getId(),
                edu.bingol.backend.community.CommunityMember.Role.MEMBER, edu.bingol.backend.community.CommunityMember.Status.ACTIVE));
        var g = new edu.bingol.backend.community.permissions.ClubMemberGrant();
        g.setCommunityId(c.getId());
        g.setUserId(granted.getId());
        g.setPermissionSet(java.util.EnumSet.of(edu.bingol.backend.community.permissions.ClubPermission.MANAGE_EVENTS));
        grants.saveAndFlush(g);

        assertEquals("EVENT_CLUB_REQUIRED", fail(() -> service.create(new Actor(mod.getId(), false), createReq(null))).code());
        assertEquals(UserEvent.Status.ACTIVE, service.create(new Actor(owner.getId(), false), createReq(c.getId())).status());
        assertEquals(UserEvent.Status.ACTIVE, service.create(new Actor(mod.getId(), false), createReq(c.getId())).status());
        assertEquals(UserEvent.Status.PENDING_REVIEW, service.create(new Actor(granted.getId(), false), createReq(c.getId())).status());
        assertEquals(403, fail(() -> service.create(new Actor(plain.getId(), false), createReq(c.getId()))).status().value());
        assertEquals(403, fail(() -> service.create(new Actor(user("Yabanci").getId(), false), createReq(c.getId()))).status().value());
    }

    @Test
    void adminEditsAndDeletesAnyEventWithAuditAndSideEffects() {
        User owner = user("Sahip");
        User going = user("Katilimci");
        UserEvent e = event(token() + " eski", owner, UserEvent.Status.ACTIVE);
        rsvps.saveAndFlush(new EventRsvp(e.getId(), going.getId(), EventRsvp.Status.GOING));

        var req = new edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest("Yeni baslik", null, null, null, "Yeni yer",
                50, EventAdmission.Mode.APPROVAL);
        AdminEventDetail d = moderation.edit(9L, e.getId(), req, "Yazim duzeltme");
        assertEquals("Yeni baslik", d.event().title());
        assertEquals("Yeni yer", d.event().location());
        assertEquals(50, d.event().capacity());
        assertEquals(EventAdmission.Mode.APPROVAL, d.event().joinPolicy());
        assertEquals("EDIT", d.history().get(0).action());
        assertEquals("Yazim duzeltme", d.history().get(0).reason());
        // yer degisti: katilimciya "guncellendi"
        verify(notifications).sendTemplated(eq(going.getId()), eq(NotificationType.EVENT), eq("notif.event.updated"),
                anyMap(), eq("Yeni baslik"));

        AdminEventDetail del = moderation.delete(9L, e.getId(), "Kural ihlali");
        assertEquals(UserEvent.Status.CANCELLED, del.event().status());
        assertEquals("DELETE", del.history().get(0).action());
        verify(notifications).sendTemplated(eq(going.getId()), eq(NotificationType.EVENT), eq("notif.event.cancelled"),
                anyMap(), eq("Yeni baslik"));
        verify(rooms).closeRoomIsolated(RoomKind.EVENT, e.getId());
        assertEquals("EVENT_INVALID_TRANSITION", fail(() -> moderation.delete(9L, e.getId(), "x")).code());
        assertEquals("EVENT_NOT_EDITABLE", fail(() -> moderation.edit(9L, e.getId(), req, null)).code());
    }

    @Test
    void creatorAndClubManagerCanEditAndDeleteOwnClubEvent() {
        User owner = user("Sahip");
        User mod = user("Mod");
        User stranger = user("Yabanci");
        Community c = club(owner);
        clubMembers.saveAndFlush(new edu.bingol.backend.community.CommunityMember(c.getId(), mod.getId(),
                edu.bingol.backend.community.CommunityMember.Role.MODERATOR, edu.bingol.backend.community.CommunityMember.Status.ACTIVE));
        UserEvent e = event(token(), owner, UserEvent.Status.ACTIVE);
        e.setCommunityId(c.getId());
        events.saveAndFlush(e);
        var req = new edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest("Guncel", null, null, null, null, null, null);

        assertEquals("Guncel", service.update(new Actor(mod.getId(), false), e.getId(), req).title());
        assertEquals(403, fail(() -> service.update(new Actor(stranger.getId(), false), e.getId(), req)).status().value());
        service.delete(new Actor(mod.getId(), false), e.getId());
        assertEquals(UserEvent.Status.CANCELLED, events.findById(e.getId()).orElseThrow().getStatus());
    }
}
