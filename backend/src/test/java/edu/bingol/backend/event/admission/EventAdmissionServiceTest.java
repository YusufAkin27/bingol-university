package edu.bingol.backend.event.admission;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.admission.AdmissionDtos.Action;
import edu.bingol.backend.event.admission.AdmissionDtos.ApplicationView;
import edu.bingol.backend.event.admission.AdmissionDtos.ApplyRequest;
import edu.bingol.backend.event.admission.AdmissionDtos.DecisionResult;
import edu.bingol.backend.event.admission.EventAdmission.Mode;
import edu.bingol.backend.event.admission.EventApplication.Status;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;

/** Durum makinesi, terfi sirasi ve yetkiler (Mockito). Eszamanlilik uctan uca betikle (scripts/event-admission-*.sh) sinanir. */
class EventAdmissionServiceTest {

    private static final long EVENT_ID = 7L;
    private static final long ORGANIZER = 99L;

    private final EventService events = mock(EventService.class);
    private final EventAdmissionRepository configs = mock(EventAdmissionRepository.class);
    private final EventApplicationRepository apps = mock(EventApplicationRepository.class);
    private final AdmissionEventRepository eventRows = mock(AdmissionEventRepository.class);
    private final UserEventRepository eventRepo = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final BlockService blocks = mock(BlockService.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final AdmissionSettings settings = mock(AdmissionSettings.class);
    private final EventAdmissionService svc = new EventAdmissionService(events, configs, apps, eventRows, eventRepo,
            rsvps, notifications, blocks, communities, settings);

    private final Actor organizer = new Actor(ORGANIZER, false);
    private final Actor user = new Actor(1L, false);
    private final Map<Long, User> users = new HashMap<>();
    private UserEvent event;
    private EventAdmission config;

    @BeforeEach
    void setUp() {
        event = new UserEvent();
        event.setId(EVENT_ID);
        event.setTitle("Konferans");
        event.setStatus(UserEvent.Status.ACTIVE);
        event.setStartsAt(Instant.now().plus(Duration.ofDays(2)));
        event.setEndsAt(Instant.now().plus(Duration.ofDays(2)).plus(Duration.ofHours(2)));
        event.setCreatedBy(ORGANIZER);
        event.setCapacity(1);
        when(events.load(EVENT_ID)).thenReturn(event);
        when(events.loadVisible(any(), eq(EVENT_ID))).thenReturn(event);
        when(events.requireManager(any(), any())).thenAnswer(inv -> {
            Actor a = inv.getArgument(0);
            if (!a.admin() && !a.id().equals(ORGANIZER)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "yetki yok");
            }
            return inv.getArgument(1);
        });
        config = new EventAdmission(EVENT_ID);
        config.setMode(Mode.APPROVAL);
        when(configs.findById(EVENT_ID)).thenReturn(Optional.of(config));
        when(apps.saveAndFlush(any())).thenAnswer(inv -> {
            EventApplication x = inv.getArgument(0);
            if (x.getId() == null) {
                x.setId(500L + x.getUserId());
            }
            return x;
        });
        when(communities.usersById(anyCollection())).thenAnswer(inv -> {
            Map<Long, User> m = new HashMap<>();
            for (Object id : (java.util.Collection<?>) inv.getArgument(0)) {
                if (users.containsKey(id)) {
                    m.put((Long) id, users.get(id));
                }
            }
            return m;
        });
        addUser(1L, UserStatus.ACTIVE);
        addUser(2L, UserStatus.ACTIVE);
        addUser(3L, UserStatus.ACTIVE);
        addUser(ORGANIZER, UserStatus.ACTIVE);
        when(eventRows.capacityOf(EVENT_ID)).thenReturn(1);
    }

    private void addUser(long id, UserStatus st) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("Kisi" + id);
        u.setStatus(st);
        users.put(id, u);
    }

    private ApiException error(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    private EventApplication app(long id, long userId, Status st) {
        EventApplication a = new EventApplication(EVENT_ID, userId);
        a.setId(id);
        a.setStatus(st);
        when(apps.findByIdAndEventId(id, EVENT_ID)).thenReturn(Optional.of(a));
        when(apps.findByEventIdAndUserId(EVENT_ID, userId)).thenReturn(Optional.of(a));
        return a;
    }

    // ---- basvuru ----

    @Test
    void applyOnOpenEventIsRejected() {
        when(configs.findById(EVENT_ID)).thenReturn(Optional.empty());

        assertEquals("ADMISSION_NOT_REQUIRED", error(() -> svc.apply(user, EVENT_ID, null)).code());
    }

    @Test
    void organizerCannotApplyToOwnEvent() {
        assertEquals("ORGANIZER_CANNOT_APPLY", error(() -> svc.apply(organizer, EVENT_ID, null)).code());
    }

    @Test
    void blockedApplicantSeesNotFound() {
        when(blocks.isBlocked(ORGANIZER, 1L)).thenReturn(true);

        assertEquals("EVENT_NOT_FOUND", error(() -> svc.apply(user, EVENT_ID, null)).code());
    }

    @Test
    void everyQuestionNeedsAnAnswer() {
        config.setQuestions(List.of("Neden katilmak istiyorsunuz?", "Bolumunuz?"));

        assertEquals("ANSWERS_REQUIRED",
                error(() -> svc.apply(user, EVENT_ID, new ApplyRequest("n", List.of("cevap", " ")))).code());
        assertEquals("ANSWERS_REQUIRED", error(() -> svc.apply(user, EVENT_ID, null)).code());
    }

    @Test
    void applyCreatesPendingAndNotifiesOrganizer() {
        config.setQuestions(List.of("Soru"));
        when(apps.findByEventIdAndUserId(EVENT_ID, 1L)).thenReturn(Optional.empty());

        ApplicationView v = svc.apply(user, EVENT_ID, new ApplyRequest(" not ", List.of(" cevap ")));

        assertEquals(Status.PENDING, v.status());
        assertEquals("not", v.note());
        assertEquals(List.of("cevap"), v.answers());
        verify(notifications).sendTemplated(eq(ORGANIZER), eq(NotificationType.EVENT), eq("notif.admission.received"),
                any(), eq("Konferans"), eq("Kisi1"));
    }

    @Test
    void duplicateAndRejectedApplicationsAreRefusedButCancelledCanReapply() {
        EventApplication a = app(10L, 1L, Status.PENDING);
        assertEquals("ALREADY_APPLIED", error(() -> svc.apply(user, EVENT_ID, null)).code());
        a.setStatus(Status.ACCEPTED);
        assertEquals("ALREADY_APPLIED", error(() -> svc.apply(user, EVENT_ID, null)).code());
        a.setStatus(Status.REJECTED);
        assertEquals("APPLICATION_REJECTED", error(() -> svc.apply(user, EVENT_ID, null)).code());

        a.setStatus(Status.CANCELLED);
        a.setQueuedAt(Instant.now());
        ApplicationView v = svc.apply(user, EVENT_ID, null);

        assertEquals(Status.PENDING, v.status());
        assertNull(a.getQueuedAt());
    }

    @Test
    void applyAfterEventEndedIsRefused() {
        event.setEndsAt(Instant.now().minusSeconds(5));

        assertEquals("EVENT_ENDED", error(() -> svc.apply(user, EVENT_ID, null)).code());
    }

    // ---- kabul / bekleme / ret ----

    @Test
    void acceptTakesSeatAndCreatesGoingRsvp() {
        EventApplication a = app(10L, 1L, Status.PENDING);
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(1);
        when(rsvps.findByEventIdAndUserId(EVENT_ID, 1L)).thenReturn(Optional.empty());

        var item = svc.decideOne(organizer, EVENT_ID, 10L, Action.ACCEPT, null);

        assertEquals(Status.ACCEPTED, item.status());
        assertEquals(ORGANIZER, a.getDecidedBy());
        ArgumentCaptor<EventRsvp> c = ArgumentCaptor.forClass(EventRsvp.class);
        verify(rsvps).save(c.capture());
        assertEquals(EventRsvp.Status.GOING, c.getValue().getStatus());
        verify(notifications).sendTemplated(eq(1L), eq(NotificationType.EVENT), eq("notif.admission.accepted"), any(),
                eq("Konferans"));
    }

    @Test
    void acceptWhenFullAutomaticallyWaitlists() {
        EventApplication a = app(10L, 1L, Status.PENDING);
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(0);

        var item = svc.decideOne(organizer, EVENT_ID, 10L, Action.ACCEPT, null);

        assertEquals(Status.WAITLISTED, item.status());
        assertNotNull(a.getQueuedAt());
        verify(rsvps, never()).save(any());
        verify(notifications).sendTemplated(eq(1L), eq(NotificationType.EVENT), eq("notif.admission.waitlisted"), any(),
                eq("Konferans"));
    }

    @Test
    void acceptingAlreadyWaitlistedWhenStillFullKeepsPlace() {
        EventApplication a = app(10L, 1L, Status.WAITLISTED);
        Instant q = Instant.now().minusSeconds(60);
        a.setQueuedAt(q);
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(0);

        assertEquals(Status.WAITLISTED, svc.decideOne(organizer, EVENT_ID, 10L, Action.ACCEPT, null).status());
        assertEquals(q, a.getQueuedAt());
    }

    @Test
    void rejectStoresReasonAndNotifies() {
        EventApplication a = app(10L, 1L, Status.PENDING);

        assertEquals(Status.REJECTED, svc.decideOne(organizer, EVENT_ID, 10L, Action.REJECT, " dolu ").status());

        assertEquals("dolu", a.getDecisionNote());
        verify(notifications).sendTemplated(eq(1L), eq(NotificationType.EVENT), eq("notif.admission.rejectedNote"), any(),
                eq("Konferans"), eq("dolu"));
    }

    @Test
    void invalidTransitionsAreConflicts() {
        app(10L, 1L, Status.REJECTED);
        app(11L, 2L, Status.CANCELLED);
        app(12L, 3L, Status.ACCEPTED);

        assertEquals("INVALID_APPLICATION_STATE", error(() -> svc.decideOne(organizer, EVENT_ID, 10L, Action.ACCEPT, null)).code());
        assertEquals("INVALID_APPLICATION_STATE", error(() -> svc.decideOne(organizer, EVENT_ID, 11L, Action.REJECT, null)).code());
        assertEquals("INVALID_APPLICATION_STATE", error(() -> svc.decideOne(organizer, EVENT_ID, 12L, Action.WAITLIST, null)).code());
    }

    @Test
    void acceptingUnavailableApplicantIsRefused() {
        app(10L, 2L, Status.PENDING);
        users.get(2L).setStatus(UserStatus.SUSPENDED);

        assertEquals("APPLICANT_UNAVAILABLE", error(() -> svc.decideOne(organizer, EVENT_ID, 10L, Action.ACCEPT, null)).code());
        verify(eventRepo, never()).tryIncrementGoing(anyLong());
    }

    @Test
    void waitlistActionMovesPendingToQueue() {
        EventApplication a = app(10L, 1L, Status.PENDING);

        assertEquals(Status.WAITLISTED, svc.decideOne(organizer, EVENT_ID, 10L, Action.WAITLIST, null).status());
        assertNotNull(a.getQueuedAt());
    }

    // ---- yetkiler ----

    @Test
    void onlyOrganizerCanDecideListOrRemove() {
        Actor stranger = new Actor(55L, false);

        assertEquals("FORBIDDEN", error(() -> svc.decideOne(stranger, EVENT_ID, 10L, Action.ACCEPT, null)).code());
        assertEquals("FORBIDDEN", error(() -> svc.decide(stranger, EVENT_ID, List.of(10L), Action.ACCEPT, null)).code());
        assertEquals("FORBIDDEN", error(() -> svc.list(stranger, EVENT_ID, null, null, 20)).code());
        assertEquals("FORBIDDEN", error(() -> svc.removeParticipant(stranger, EVENT_ID, 1L)).code());
        assertEquals("FORBIDDEN", error(() -> svc.setConfig(stranger, EVENT_ID,
                new AdmissionDtos.ConfigRequest(Mode.OPEN, null))).code());
    }

    @Test
    void applicationOfAnotherEventIsNotFound() {
        when(apps.findByIdAndEventId(10L, EVENT_ID)).thenReturn(Optional.empty());

        assertEquals("APPLICATION_NOT_FOUND", error(() -> svc.decideOne(organizer, EVENT_ID, 10L, Action.ACCEPT, null)).code());
    }

    @Test
    void bulkDecisionReportsPerItemResults() {
        app(10L, 1L, Status.PENDING);
        app(11L, 2L, Status.REJECTED);
        when(apps.findByIdAndEventId(12L, EVENT_ID)).thenReturn(Optional.empty());
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(1);

        DecisionResult r = svc.decide(organizer, EVENT_ID, List.of(10L, 11L, 12L, 10L), Action.ACCEPT, null);

        assertEquals(3, r.items().size());
        assertEquals(Status.ACCEPTED, r.items().get(0).status());
        assertEquals("INVALID_APPLICATION_STATE", r.items().get(1).error());
        assertEquals("APPLICATION_NOT_FOUND", r.items().get(2).error());
    }

    // ---- terfi ----

    @Test
    void rejectingAcceptedParticipantFreesSeatAndPromotesFirstInQueue() {
        EventApplication accepted = app(10L, 1L, Status.ACCEPTED);
        EventRsvp going = new EventRsvp(EVENT_ID, 1L, EventRsvp.Status.GOING);
        when(rsvps.findByEventIdAndUserId(EVENT_ID, 1L)).thenReturn(Optional.of(going));
        EventApplication w1 = app(20L, 2L, Status.WAITLISTED);
        w1.setQueuedAt(Instant.now().minusSeconds(100));
        when(eventRows.capacityOf(EVENT_ID)).thenReturn(1);
        when(eventRepo.goingCount(EVENT_ID)).thenReturn(0, 1);
        when(apps.waitlist(eq(EVENT_ID), eq(Status.WAITLISTED), any(Pageable.class))).thenReturn(List.of(w1));
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(1);
        when(rsvps.findByEventIdAndUserId(EVENT_ID, 2L)).thenReturn(Optional.empty());

        svc.removeParticipant(organizer, EVENT_ID, 1L);

        assertEquals(Status.REJECTED, accepted.getStatus());
        verify(eventRepo).decrementGoing(EVENT_ID);
        verify(rsvps).delete(going);
        assertEquals(Status.ACCEPTED, w1.getStatus());
        verify(notifications).sendTemplated(eq(2L), eq(NotificationType.EVENT), eq("notif.admission.promoted"), any(),
                eq("Konferans"));
        verify(notifications).sendTemplated(eq(1L), eq(NotificationType.EVENT), eq("notif.admission.removed"), any(),
                eq("Konferans"));
    }

    @Test
    void promotionFollowsQueueOrderSkipsUnavailableAndStopsAtCapacity() {
        users.get(2L).setStatus(UserStatus.DELETED);
        EventApplication w1 = app(20L, 2L, Status.WAITLISTED);
        EventApplication w2 = app(21L, 3L, Status.WAITLISTED);
        EventApplication w3 = app(22L, 1L, Status.WAITLISTED);
        when(eventRows.capacityOf(EVENT_ID)).thenReturn(2);
        when(eventRepo.goingCount(EVENT_ID)).thenReturn(1, 1, 2);
        // Depo her cagrida siradaki WAITLISTED'i verir (durumu degisenler listeden duser)
        when(apps.waitlist(eq(EVENT_ID), eq(Status.WAITLISTED), any(Pageable.class))).thenAnswer(inv -> {
            for (EventApplication x : List.of(w1, w2, w3)) {
                if (x.getStatus() == Status.WAITLISTED) {
                    return List.of(x);
                }
            }
            return List.of();
        });
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(1);
        when(rsvps.findByEventIdAndUserId(eq(EVENT_ID), anyLong())).thenReturn(Optional.empty());

        svc.promoteWaitlist(event);

        assertEquals(Status.CANCELLED, w1.getStatus());
        assertEquals(Status.ACCEPTED, w2.getStatus());
        assertEquals(Status.WAITLISTED, w3.getStatus());
    }

    @Test
    void unlimitedCapacityPromotesEveryone() {
        EventApplication w1 = app(20L, 2L, Status.WAITLISTED);
        EventApplication w2 = app(21L, 3L, Status.WAITLISTED);
        when(eventRows.capacityOf(EVENT_ID)).thenReturn(null);
        when(apps.waitlist(eq(EVENT_ID), eq(Status.WAITLISTED), any(Pageable.class))).thenAnswer(inv ->
                w1.getStatus() == Status.WAITLISTED ? List.of(w1) : w2.getStatus() == Status.WAITLISTED ? List.of(w2) : List.of());
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(1);
        when(rsvps.findByEventIdAndUserId(eq(EVENT_ID), anyLong())).thenReturn(Optional.empty());

        svc.promoteWaitlist(event);

        assertEquals(Status.ACCEPTED, w1.getStatus());
        assertEquals(Status.ACCEPTED, w2.getStatus());
    }

    @Test
    void noPromotionWhenEventCancelledOrEnded() {
        event.setStatus(UserEvent.Status.CANCELLED);

        svc.promoteWaitlist(event);

        verify(eventRepo, never()).tryIncrementGoing(anyLong());
    }

    @Test
    void withdrawAcceptedFreesSeatAndPromotes() {
        EventApplication a = app(10L, 1L, Status.ACCEPTED);
        EventRsvp going = new EventRsvp(EVENT_ID, 1L, EventRsvp.Status.GOING);
        when(rsvps.findByEventIdAndUserId(EVENT_ID, 1L)).thenReturn(Optional.of(going));
        when(eventRepo.goingCount(EVENT_ID)).thenReturn(1);

        ApplicationView v = svc.withdraw(user, EVENT_ID);

        assertEquals(Status.CANCELLED, v.status());
        assertEquals(Status.CANCELLED, a.getStatus());
        verify(eventRepo).decrementGoing(EVENT_ID);
        verify(rsvps).delete(going);
    }

    @Test
    void withdrawPendingDoesNotTouchSeats() {
        app(10L, 1L, Status.PENDING);

        assertEquals(Status.CANCELLED, svc.withdraw(user, EVENT_ID).status());
        verify(eventRepo, never()).decrementGoing(anyLong());
    }

    @Test
    void withdrawIsIdempotentButRejectedCannotWithdraw() {
        EventApplication a = app(10L, 1L, Status.CANCELLED);
        assertEquals(Status.CANCELLED, svc.withdraw(user, EVENT_ID).status());

        a.setStatus(Status.REJECTED);
        assertEquals("INVALID_APPLICATION_STATE", error(() -> svc.withdraw(user, EVENT_ID)).code());
    }

    @Test
    void withdrawWithoutApplicationIsNotFound() {
        when(apps.findByEventIdAndUserId(EVENT_ID, 1L)).thenReturn(Optional.empty());

        assertEquals("APPLICATION_NOT_FOUND", error(() -> svc.withdraw(user, EVENT_ID)).code());
    }

    @Test
    void removingNonParticipantIsNotFound() {
        when(apps.findByEventIdAndUserId(EVENT_ID, 2L)).thenReturn(Optional.empty());
        when(rsvps.findByEventIdAndUserId(EVENT_ID, 2L)).thenReturn(Optional.empty());

        assertEquals("PARTICIPANT_NOT_FOUND", error(() -> svc.removeParticipant(organizer, EVENT_ID, 2L)).code());
    }

    @Test
    void capacityIncreasePromotesWaitlistAndRefreshesCount() {
        EventApplication w1 = app(20L, 2L, Status.WAITLISTED);
        when(apps.countByEventIdAndStatus(EVENT_ID, Status.WAITLISTED)).thenReturn(1L);
        when(eventRows.capacityOf(EVENT_ID)).thenReturn(3);
        when(eventRepo.goingCount(EVENT_ID)).thenReturn(1, 1, 2);
        when(apps.waitlist(eq(EVENT_ID), eq(Status.WAITLISTED), any(Pageable.class))).thenAnswer(inv ->
                w1.getStatus() == Status.WAITLISTED ? List.of(w1) : List.of());
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(1);
        when(rsvps.findByEventIdAndUserId(EVENT_ID, 2L)).thenReturn(Optional.empty());

        svc.afterCapacityChanged(event);

        assertEquals(Status.ACCEPTED, w1.getStatus());
        assertEquals(2, event.getGoingCount());
    }

    @Test
    void capacityChangeWithoutWaitlistTakesNoLock() {
        when(apps.countByEventIdAndStatus(EVENT_ID, Status.WAITLISTED)).thenReturn(0L);

        svc.afterCapacityChanged(event);

        verify(eventRows, never()).lock(anyLong());
    }

    // ---- hooks ----

    @Test
    void directGoingIsBlockedInApprovalModeOnly() {
        assertEquals("APPLICATION_REQUIRED", error(() -> svc.guardDirectRsvp(event, EventRsvp.Status.GOING)).code());
        svc.guardDirectRsvp(event, EventRsvp.Status.INTERESTED);

        config.setMode(Mode.OPEN);
        svc.guardDirectRsvp(event, EventRsvp.Status.GOING);
    }

    @Test
    void withdrawAcceptedHookIgnoresUsersWithoutOpenApplication() {
        app(10L, 1L, Status.REJECTED);
        assertEquals(false, svc.withdrawAccepted(user, event));

        when(apps.findByEventIdAndUserId(EVENT_ID, 3L)).thenReturn(Optional.empty());
        assertEquals(false, svc.withdrawAccepted(new Actor(3L, false), event));
    }

    @Test
    void manualAttendanceNeedsAcceptedParticipantInApprovalMode() {
        when(rsvps.findByEventIdAndUserId(EVENT_ID, 1L)).thenReturn(Optional.empty());
        assertEquals("NOT_ACCEPTED", error(() -> svc.requireEligibleForMark(event, 1L)).code());

        when(rsvps.findByEventIdAndUserId(EVENT_ID, 2L))
                .thenReturn(Optional.of(new EventRsvp(EVENT_ID, 2L, EventRsvp.Status.GOING)));
        svc.requireEligibleForMark(event, 2L);

        config.setMode(Mode.OPEN);
        svc.requireEligibleForMark(event, 1L);
    }

    @Test
    void cancelledEventClosesPendingApplicationsAndNotifies() {
        when(apps.userIdsByStatus(eq(EVENT_ID), anyCollection())).thenReturn(List.of(1L, 2L));

        svc.onEventCancelled(event);

        verify(apps).closeAll(eq(EVENT_ID), anyCollection(), eq(Status.CANCELLED), any());
        verify(notifications).sendTemplated(eq(1L), eq(NotificationType.EVENT), eq("notif.event.cancelled"), any(), anyString());
        verify(notifications).sendTemplated(eq(2L), eq(NotificationType.EVENT), eq("notif.event.cancelled"), any(), anyString());
    }

    // ---- sinirlar ----

    @Test
    void openEventLimitIsEnforcedAndAdminsAreExempt() {
        when(settings.maxOpenPerUser()).thenReturn(2);
        when(settings.dailyCreateLimit()).thenReturn(0);
        when(eventRows.countOpen(eq(1L), anyCollection(), any())).thenReturn(2L);

        ApiException ex = error(() -> svc.beforeCreate(user));
        assertEquals("EVENT_LIMIT_OPEN", ex.code());
        assertEquals(HttpStatus.CONFLICT, ex.status());
        svc.beforeCreate(new Actor(1L, true));
    }

    @Test
    void dailyCreateLimitIsEnforced() {
        when(settings.maxOpenPerUser()).thenReturn(0);
        when(settings.dailyCreateLimit()).thenReturn(3);
        when(eventRows.countCreatedSince(eq(1L), any())).thenReturn(3L);

        ApiException ex = error(() -> svc.beforeCreate(user));
        assertEquals("EVENT_LIMIT_DAILY", ex.code());
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, ex.status());

        when(eventRows.countCreatedSince(eq(1L), any())).thenReturn(2L);
        svc.beforeCreate(user);
    }

    // ---- yapilandirma ----

    @Test
    void atMostThreeQuestions() {
        assertEquals("VALIDATION_ERROR", error(() -> EventAdmissionService.cleanQuestions(List.of("a", "b", "c", "d"))).code());
        assertEquals(List.of("a", "b"), EventAdmissionService.cleanQuestions(List.of(" a ", "", "b")));
    }

    @Test
    void switchingToOpenCancelsPendingApplications() {
        when(configs.findById(EVENT_ID)).thenReturn(Optional.of(config));
        when(apps.userIdsByStatus(eq(EVENT_ID), anyCollection())).thenReturn(List.of(2L));

        var v = svc.setConfig(organizer, EVENT_ID, new AdmissionDtos.ConfigRequest(Mode.OPEN, List.of("x")));

        assertEquals(Mode.OPEN, v.mode());
        assertEquals(List.of(), v.questions());
        verify(apps).closeAll(eq(EVENT_ID), anyCollection(), eq(Status.CANCELLED), any());
        verify(notifications).sendTemplated(eq(2L), eq(NotificationType.EVENT), eq("notif.admission.modeOpen"), any(), eq("Konferans"));
    }

    @Test
    void configCannotChangeAfterEventEnded() {
        event.setEndsAt(Instant.now().minusSeconds(1));

        assertEquals("EVENT_ENDED", error(() -> svc.setConfig(organizer, EVENT_ID,
                new AdmissionDtos.ConfigRequest(Mode.APPROVAL, null))).code());
    }

    // ---- joinPolicy / istek uclari ----

    @Test
    void goingInApprovalModeOpensPendingRequest() {
        when(apps.findByEventIdAndUserId(EVENT_ID, 1L)).thenReturn(Optional.empty());
        assertEquals(true, svc.requestIfApprovalRequired(user, event));
        org.mockito.ArgumentCaptor<EventApplication> cap = org.mockito.ArgumentCaptor.forClass(EventApplication.class);
        verify(apps).saveAndFlush(cap.capture());
        assertEquals(Status.PENDING, cap.getValue().getStatus());
        verify(notifications).sendTemplated(eq(ORGANIZER), eq(edu.bingol.backend.notification.NotificationType.EVENT),
                eq("notif.admission.received"), org.mockito.ArgumentMatchers.<Map<String, String>>any(), eq("Konferans"), eq("Kisi1"));
    }

    @Test
    void goingInOpenModeIsNotARequest() {
        config.setMode(Mode.OPEN);
        assertEquals(false, svc.requestIfApprovalRequired(user, event));
        verify(apps, never()).saveAndFlush(any());
    }

    @Test
    void pendingRequestCanBeWithdrawnThroughRsvpHook() {
        app(10L, 1L, Status.PENDING);
        assertEquals(true, svc.withdrawAccepted(user, event));
        assertEquals(Status.CANCELLED, apps.findByEventIdAndUserId(EVENT_ID, 1L).get().getStatus());
    }

    @Test
    void approveRequestFailsWithEventFullWhenCapacityReached() {
        EventApplication a = app(10L, 1L, Status.PENDING);
        when(eventRepo.goingCount(EVENT_ID)).thenReturn(1);
        assertEquals("EVENT_FULL", error(() -> svc.approveRequest(organizer, EVENT_ID, 1L)).code());
        assertEquals(Status.PENDING, a.getStatus());
    }

    @Test
    void approveRequestAcceptsWhenSeatAvailable() {
        EventApplication a = app(10L, 1L, Status.PENDING);
        when(eventRepo.goingCount(EVENT_ID)).thenReturn(0);
        when(eventRepo.tryIncrementGoing(EVENT_ID)).thenReturn(1);
        assertEquals(Status.ACCEPTED, svc.approveRequest(organizer, EVENT_ID, 1L).status());
        assertEquals(Status.ACCEPTED, a.getStatus());
    }

    @Test
    void rejectRequestNotifiesAndNonOrganizerIsForbidden() {
        EventApplication a = app(10L, 1L, Status.PENDING);
        assertEquals("FORBIDDEN", error(() -> svc.rejectRequest(user, EVENT_ID, 1L, null)).code());
        assertEquals(Status.REJECTED, svc.rejectRequest(organizer, EVENT_ID, 1L, null).status());
        assertEquals(Status.REJECTED, a.getStatus());
    }

    @Test
    void requestStatesMapPendingWaitlistedAndRejected() {
        EventApplication p = new EventApplication(8L, 1L);
        p.setStatus(Status.WAITLISTED);
        EventApplication r = new EventApplication(9L, 1L);
        r.setStatus(Status.REJECTED);
        when(apps.mineAmong(eq(1L), anyCollection(), anyCollection())).thenReturn(java.util.List.of(p, r));
        Map<Long, EventRsvp.Status> m = svc.requestStates(1L, java.util.List.of(8L, 9L));
        assertEquals(EventRsvp.Status.PENDING, m.get(8L));
        assertEquals(EventRsvp.Status.REJECTED, m.get(9L));
    }

    @Test
    void switchingApprovalToOpenClosesPendingRequests() {
        when(apps.userIdsByStatus(eq(EVENT_ID), anyCollection())).thenReturn(java.util.List.of(1L));
        svc.applyJoinPolicy(event, Mode.OPEN);
        assertEquals(Mode.OPEN, config.getMode());
        verify(apps).closeAll(eq(EVENT_ID), anyCollection(), eq(Status.CANCELLED), any());
    }
}
