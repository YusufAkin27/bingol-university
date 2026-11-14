package edu.bingol.backend.academician;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Akademisyen basvurusu/profili (V1900). Rol eklenmez: app_user + bu satir; kimlik user_id'dir. */
@Entity
@Table(name = "academician")
@Getter
@Setter
public class Academician {

    public enum Status { PENDING, APPROVED, REJECTED, REVOKED }

    public enum ApprovalMode { AUTO, ADMIN }

    @Id
    private Long userId;

    @Column(nullable = false, length = 40)
    private String title;

    @Column(nullable = false, length = 60)
    private String firstName;

    @Column(nullable = false, length = 60)
    private String lastName;

    @Column(length = 160)
    private String unit;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status;

    @Enumerated(EnumType.STRING)
    @Column(length = 8)
    private ApprovalMode approvalMode;

    private Long reviewedBy;

    private Instant reviewedAt;

    @Column(length = 300)
    private String rejectReason;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public String fullName() {
        return (title + " " + firstName + " " + lastName).trim();
    }
}
