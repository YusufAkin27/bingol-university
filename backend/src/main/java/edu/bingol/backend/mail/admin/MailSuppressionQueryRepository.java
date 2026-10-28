package edu.bingol.backend.mail.admin;

import edu.bingol.backend.mail.MailSuppression;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

/** Yonetici bastirma listesi sorgulari (P13): suzgecli sayfa, ozet ile arama. Yazma yolu {@code MailSuppressionService}'tedir. */
public interface MailSuppressionQueryRepository
        extends JpaRepository<MailSuppression, Long>, JpaSpecificationExecutor<MailSuppression> {

    Optional<MailSuppression> findByEmailHash(String emailHash);

}
