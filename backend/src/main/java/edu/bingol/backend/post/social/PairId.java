package edu.bingol.backend.post.social;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** Iki kimlikli bilesik anahtar (sutun adlari, kullanan varlikta AttributeOverride ile verilir). */
@Embeddable
@Getter
@NoArgsConstructor
public class PairId implements Serializable {

    @Column(name = "a", nullable = false)
    private Long a;

    @Column(name = "b", nullable = false)
    private Long b;

    public PairId(Long a, Long b) {
        this.a = a;
        this.b = b;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof PairId k && Objects.equals(a, k.a) && Objects.equals(b, k.b);
    }

    @Override
    public int hashCode() {
        return Objects.hash(a, b);
    }
}
