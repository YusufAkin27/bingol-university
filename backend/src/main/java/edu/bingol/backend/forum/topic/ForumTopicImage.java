package edu.bingol.backend.forum.topic;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/** Konu-gorsel baglantisi (forum_media satiri bir konuya en cok bir kez baglanir). */
@Entity
@Table(name = "forum_topic_image", uniqueConstraints = @UniqueConstraint(name = "fa14_timg_media_uq", columnNames = "media_id"))
@Getter
@Setter
public class ForumTopicImage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long topicId;

    @Column(nullable = false)
    private Long mediaId;

    @Column(nullable = false)
    private short position;
}
