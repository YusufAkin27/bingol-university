package edu.bingol.backend.community.permissions;

import edu.bingol.backend.community.CommunityMember.Role;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.Set;

/** Kulup yetki/devir/davet uclarinin istek-yanit kayitlari. */
public final class ClubDtos {

    private ClubDtos() {}

    /** Hepsi opsiyonel ama en az biri gerekli. template verilirse rol ve yetkiler sablondan gelir; permissions ozel kume. */
    public record AccessRequest(Role role, String template, List<String> permissions) {
    }

    public record AccessView(Long userId, Role role, Set<ClubPermission> permissions, String template, boolean custom) {
    }

    public record MyAccessView(Role role, Set<ClubPermission> permissions) {
    }

    public record TemplateView(String name, Role role, Set<ClubPermission> permissions) {
    }

    public record TransferRequest(@NotNull Long targetUserId, boolean keepAsAdmin, boolean confirmIrreversible) {
    }

    public record TransferDecision(boolean confirmIrreversible) {
    }

    public record TransferView(Long id, Long communityId, Long fromUserId, String fromName, Long toUserId,
                               String toName, boolean keepAsAdmin, String status, Instant createdAt, Instant expiresAt) {
    }

    /** Sureler saat; bos birakilirsa varsayilan 168 (7 gun), en fazla 720. maxUses bos = sinirsiz. */
    public record InviteRequest(@Min(1) @Max(1000) Integer maxUses, @Min(1) @Max(720) Integer validHours) {
    }

    /** code yalnizca olusturma yanitinda doner. */
    public record InviteCreated(Long id, String code, Integer maxUses, Instant expiresAt) {
    }

    public record InviteView(Long id, String codeHint, Long createdBy, Integer maxUses, int usedCount, Instant expiresAt,
                             boolean revoked, String state) {
    }

    public record JoinByCodeRequest(@NotNull @jakarta.validation.constraints.Size(min = 4, max = 32) String code) {
    }

    public record JoinByCodeResult(Long communityId, String status) {
    }

    public record AuditView(Long id, String action, Long actorId, String actorName, Long targetUserId,
                            String targetName, String detail, Instant createdAt) {
    }
}
