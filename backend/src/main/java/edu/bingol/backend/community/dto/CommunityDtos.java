package edu.bingol.backend.community.dto;

import edu.bingol.backend.community.Community.JoinPolicy;
import edu.bingol.backend.community.Community.Status;
import edu.bingol.backend.community.Community.Visibility;
import edu.bingol.backend.community.CommunityMember.Role;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

/** Topluluk uclarinin istek/yanit kayitlari. */
public final class CommunityDtos {

    private CommunityDtos() {}

    public record CreateCommunityRequest(
            @NotBlank @Size(min = 3, max = 80) String name,
            @Size(max = 1000) String description,
            @Size(max = 40) String category,
            JoinPolicy joinPolicy,
            Visibility visibility) {
    }

    /** Alanlarin hepsi opsiyonel; verilenler guncellenir. */
    public record UpdateCommunityRequest(
            @Size(min = 3, max = 80) String name,
            @Size(max = 1000) String description,
            @Size(max = 40) String category,
            JoinPolicy joinPolicy,
            Visibility visibility) {
    }

    /** myStatus: NONE | ACTIVE | PENDING | BANNED; myRole: uye degilse null. */
    public record CommunityView(Long id, String name, String slug, String description, String category,
                                String coverUrl, JoinPolicy joinPolicy, Visibility visibility, Status status,
                                Long ownerId, long memberCount, String myStatus, Role myRole, Instant createdAt,
                                String logoUrl) {
    }

    public record JoinResult(String status) {
    }

    public record MemberView(Long userId, String displayName, String avatarUrl, Role role, Instant joinedAt) {
    }

    public record RoleRequest(@NotNull Role role) {
    }

    public record CreatePostRequest(@NotBlank @Size(max = 2000) String text, @Size(max = 300) String imageUrl) {
    }

    public record PostView(Long id, Long communityId, Long authorId, String authorName, String authorAvatarUrl,
                           String text, String imageUrl, boolean pinned, Instant createdAt, boolean canDelete) {
    }

    public record ReviewRequest(@Size(max = 300) String reason) {
    }

    public record UploadResult(String url) {
    }
}
