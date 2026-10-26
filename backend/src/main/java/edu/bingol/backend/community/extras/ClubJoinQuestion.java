package edu.bingol.backend.community.extras;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/** Onayli/ozel kulubun basvuru formu sorusu (en fazla 3, sirali). */
@Entity
@Table(name = "club_join_question")
@Getter
@Setter
public class ClubJoinQuestion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long communityId;

    @Column(nullable = false)
    private int sortOrder;

    @Column(nullable = false, length = 200)
    private String question;
}
