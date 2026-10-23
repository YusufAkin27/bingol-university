package edu.bingol.backend.community;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.dto.CommunityDtos.CommunityView;
import edu.bingol.backend.community.dto.CommunityDtos.ReviewRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Topluluk onay uclari (/api/admin/** zaten SecurityConfig'te ROLE_ADMIN ister). */
@RestController
@RequestMapping("/api/admin/communities")
public class CommunityAdminController {

    private final CommunityService communities;

    public CommunityAdminController(CommunityService communities) {
        this.communities = communities;
    }

    /** Varsayilan: onay bekleyenler (id'ye gore azalan). */
    @GetMapping
    public CursorPage<CommunityView> list(@RequestParam(defaultValue = "PENDING_REVIEW") Community.Status status,
                                          @RequestParam(required = false) Long cursor,
                                          @RequestParam(defaultValue = "20") int size) {
        return communities.byStatus(status, cursor, size);
    }

    @PostMapping("/{id}/approve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void approve(@PathVariable Long id) {
        communities.review(id, true, null);
    }

    @PostMapping("/{id}/reject")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reject(@PathVariable Long id, @Valid @RequestBody(required = false) ReviewRequest r) {
        communities.review(id, false, r == null ? null : r.reason());
    }
}
