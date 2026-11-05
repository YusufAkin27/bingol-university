package edu.bingol.backend.forum.topic;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** (konu, kullanici) basina kararli anonim takma ad numarasi ("Anonim #n"). */
@Entity
@Table(name = "forum_anon_alias", uniqueConstraints = @UniqueConstraint(name = "fa14_alias_n_uq", columnNames = {"topic_id", "n"}))
@Getter
@Setter
@NoArgsConstructor
public class ForumAnonAlias {

    @EmbeddedId
    private TopicUserId id;

    @Column(nullable = false)
    private int n;

    public ForumAnonAlias(Long topicId, Long userId, int n) {
        this.id = new TopicUserId(topicId, userId);
        this.n = n;
    }
}
