package edu.bingol.backend.academic;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.SmartInitializingSingleton;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Testlerde Flyway kapali ve sema JPA varliklarindan uretilir; akademik modul duz SQL kullandigindan V320 migration'i
 * H2'ye uyarlanip (TIMESTAMPTZ, now()) burada uygulanir. Bu sayede migration metni de dolayli olarak sinanir.
 */
@Configuration
public class AcademicTestSchema {

    private static final Logger log = LoggerFactory.getLogger(AcademicTestSchema.class);

    @Bean
    SmartInitializingSingleton academicSchema(JdbcTemplate jdbc) {
        return () -> {
            try {
                String sql = new String(new ClassPathResource("db/migration/V320__academic.sql").getInputStream().readAllBytes(),
                        StandardCharsets.UTF_8)
                        .replace("TIMESTAMPTZ", "TIMESTAMP WITH TIME ZONE").replace("now()", "CURRENT_TIMESTAMP");
                for (String stmt : sql.replaceAll("(?m)^--.*$", "").split(";")) {
                    String s = stmt.replaceAll("(?m)^--.*$", "").strip();
                    if (!s.isEmpty()) {
                        try {
                            jdbc.execute(s);
                        } catch (RuntimeException e) {
                            log.warn("academic test schema: {}", e.getMessage());
                        }
                    }
                }
            } catch (IOException e) {
                throw new IllegalStateException(e);
            }
        };
    }
}
