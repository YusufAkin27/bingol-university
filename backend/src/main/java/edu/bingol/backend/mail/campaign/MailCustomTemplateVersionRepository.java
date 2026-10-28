package edu.bingol.backend.mail.campaign;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MailCustomTemplateVersionRepository extends JpaRepository<MailCustomTemplateVersion, Long> {

    Optional<MailCustomTemplateVersion> findByTemplateIdAndVersion(Long templateId, int version);

    List<MailCustomTemplateVersion> findByTemplateIdOrderByVersionDesc(Long templateId);
}
