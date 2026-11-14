package edu.bingol.backend.academician;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.academician.*`: akademisyen alani. autoApprove STAFF_PATTERN (ad-soyad kalibli kurumsal adres otomatik onay) ya da
 * NEVER (hepsi yonetici onayi); sessionTtl yoklama oturumu suresi.
 */
@ConfigurationProperties("app.academician")
public record AcademicianProperties(@DefaultValue("STAFF_PATTERN") AutoApprove autoApprove,
                                    @DefaultValue("3h") Duration sessionTtl,
                                    @DefaultValue("500") int courseStorageCapMb,
                                    @DefaultValue("200") int pendingScanCap,
                                    @DefaultValue("4") int percentMinSessions,
                                    @DefaultValue("2000") int ownerStorageCapMb,
                                    @DefaultValue("60") int maxCourses) {

    public enum AutoApprove { STAFF_PATTERN, NEVER }
}
