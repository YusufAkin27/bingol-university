package edu.bingol.backend.admin;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Bu yonetici ucu SEBEP ister (basliktan `X-Admin-Reason`, govdeden `reason` ya da GET'te `reason` sorgu parametresi).
 * `app.admin.require-reason=false` iken zorlanmaz. `min` en kisa sebep uzunlugudur.
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.TYPE})
public @interface AdminReasonRequired {

    int min() default AdminGuardPolicy.DEFAULT_MIN_REASON;
}
