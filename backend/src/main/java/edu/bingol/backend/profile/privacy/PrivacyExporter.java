package edu.bingol.backend.profile.privacy;

import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.profile.privacy.PrivacyDtos.PrivacyView;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** KVKK disa aktarim: profil gizlilik ayarlari (avatar moderasyon bayragi dahil). */
@Configuration
public class PrivacyExporter {

    @Bean
    DataExporter profilePrivacyExporter(PrivacyService privacy) {
        return DataExporter.of("profilePrivacy", uid -> PrivacyView.of(privacy.get(uid)));
    }
}
