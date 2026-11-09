package edu.bingol.backend.community;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** Kulup onerisi hedefi: bir fakulte ya da bolum (kanonik Turkce ad). Yalniz oneri siralamasi icin. */
@Entity
@Table(name = "community_audience")
@Getter
@Setter
public class CommunityAudience {

    public static final String FACULTY = "FACULTY";
    public static final String DEPARTMENT = "DEPARTMENT";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "community_id", nullable = false)
    private Long communityId;

    @Column(nullable = false, length = 12)
    private String kind;

    @Column(name = "target_value", nullable = false, length = 120)
    private String targetValue;

    public CommunityAudience() {}

    public CommunityAudience(Long communityId, String kind, String value) {
        this.communityId = communityId;
        this.kind = kind;
        this.targetValue = value;
    }
}
