package edu.bingol.backend.community.extras;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnswerInput;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnswerView;
import edu.bingol.backend.community.extras.ClubExtrasDtos.QuestionView;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.permissions.ClubPermissions;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Katilim sorulari: onayli/ozel kulupte basvuru formu (en fazla {@value #MAX_QUESTIONS} soru). Yanitlar basvuruyla
 * birlikte kaydedilir ve yalnizca MANAGE_MEMBERS yetkililerine gorunur; istek reddedilir / uye ayrilir / cikarilirsa
 * silinir (KVKK veri azaltma).
 */
@Service
public class ClubJoinFormService {

    static final int MAX_QUESTIONS = 3;
    static final int MIN_QUESTION_LEN = 3;
    static final int MAX_ANSWER_LEN = 500;

    private final CommunityService communities;
    private final ClubJoinQuestionRepository questions;
    private final ClubJoinAnswerRepository answers;
    private final CommunityMemberRepository members;
    private final ClubPermissions permissions;
    private final ClubAuditService audit;

    public ClubJoinFormService(CommunityService communities, ClubJoinQuestionRepository questions,
                               ClubJoinAnswerRepository answers, CommunityMemberRepository members,
                               ClubPermissions permissions, ClubAuditService audit) {
        this.communities = communities;
        this.questions = questions;
        this.answers = answers;
        this.members = members;
        this.permissions = permissions;
        this.audit = audit;
    }

    /** Basvuru formu sorulari: ACTIVE kulupte herkes (basvuran gormeli); diger durumlarda 404. */
    @Transactional(readOnly = true)
    public List<QuestionView> questionsOf(Actor a, Long cid) {
        communities.loadVisible(a, cid);
        return questions.findByCommunityIdOrderBySortOrderAsc(cid).stream()
                .map(q -> new QuestionView(q.getId(), q.getQuestion())).toList();
    }

    /** EDIT_INFO: formu degistirir. Var olan siralar yerinde guncellenir (bekleyen yanitlar korunur), fazlalar silinir. */
    @Transactional
    public List<QuestionView> setQuestions(Actor a, Long cid, List<String> raw) {
        communities.load(cid);
        permissions.require(a, cid, ClubPermission.EDIT_INFO);
        List<String> texts = new ArrayList<>();
        for (String s : raw == null ? List.<String>of() : raw) {
            String t = s == null ? "" : s.trim();
            if (t.length() < MIN_QUESTION_LEN || t.length() > 200) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Soru 3-200 karakter olmalı.");
            }
            texts.add(t);
        }
        if (texts.size() > MAX_QUESTIONS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "QUESTION_LIMIT",
                    "En fazla " + MAX_QUESTIONS + " katılım sorusu eklenebilir.", String.valueOf(MAX_QUESTIONS));
        }
        List<ClubJoinQuestion> current = questions.findByCommunityIdOrderBySortOrderAsc(cid);
        for (int i = 0; i < texts.size(); i++) {
            ClubJoinQuestion q = i < current.size() ? current.get(i) : new ClubJoinQuestion();
            q.setCommunityId(cid);
            q.setSortOrder(i);
            q.setQuestion(texts.get(i));
            questions.save(q);
        }
        if (current.size() > texts.size()) {
            questions.deleteAll(current.subList(texts.size(), current.size())); // yanitlar FK cascade ile gider
        }
        audit.record(cid, a.id(), null, ClubAuditService.JOIN_QUESTIONS_SET, "count=" + texts.size());
        return questions.findByCommunityIdOrderBySortOrderAsc(cid).stream()
                .map(q -> new QuestionView(q.getId(), q.getQuestion())).toList();
    }

    /**
     * Katilma istegi: onay gerektiren kulupte soru varsa HEPSI yanitlanmalidir (once dogrulanir, boylece eksik
     * yanitla yan etki - bildirim, uyelik satiri - olusmaz). Sonra mevcut katilim akisi calisir; istek BEKLEMEYE
     * dustuyse yanitlar kaydedilir.
     * @return ACTIVE | PENDING
     */
    @Transactional
    public String join(Actor a, Long cid, List<AnswerInput> given) {
        Community c = communities.load(cid);
        List<ClubJoinQuestion> qs = c.getStatus() == Community.Status.ACTIVE && !CommunityService.isOpenJoin(c)
                ? questions.findByCommunityIdOrderBySortOrderAsc(cid) : List.of();
        Map<Long, String> clean = qs.isEmpty() ? Map.of() : validate(qs, given);
        String status = communities.join(a, cid);
        if (!clean.isEmpty() && "PENDING".equals(status)) {
            answers.deleteMember(cid, a.id());
            for (Map.Entry<Long, String> e : clean.entrySet()) {
                ClubJoinAnswer ans = new ClubJoinAnswer();
                ans.setCommunityId(cid);
                ans.setQuestionId(e.getKey());
                ans.setUserId(a.id());
                ans.setAnswer(e.getValue());
                answers.save(ans);
            }
        }
        return status;
    }

    /** MANAGE_MEMBERS: bir basvuranin yanitlari. Uyelik kaydi yoksa 404 (baskasinin verisi sizmaz). */
    @Transactional(readOnly = true)
    public List<AnswerView> answersOf(Actor a, Long cid, Long userId) {
        communities.load(cid);
        permissions.require(a, cid, ClubPermission.MANAGE_MEMBERS);
        CommunityMember m = members.findByCommunityIdAndUserId(cid, userId).orElse(null);
        if (m == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "REQUEST_NOT_FOUND", "Bekleyen istek bulunamadı.");
        }
        Map<Long, ClubJoinQuestion> byId = new HashMap<>();
        questions.findByCommunityIdOrderBySortOrderAsc(cid).forEach(q -> byId.put(q.getId(), q));
        return answers.findByCommunityIdAndUserId(cid, userId).stream()
                .filter(x -> byId.containsKey(x.getQuestionId()))
                .sorted((x, y) -> Integer.compare(byId.get(x.getQuestionId()).getSortOrder(),
                        byId.get(y.getQuestionId()).getSortOrder()))
                .map(x -> new AnswerView(x.getQuestionId(), byId.get(x.getQuestionId()).getQuestion(), x.getAnswer(),
                        x.getCreatedAt())).toList();
    }

    /** Her soru tam bir kez ve bos olmayan bir yanitla yanitlanmali; bilinmeyen soru kimligi reddedilir. */
    static Map<Long, String> validate(List<ClubJoinQuestion> qs, List<AnswerInput> given) {
        Map<Long, String> byQuestion = new HashMap<>();
        for (AnswerInput in : given == null ? List.<AnswerInput>of() : given) {
            String t = in.answer() == null ? "" : in.answer().trim();
            if (t.length() > MAX_ANSWER_LEN) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Yanıt en fazla 500 karakter olabilir.");
            }
            byQuestion.put(in.questionId(), t);
        }
        Map<Long, String> out = new LinkedHashMap<>();
        for (ClubJoinQuestion q : qs) {
            String t = byQuestion.remove(q.getId());
            if (t == null || t.isEmpty()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "ANSWERS_REQUIRED",
                        "Katılım sorularının tümünü yanıtlamalısınız.");
            }
            out.put(q.getId(), t);
        }
        if (!byQuestion.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Bilinmeyen soru.");
        }
        return out;
    }
}
