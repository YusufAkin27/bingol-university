package edu.bingol.backend.poll;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/** Anket. Sayaclar (voterCount, secenek sayaclari) yalniz atomik SQL ile guncellenir (PollVoteService). */
@Entity
@Table(name = "poll", uniqueConstraints = @UniqueConstraint(name = "pol330_menu_day_entity_uq", columnNames = "menuDate"))
@Getter
@Setter
public class Poll {

    public enum Type { SINGLE, MULTI, RATING, RANKED }

    public enum Scope { GLOBAL, COMMUNITY, MENU }

    public enum Status { DRAFT, OPEN, CLOSED, CANCELLED }

    public enum ShowResults { ALWAYS, AFTER_VOTE, AFTER_CLOSE }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String title;

    @Column(length = 1000)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private Type type = Type.SINGLE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Scope scope = Scope.GLOBAL;

    private Long communityId;

    /** MENU kapsaminda yemek listesi gunu; bir gun icin tek anket. */
    private LocalDate menuDate;

    /** Olusturan; otomatik menu anketinde ve hesap silinince null. */
    private Long createdBy;

    private boolean anonymous;

    private boolean allowChangeVote = true;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private ShowResults showResults = ShowResults.ALWAYS;

    @Column(nullable = false)
    private short maxChoices = 1;

    private boolean notify;

    @Column(nullable = false)
    private Instant opensAt = Instant.now();

    private Instant closesAt;

    @Column(length = 120)
    private String audienceFaculty;

    @Column(length = 120)
    private String audienceDepartment;

    @Column(length = 8)
    private String audienceGrade;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private Status status = Status.OPEN;

    /** Oy kullanan kisi sayisi (atomik artar/azalir). */
    @Column(nullable = false, updatable = false)
    private int voterCount;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    private Instant closedAt;

    private Instant openedNotifiedAt;

    private Instant closingNotifiedAt;

    public boolean hasAudience() {
        return audienceFaculty != null || audienceDepartment != null || audienceGrade != null;
    }

    /** Sureye bakmadan: kapanmis ya da iptal. */
    public boolean isFinished() {
        return status == Status.CLOSED || status == Status.CANCELLED;
    }

    /** Kapanis zamani gecmis mi (isleyici henuz CLOSED yapmamis olabilir). */
    public boolean isExpired(Instant now) {
        return closesAt != null && !closesAt.isAfter(now);
    }

    /** Sonuc acisindan kapali: durum bitmis ya da sure dolmus. */
    public boolean isClosedAt(Instant now) {
        return isFinished() || (status == Status.OPEN && isExpired(now));
    }

    /** Oy verilebilir pencerede mi (durum OPEN, acilmis, kapanmamis). */
    public boolean isVotingOpen(Instant now) {
        return status == Status.OPEN && !opensAt.isAfter(now) && !isExpired(now);
    }
}
