package edu.bingol.backend.community.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnswerInput;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnswerView;
import edu.bingol.backend.community.permissions.ClubAuditService;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

/** Katilim sorulari: form yonetimi (EDIT_INFO), zorunlu yanitlar, yanit gizliligi (MANAGE_MEMBERS). */
class ClubJoinFormServiceTest {

    private final ClubExtrasTestSupport t = new ClubExtrasTestSupport();
    private final ClubJoinQuestionRepository questions = mock(ClubJoinQuestionRepository.class);
    private final ClubJoinAnswerRepository answers = mock(ClubJoinAnswerRepository.class);
    private final ClubAuditService audit = mock(ClubAuditService.class);
    private final ClubJoinFormService svc = new ClubJoinFormService(t.communities, questions, answers, t.members,
            t.permissions, audit);

    private final Actor mod = new Actor(2L, false);
    private final Actor plain = new Actor(3L, false);
    private final Actor applicant = new Actor(9L, false);

    private static ClubJoinQuestion q(long id, int order, String text) {
        ClubJoinQuestion x = new ClubJoinQuestion();
        x.setId(id);
        x.setCommunityId(10L);
        x.setSortOrder(order);
        x.setQuestion(text);
        return x;
    }

    private void approvalClub() {
        t.club.setJoinPolicy(Community.JoinPolicy.APPROVAL);
        when(questions.findByCommunityIdOrderBySortOrderAsc(10L)).thenReturn(List.of(q(1, 0, "Neden?"), q(2, 1, "Bolum?")));
        when(t.communities.join(applicant, 10L)).thenReturn("PENDING");
    }

    // ---- form yonetimi ----

    @Test
    void onlyInfoEditorsSetQuestions() {
        t.member(3L, Role.MEMBER);

        assertEquals(HttpStatus.FORBIDDEN,
                ClubExtrasTestSupport.error(() -> svc.setQuestions(plain, 10L, List.of("Neden katildin?"))).status());
        verify(questions, never()).save(any());
    }

    @Test
    void atMostThreeQuestions() {
        t.member(2L, Role.MODERATOR);

        ApiException e = ClubExtrasTestSupport.error(
                () -> svc.setQuestions(mod, 10L, List.of("Soru bir", "Soru iki", "Soru uc", "Soru dort")));

        assertEquals("QUESTION_LIMIT", e.code());
        assertEquals("3", e.args()[0]);
    }

    @Test
    void tooShortOrLongQuestionRejected() {
        t.member(2L, Role.MODERATOR);

        assertEquals("VALIDATION_ERROR", ClubExtrasTestSupport.error(() -> svc.setQuestions(mod, 10L, List.of("a"))).code());
        assertEquals("VALIDATION_ERROR",
                ClubExtrasTestSupport.error(() -> svc.setQuestions(mod, 10L, List.of("x".repeat(201)))).code());
    }

    @Test
    void existingRowsAreUpdatedInPlaceAndExtrasDeleted() {
        t.member(2L, Role.MODERATOR);
        ClubJoinQuestion a = q(1, 0, "Eski bir");
        ClubJoinQuestion b = q(2, 1, "Eski iki");
        ClubJoinQuestion c = q(3, 2, "Eski uc");
        when(questions.findByCommunityIdOrderBySortOrderAsc(10L)).thenReturn(List.of(a, b, c));

        svc.setQuestions(mod, 10L, List.of("  Yeni bir  "));

        assertEquals("Yeni bir", a.getQuestion());
        verify(questions).save(a);
        verify(questions).deleteAll(List.of(b, c)); // yanitlari FK cascade ile gider
        verify(audit).record(10L, 2L, null, ClubAuditService.JOIN_QUESTIONS_SET, "count=1");
    }

    @Test
    void emptyListClearsTheForm() {
        t.member(2L, Role.MODERATOR);
        ClubJoinQuestion a = q(1, 0, "Eski bir");
        when(questions.findByCommunityIdOrderBySortOrderAsc(10L)).thenReturn(List.of(a));

        svc.setQuestions(mod, 10L, List.of());

        verify(questions).deleteAll(List.of(a));
    }

    // ---- basvuru ----

    @Test
    void approvalClubRequiresAllAnswersAndHasNoSideEffectWhenMissing() {
        approvalClub();

        ApiException e = assertThrows(ApiException.class,
                () -> svc.join(applicant, 10L, List.of(new AnswerInput(1L, "Ogrenmek"))));

        assertEquals("ANSWERS_REQUIRED", e.code());
        verify(t.communities, never()).join(any(), any()); // uyelik satiri/bildirim olusmaz
        verify(answers, never()).save(any());
    }

    @Test
    void blankAnswerCountsAsMissing() {
        approvalClub();

        assertEquals("ANSWERS_REQUIRED", assertThrows(ApiException.class, () -> svc.join(applicant, 10L,
                List.of(new AnswerInput(1L, "Ogrenmek"), new AnswerInput(2L, "   ")))).code());
        assertEquals("ANSWERS_REQUIRED", assertThrows(ApiException.class, () -> svc.join(applicant, 10L, null)).code());
    }

    @Test
    void unknownQuestionIdRejected() {
        approvalClub();

        ApiException e = assertThrows(ApiException.class, () -> svc.join(applicant, 10L,
                List.of(new AnswerInput(1L, "a"), new AnswerInput(2L, "b"), new AnswerInput(99L, "c"))));

        assertEquals("VALIDATION_ERROR", e.code());
    }

    @Test
    void overlongAnswerRejected() {
        approvalClub();

        ApiException e = assertThrows(ApiException.class, () -> svc.join(applicant, 10L,
                List.of(new AnswerInput(1L, "x".repeat(501)), new AnswerInput(2L, "b"))));

        assertEquals("VALIDATION_ERROR", e.code());
    }

    @Test
    void answersAreSavedTrimmedWithPendingRequest() {
        approvalClub();

        String st = svc.join(applicant, 10L, List.of(new AnswerInput(2L, " Bilgisayar "), new AnswerInput(1L, "Ogrenmek")));

        assertEquals("PENDING", st);
        ArgumentCaptor<ClubJoinAnswer> cc = ArgumentCaptor.forClass(ClubJoinAnswer.class);
        verify(answers, org.mockito.Mockito.times(2)).save(cc.capture());
        assertEquals(List.of("Ogrenmek", "Bilgisayar"), cc.getAllValues().stream().map(ClubJoinAnswer::getAnswer).toList());
        assertEquals(9L, cc.getAllValues().get(0).getUserId());
        verify(answers).deleteMember(10L, 9L); // yeniden basvuruda eski yanitlar degisir
    }

    @Test
    void privateClubWithOpenPolicyStillRequiresAnswers() {
        t.club.setJoinPolicy(Community.JoinPolicy.OPEN);
        t.club.setVisibility(Community.Visibility.PRIVATE);
        when(questions.findByCommunityIdOrderBySortOrderAsc(10L)).thenReturn(List.of(q(1, 0, "Neden?")));

        assertEquals("ANSWERS_REQUIRED", assertThrows(ApiException.class, () -> svc.join(applicant, 10L, List.of())).code());
    }

    @Test
    void openClubIgnoresQuestionsAndAnswers() {
        when(t.communities.join(applicant, 10L)).thenReturn("ACTIVE");

        assertEquals("ACTIVE", svc.join(applicant, 10L, List.of(new AnswerInput(1L, "x"))));

        verify(questions, never()).findByCommunityIdOrderBySortOrderAsc(any());
        verify(answers, never()).save(any());
    }

    @Test
    void formWithoutQuestionsJustJoins() {
        t.club.setJoinPolicy(Community.JoinPolicy.APPROVAL);
        when(questions.findByCommunityIdOrderBySortOrderAsc(10L)).thenReturn(List.of());
        when(t.communities.join(applicant, 10L)).thenReturn("PENDING");

        assertEquals("PENDING", svc.join(applicant, 10L, null));
        verify(answers, never()).save(any());
    }

    // ---- yanitlari okuma ----

    @Test
    void plainMemberAndOutsiderCannotReadAnswers() {
        t.member(3L, Role.MEMBER);
        t.member(9L, Role.MEMBER, edu.bingol.backend.community.CommunityMember.Status.PENDING);

        assertEquals(HttpStatus.FORBIDDEN, ClubExtrasTestSupport.error(() -> svc.answersOf(plain, 10L, 9L)).status());
        assertEquals(HttpStatus.FORBIDDEN, ClubExtrasTestSupport.error(() -> svc.answersOf(applicant, 10L, 9L)).status());
    }

    @Test
    void managerReadsAnswersInQuestionOrder() {
        t.member(2L, Role.MODERATOR);
        t.member(9L, Role.MEMBER, edu.bingol.backend.community.CommunityMember.Status.PENDING);
        when(questions.findByCommunityIdOrderBySortOrderAsc(10L)).thenReturn(List.of(q(1, 0, "Neden?"), q(2, 1, "Bolum?")));
        ClubJoinAnswer second = new ClubJoinAnswer();
        second.setQuestionId(2L);
        second.setAnswer("Bilgisayar");
        ClubJoinAnswer first = new ClubJoinAnswer();
        first.setQuestionId(1L);
        first.setAnswer("Ogrenmek");
        when(answers.findByCommunityIdAndUserId(10L, 9L)).thenReturn(List.of(second, first));

        List<AnswerView> out = svc.answersOf(mod, 10L, 9L);

        assertEquals(List.of("Neden?", "Bolum?"), out.stream().map(AnswerView::question).toList());
        assertEquals(List.of("Ogrenmek", "Bilgisayar"), out.stream().map(AnswerView::answer).toList());
    }

    @Test
    void answersOfUnknownUserIs404() {
        t.member(2L, Role.MODERATOR);

        ApiException e = ClubExtrasTestSupport.error(() -> svc.answersOf(mod, 10L, 777L));

        assertEquals(HttpStatus.NOT_FOUND, e.status());
        assertEquals("REQUEST_NOT_FOUND", e.code());
    }

    @Test
    void validateReturnsAnswersInQuestionOrder() {
        Map<Long, String> m = ClubJoinFormService.validate(List.of(q(1, 0, "a"), q(2, 1, "b")),
                List.of(new AnswerInput(2L, "y"), new AnswerInput(1L, "x")));

        assertEquals(List.of(1L, 2L), List.copyOf(m.keySet()));
    }
}
