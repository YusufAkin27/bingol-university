package edu.bingol.backend.community.permissions;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.util.EnumSet;
import java.util.Set;
import lombok.Getter;
import lombok.Setter;

/**
 * Uyeye ozel yetki kumesi. Kayit YOKSA uyenin rolunun varsayilan yetkileri gecerlidir (geriye uyumluluk);
 * kayit VARSA rol varsayilanlarinin yerine gecer (bos kume = hicbir yetki).
 */
@Entity
@Table(name = "club_member_grant",
        uniqueConstraints = @UniqueConstraint(name = "uq_club_grant_member", columnNames = {"community_id", "user_id"}))
@Getter
@Setter
public class ClubMemberGrant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long communityId;

    @Column(nullable = false)
    private Long userId;

    /** Uygulanan hazir sablonun adi (bilgi amacli); ozel kumede null. */
    @Column(length = 32)
    private String template;

    /** Virgulle ayrilmis ClubPermission adlari; bos olabilir. */
    @Column(nullable = false, length = 200)
    private String permissions = "";

    private Long updatedBy;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public Set<ClubPermission> permissionSet() {
        Set<ClubPermission> s = EnumSet.noneOf(ClubPermission.class);
        for (String p : permissions.split(",")) {
            ClubPermission.parse(p).ifPresent(s::add);
        }
        return s;
    }

    public void setPermissionSet(Set<ClubPermission> set) {
        StringBuilder sb = new StringBuilder();
        for (ClubPermission p : EnumSet.copyOf(set.isEmpty() ? EnumSet.noneOf(ClubPermission.class) : set)) {
            sb.append(sb.length() == 0 ? "" : ",").append(p.name());
        }
        this.permissions = sb.toString();
    }
}
