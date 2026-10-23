package edu.bingol.backend.i18n;

import java.util.List;
import java.util.Locale;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.LocaleResolver;
import org.springframework.web.servlet.i18n.AcceptHeaderLocaleResolver;

/** Istek dili: Accept-Language basligi; desteklenmeyen veya eksikse Turkce. */
@Configuration
public class I18nConfig {

    @Bean
    LocaleResolver localeResolver() {
        AcceptHeaderLocaleResolver r = new AcceptHeaderLocaleResolver();
        r.setSupportedLocales(List.of(Lang.TR.locale(), Lang.EN.locale(), Lang.AR.locale()));
        r.setDefaultLocale(Locale.forLanguageTag("tr"));
        return r;
    }
}
