package edu.bingol.backend.event.admission;

import org.springframework.data.jpa.repository.JpaRepository;

public interface EventAdmissionRepository extends JpaRepository<EventAdmission, Long> {
}
