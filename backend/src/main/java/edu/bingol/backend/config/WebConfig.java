package edu.bingol.backend.config;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.filter.ShallowEtagHeaderFilter;

/** Herkese acik okuma uclarina ETag ekler: icerik degismediyse mobil 304 alir, veri tasinmaz. */
@Configuration
public class WebConfig {

    @Bean
    FilterRegistrationBean<ShallowEtagHeaderFilter> etagFilter() {
        var reg = new FilterRegistrationBean<>(new ShallowEtagHeaderFilter());
        reg.addUrlPatterns("/api/news", "/api/news/*", "/api/menu", "/api/menu/*", "/api/status");
        return reg;
    }
}
