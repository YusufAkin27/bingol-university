package edu.bingol.backend.profile;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DisplayNameChangeRepository extends JpaRepository<DisplayNameChange, Long> {

    Optional<DisplayNameChange> findFirstByUserIdOrderByChangedAtDesc(Long userId);

    /** KVKK disa aktarim: kullanicinin kendi ad degisiklikleri. */
    List<DisplayNameChange> findTop50ByUserIdOrderByChangedAtDesc(Long userId);

    @Modifying
    @Query("DELETE FROM DisplayNameChange c WHERE c.userId = :uid")
    int deleteByUser(@Param("uid") Long userId);
}
