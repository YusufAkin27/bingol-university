package edu.bingol.backend.community.extras;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.dto.CommunityDtos.CommunityView;
import edu.bingol.backend.community.dto.CommunityDtos.MemberView;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnnouncementRequest;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnnouncementView;
import edu.bingol.backend.community.extras.ClubExtrasDtos.AnswerView;
import edu.bingol.backend.community.extras.ClubExtrasDtos.ChatRoomView;
import edu.bingol.backend.community.extras.ClubExtrasDtos.ClosedRequest;
import edu.bingol.backend.community.extras.ClubExtrasDtos.ClubStats;
import edu.bingol.backend.community.extras.ClubExtrasDtos.QuestionView;
import edu.bingol.backend.community.extras.ClubExtrasDtos.QuestionsRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Kulup ekstralari (T15) uclari: yalnizca HTTP eslemesi + rate limit; kurallar servislerde. */
@RestController
@RequestMapping("/api/communities/{id}")
public class ClubExtrasController {

    private final CommunityService communities;
    private final ClubAnnouncementService announcements;
    private final ClubJoinFormService joinForm;
    private final ClubChatRoomService chatRoom;
    private final ClubMemberSearchService search;
    private final ClubStatsService stats;
    private final RateLimiter limiter;

    public ClubExtrasController(CommunityService communities, ClubAnnouncementService announcements,
                                ClubJoinFormService joinForm, ClubChatRoomService chatRoom,
                                ClubMemberSearchService search, ClubStatsService stats, RateLimiter limiter) {
        this.communities = communities;
        this.announcements = announcements;
        this.joinForm = joinForm;
        this.chatRoom = chatRoom;
        this.search = search;
        this.stats = stats;
        this.limiter = limiter;
    }

    // ---- logo ----

    /** multipart alani "file"; jpg/png/webp, T1 hattinda sikistirilir. */
    @PostMapping("/logo")
    public CommunityView setLogo(@PathVariable Long id, @RequestParam("file") MultipartFile file) {
        Actor a = Actor.current();
        limiter.check("community-logo:user:" + a.id(), 10, Duration.ofHours(1));
        return communities.setLogo(a, id, file);
    }

    @DeleteMapping("/logo")
    public CommunityView removeLogo(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        return communities.removeLogo(a, id);
    }

    // ---- duyurular ----

    @PostMapping("/announcements")
    @ResponseStatus(HttpStatus.CREATED)
    public AnnouncementView announce(@PathVariable Long id, @Valid @RequestBody AnnouncementRequest r) {
        Actor a = Actor.current();
        limiter.check("community-announce:user:" + a.id(), 10, Duration.ofHours(1));
        return announcements.create(a, id, r.text());
    }

    @GetMapping("/announcements")
    public CursorPage<AnnouncementView> announcements(@PathVariable Long id,
                                                      @RequestParam(required = false) Long cursor,
                                                      @RequestParam(defaultValue = "20") int size) {
        return announcements.list(Actor.current(), id, cursor, size);
    }

    // ---- katilim sorulari ----

    @GetMapping("/join-questions")
    public List<QuestionView> questions(@PathVariable Long id) {
        return joinForm.questionsOf(Actor.current(), id);
    }

    @PutMapping("/join-questions")
    public List<QuestionView> setQuestions(@PathVariable Long id, @Valid @RequestBody QuestionsRequest r) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        return joinForm.setQuestions(a, id, r.questions());
    }

    /** Basvuranin yanitlari: yalnizca uye yonetimi yetkilileri. */
    @GetMapping("/requests/{userId}/answers")
    public List<AnswerView> answers(@PathVariable Long id, @PathVariable Long userId) {
        Actor a = Actor.current();
        limiter.check("community-answers:user:" + a.id(), 120, Duration.ofHours(1));
        return joinForm.answersOf(a, id, userId);
    }

    // ---- sohbet odasi ----

    @GetMapping("/chat-room")
    public ChatRoomView room(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("community-chatroom:user:" + a.id(), 120, Duration.ofHours(1));
        return chatRoom.get(a, id);
    }

    @PostMapping({"/chat-room/join", "/chat/join"})
    public ChatRoomView joinRoom(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("community-chatroom-join:user:" + a.id(), 30, Duration.ofHours(1));
        return chatRoom.join(a, id);
    }

    @PutMapping("/chat-room/closed")
    public ChatRoomView closeRoom(@PathVariable Long id, @Valid @RequestBody ClosedRequest r) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        return chatRoom.setClosed(a, id, r.closed());
    }

    // ---- uye arama / istatistik ----

    /** q: ad icinde arama; role: MEMBER|MODERATOR|ADMIN|OWNER; status: ACTIVE (varsayilan)|PENDING|BANNED. */
    @GetMapping("/members/search")
    public CursorPage<MemberView> searchMembers(@PathVariable Long id, @RequestParam(required = false) String q,
                                                @RequestParam(required = false) String role,
                                                @RequestParam(required = false) String status,
                                                @RequestParam(required = false) Long cursor,
                                                @RequestParam(defaultValue = "20") int size) {
        Actor a = Actor.current();
        limiter.check("community-member-search:user:" + a.id(), 120, Duration.ofMinutes(10));
        return search.search(a, id, q, role, status, cursor, size);
    }

    @GetMapping("/stats")
    public ClubStats clubStats(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("community-stats:user:" + a.id(), 60, Duration.ofMinutes(10));
        return stats.stats(a, id);
    }
}
