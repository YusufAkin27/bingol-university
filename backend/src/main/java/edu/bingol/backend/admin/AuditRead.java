package edu.bingol.backend.admin;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Kisisel veri OKUYAN yonetici GET ucunu isaretler: istek denetim kaydina yazilir (sebep zorunlu degildir; kayit zorunludur).
 * Sinif ya da metod uzerinde kullanilir. Genel okuma/liste uclarina KONMAZ (kayit seli olur).
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.TYPE})
public @interface AuditRead {}
