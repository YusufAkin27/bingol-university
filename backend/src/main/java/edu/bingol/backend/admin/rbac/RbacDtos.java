package edu.bingol.backend.admin.rbac;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

/** Yonetici rol/izin matrisi (P16) istek ve yanit kayitlari. */
public final class RbacDtos {

    private RbacDtos() {}

    /** Giris yapmis yoneticinin profili ve izinleri; `userId` Basic auth yoneticisinde null. */
    public record Me(Long userId, String email, String displayName, AdminProfile profile, boolean pinned,
                     List<String> permissions) {}

    public record MatrixEntry(String permission, List<AdminProfile> profiles) {}

    /** Salt okunur matris: profil listesi + her iznin hangi profillerde oldugu. */
    public record Matrix(List<AdminProfile> profiles, List<MatrixEntry> entries) {}

    public record AdminRow(Long id, String email, String displayName, AdminProfile profile, boolean pinned,
                           String status, String lastSeenAt) {}

    public record ProfileRequest(@NotNull AdminProfile profile, @NotNull @Size(min = 5, max = 300) String reason) {}

    public record ProposeRequest(@NotNull Long userId, @NotNull AdminProfile profile,
                                 @NotNull @Size(min = 5, max = 300) String reason) {}

    /** Onay/ret notu (istege bagli). */
    public record DecisionRequest(@Size(max = 300) String note) {}

    public record ChangeView(Long id, Long targetUserId, String targetEmail, String targetName,
                             AdminProfile fromProfile, AdminProfile toProfile, String reason, Long proposedBy,
                             String proposedByEmail, String proposedAt, String expiresAt, String status,
                             Long decidedBy, String decidedAt, String decisionNote) {}
}
