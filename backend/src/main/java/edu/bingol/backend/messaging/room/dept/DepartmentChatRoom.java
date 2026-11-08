package edu.bingol.backend.messaging.room.dept;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Bolum sohbet odasinin kaynak kaydi; id, chat_room_link.ref_id olarak kullanilir. */
@Entity
@Table(name = "department_chat_room")
@Getter
@Setter
public class DepartmentChatRoom {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "dept_key", nullable = false, length = 200)
    private String deptKey;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
