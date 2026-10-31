package edu.bingol.backend.admin.pii;

import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import org.springframework.core.MethodParameter;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.mvc.method.annotation.ResponseBodyAdvice;
import tools.jackson.databind.json.JsonMapper;

/**
 * T-018 ikinci savunma hatti: `users.pii` izni olmayan yonetici profilleri (SUPPORT, EDITOR, VIEWER) icin
 * `/api/admin/**` JSON yanitlarindaki e-posta adreslerini ve IP/cihaz alanlarini, hangi uctan geldigine bakmadan
 * maskeler. Birincil maskeleme DTO fabrikalarindadir; bu katman yeni eklenen ya da serbest metne gomulu kalintilari
 * yakalar. Yalniz maskesiz profiller icin calisir (FULL/MODERATOR yolu degismez, ek maliyet yok). CSV/akis yanitlari
 * JSON olmadigindan burada degil, ilgili disa aktarma servislerinde maskelenir.
 */
@RestControllerAdvice
public class AdminPiiResponseAdvice implements ResponseBodyAdvice<Object> {

    private static final String ADMIN_PREFIX = "/api/admin/";

    private final JsonMapper mapper;

    public AdminPiiResponseAdvice(JsonMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    public boolean supports(MethodParameter returnType, Class<? extends HttpMessageConverter<?>> converterType) {
        return true;
    }

    @Override
    public Object beforeBodyWrite(Object body, MethodParameter returnType, MediaType selectedContentType,
                                  Class<? extends HttpMessageConverter<?>> selectedConverterType,
                                  ServerHttpRequest request, ServerHttpResponse response) {
        if (body == null || body instanceof String || body instanceof byte[] || body instanceof Resource
                || !isJson(selectedContentType) || !request.getURI().getPath().startsWith(ADMIN_PREFIX)
                || PermissionAwareMasking.canSeePii()) {
            return body;
        }
        try {
            Object plain = mapper.convertValue(body, Object.class);
            return PiiScrubber.scrub(plain);
        } catch (RuntimeException e) {
            // fail-closed: temizlenemeyen yanit maskesiz gitmesin
            throw new IllegalStateException("Yonetici yaniti kisisel veri temizligi basarisiz", e);
        }
    }

    private static boolean isJson(MediaType t) {
        return t != null && (t.isCompatibleWith(MediaType.APPLICATION_JSON) || t.getSubtype().endsWith("+json"));
    }
}
