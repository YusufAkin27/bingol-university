package edu.bingol.backend.mail;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface MailSuppressionRepository extends JpaRepository<MailSuppression, Long> {

    boolean existsByEmailHash(String emailHash);

    @Transactional
    @Modifying
    @Query("DELETE FROM MailSuppression s WHERE s.emailHash = :hash")
    int deleteByHash(@Param("hash") String hash);
}
