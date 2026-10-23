package edu.bingol.backend.status;

import org.springframework.data.jpa.repository.JpaRepository;

public interface SyncStatusRepository extends JpaRepository<SyncStatus, String> {
}
