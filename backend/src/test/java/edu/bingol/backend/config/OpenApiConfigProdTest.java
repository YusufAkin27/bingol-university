package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import io.swagger.v3.core.converter.ModelConverter;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

/**
 * Regresyon (REL1 geri yukleme provasi): prod profilinde springdoc.api-docs.enabled=false iken springdoc
 * ObjectMapperProvider bean'ini uretmez; OpenApiConfig buna kosulsuz bagli olursa uygulama HIC acilmaz.
 */
class OpenApiConfigProdTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner().withUserConfiguration(OpenApiConfig.class);

    @Test
    void apiDocsKapaliykenBaglamAcilir() {
        runner.withPropertyValues("springdoc.api-docs.enabled=false").run(ctx -> {
            assertThat(ctx).hasNotFailed();
            assertThat(ctx).doesNotHaveBean(ModelConverter.class);
        });
    }
}
