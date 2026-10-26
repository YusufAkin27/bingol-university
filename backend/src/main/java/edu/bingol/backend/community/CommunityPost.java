package edu.bingol.backend.community;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "community_post")
@Getter
@Setter
public class CommunityPost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long communityId;

    @Column(nullable = false)
    private Long authorId;

    /** Metin; sutun adi "content" (SQL'de "text" ayrilmis kelimeye yakin), API'de "text" olarak gorunur. */
    @Column(nullable = false, length = 2000)
    private String content;

    @Column(length = 300)
    private String imageUrl;

    private boolean pinned;

    /** Kulup duyurusu (T15): yetkili yazar, tum aktif uyelere bildirim gider, gunluk sinirli. */
    private boolean announcement;

    /** Yumusak silme (yazar/moderator silmesi veya rapor sonucu gizleme). */
    private boolean deleted;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
