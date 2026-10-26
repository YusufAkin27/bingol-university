package edu.bingol.backend.community;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.dto.CommunityDtos.CommunityView;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.community.dto.CommunityDtos.CreatePostRequest;
import edu.bingol.backend.community.dto.CommunityDtos.JoinResult;
import edu.bingol.backend.community.dto.CommunityDtos.MemberView;
import edu.bingol.backend.community.dto.CommunityDtos.PostView;
import edu.bingol.backend.community.dto.CommunityDtos.RoleRequest;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.community.dto.CommunityDtos.UploadResult;
import edu.bingol.backend.community.permissions.ClubDtos.AccessRequest;
import edu.bingol.backend.community.permissions.ClubRoleService;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Topluluk uclari. Yalnizca HTTP eslemesi ve rate limit; kurallar CommunityService / CommunityPostService'te. */
@RestController
@RequestMapping("/api")
public class CommunityController {

    private final CommunityService communities;
    private final CommunityPostService posts;
    private final RateLimiter limiter;
    private final ClubRoleService roles;

    public CommunityController(CommunityService communities, CommunityPostService posts, RateLimiter limiter,
                               ClubRoleService roles) {
        this.roles = roles;
        this.communities = communities;
        this.posts = posts;
        this.limiter = limiter;
    }

    /** Onay bekleyen topluluk olusturur (202). */
    @PostMapping("/communities")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public CommunityView create(@Valid @RequestBody CreateCommunityRequest r) {
        Actor a = Actor.current();
        limiter.check("community-create:user:" + a.id(), 5, Duration.ofHours(1));
        Community c = communities.create(a, r);
        return communities.get(a, c.getId());
    }

    @GetMapping("/communities")
    public CursorPage<CommunityView> discover(@RequestParam(required = false) String category,
                                              @RequestParam(required = false) String q,
                                              @RequestParam(required = false) Long cursor,
                                              @RequestParam(defaultValue = "20") int size) {
        return communities.discover(Actor.current(), category, q, cursor, size);
    }

    @GetMapping("/communities/{id}")
    public CommunityView get(@PathVariable Long id) {
        return communities.get(Actor.current(), id);
    }

    @PatchMapping("/communities/{id}")
    public CommunityView update(@PathVariable Long id, @Valid @RequestBody UpdateCommunityRequest r) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        return communities.update(a, id, r);
    }

    /** multipart alani "file", jpg/png/webp, en fazla 3 MB. */
    @PostMapping("/communities/{id}/cover")
    public CommunityView cover(@PathVariable Long id, @RequestParam("file") MultipartFile file) {
        Actor a = Actor.current();
        limiter.check("community-cover:user:" + a.id(), 10, Duration.ofHours(1));
        return communities.setCover(a, id, file);
    }

    @PostMapping("/communities/{id}/join")
    public JoinResult join(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("community-join:user:" + a.id(), 20, Duration.ofHours(1));
        return new JoinResult(communities.join(a, id));
    }

    @DeleteMapping("/communities/{id}/membership")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        communities.leave(a, id);
    }

    @GetMapping("/communities/{id}/members")
    public CursorPage<MemberView> members(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                          @RequestParam(defaultValue = "20") int size) {
        return communities.members(Actor.current(), id, cursor, size);
    }

    @GetMapping("/communities/{id}/requests")
    public CursorPage<MemberView> requests(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                           @RequestParam(defaultValue = "20") int size) {
        return communities.requests(Actor.current(), id, cursor, size);
    }

    @PostMapping("/communities/{id}/requests/{userId}/approve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void approve(@PathVariable Long id, @PathVariable Long userId) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        communities.decide(a, id, userId, true);
    }

    @PostMapping("/communities/{id}/requests/{userId}/reject")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reject(@PathVariable Long id, @PathVariable Long userId) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        communities.decide(a, id, userId, false);
    }

    @PutMapping("/communities/{id}/members/{userId}/role")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void role(@PathVariable Long id, @PathVariable Long userId, @Valid @RequestBody RoleRequest r) {
        Actor a = Actor.current();
        limiter.check("club-perm:user:" + a.id(), 60, Duration.ofHours(1));
        // Rol atama = rolun varsayilan yetkileriyle ince yetki akisi (yukseltme korumalari orada).
        roles.setAccess(a, id, userId, new AccessRequest(r.role(), null, null));
    }

    /** ban=true ise kullanici yasaklanir ve yeniden katilamaz. */
    @DeleteMapping("/communities/{id}/members/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@PathVariable Long id, @PathVariable Long userId,
                       @RequestParam(defaultValue = "false") boolean ban) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        communities.remove(a, id, userId, ban);
    }

    @GetMapping("/communities/{id}/posts")
    public CursorPage<PostView> feed(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                     @RequestParam(defaultValue = "20") int size) {
        return posts.feed(Actor.current(), id, cursor, size);
    }

    @PostMapping("/communities/{id}/posts")
    @ResponseStatus(HttpStatus.CREATED)
    public PostView post(@PathVariable Long id, @Valid @RequestBody CreatePostRequest r) {
        Actor a = Actor.current();
        limiter.check("community-post:user:" + a.id(), 10, Duration.ofMinutes(1));
        return posts.create(a, id, r);
    }

    /** Yazi gorseli yukler; donen url yazi olustururken imageUrl olarak gonderilir. */
    @PostMapping("/communities/{id}/posts/upload")
    public UploadResult upload(@PathVariable Long id, @RequestParam("file") MultipartFile file) {
        Actor a = Actor.current();
        limiter.check("community-upload:user:" + a.id(), 20, Duration.ofHours(1));
        return new UploadResult(posts.uploadImage(a, id, file));
    }

    @DeleteMapping("/communities/{id}/posts/{postId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deletePost(@PathVariable Long id, @PathVariable Long postId) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        posts.delete(a, id, postId);
    }

    @PutMapping("/communities/{id}/posts/{postId}/pin")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void pin(@PathVariable Long id, @PathVariable Long postId) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        posts.pin(a, id, postId, true);
    }

    @DeleteMapping("/communities/{id}/posts/{postId}/pin")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unpin(@PathVariable Long id, @PathVariable Long postId) {
        Actor a = Actor.current();
        limiter.check("community-write:user:" + a.id(), 60, Duration.ofHours(1));
        posts.pin(a, id, postId, false);
    }

    @GetMapping("/me/communities")
    public CursorPage<CommunityView> mine(@RequestParam(required = false) Long cursor,
                                          @RequestParam(defaultValue = "20") int size) {
        return communities.mine(Actor.current(), cursor, size);
    }
}
