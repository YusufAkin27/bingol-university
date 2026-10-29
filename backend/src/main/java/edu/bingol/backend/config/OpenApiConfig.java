package edu.bingol.backend.config;

import io.swagger.v3.core.converter.ModelConverter;
import io.swagger.v3.core.jackson.ModelResolver;
import io.swagger.v3.core.jackson.TypeNameResolver;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.PathItem;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.media.ObjectSchema;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.media.StringSchema;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.List;
import java.util.Map;
import java.util.function.BiPredicate;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springdoc.core.models.GroupedOpenApi;
import org.springdoc.core.providers.ObjectMapperProvider;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.AntPathMatcher;

/**
 * OpenAPI (springdoc 3.x) tanimi: Bearer semasi, uc grup (herkese acik / kimlikli / yonetici).
 * Erisim: /v3/api-docs ve Swagger arayuzu SecurityConfig'te yalnizca ADMIN'e aciktir;
 * Swagger arayuzu varsayilan KAPALIDIR (yalnizca dev profili veya SWAGGER_UI_ENABLED=true).
 */
@Configuration
public class OpenApiConfig {

    private static final String BEARER = "bearerAuth";
    private static final String BASIC = "adminBasic";
    private static final AntPathMatcher MATCHER = new AntPathMatcher();

    /** SecurityConfig'teki permitAll kurallarinin aynasi (yontem, desen); kurallar degisirse burayi da guncelleyin. */
    private static final List<String[]> PUBLIC = List.of(
            new String[]{"GET", "/api/faq"}, new String[]{"GET", "/api/legal"}, new String[]{"GET", "/api/legal/*"},
            new String[]{"GET", "/api/legal/*/versions"}, new String[]{"GET", "/api/app/info"},
            new String[]{"GET", "/api/app/version"}, new String[]{"GET", "/api/faculties"}, new String[]{"GET", "/api/catalog/academic"},
            new String[]{"GET", "/api/catalog/departments"},
            new String[]{"*", "/api/auth/**"},
            new String[]{"GET", "/api/news"}, new String[]{"GET", "/api/news/**"},
            new String[]{"GET", "/api/menu"}, new String[]{"GET", "/api/menu/**"}, new String[]{"GET", "/api/status"},
            new String[]{"*", "/api/hello"}, new String[]{"*", "/files/**"});
    /** permitAll listesinde olsa da kimlik isteyen (SecurityConfig'te onceden yazilmis) uclar. */
    private static final List<String> AUTH_EXCEPTIONS = List.of("/api/auth/me");

    static boolean isAdmin(String path) {
        return path.startsWith("/api/admin/");
    }

    static boolean isPublic(String method, String path) {
        if (isAdmin(path) || AUTH_EXCEPTIONS.contains(path)) return false;
        for (String[] r : PUBLIC) {
            if (("*".equals(r[0]) || r[0].equals(method)) && MATCHER.match(r[1], path)) return true;
        }
        return false;
    }

    /**
     * Ayni basit ada sahip ic DTO'lar (ornegin iki ayri MemberView) tek semaya carpisip birini siliyordu.
     * Carpisan adlar ust sinif adiyla one eklenir (CommunityDtosMemberView); digerleri degismez.
     * springdoc.api-docs.enabled=false iken (prod varsayilani, OPENAPI_DOCS_ENABLED) springdoc ObjectMapperProvider bean'ini
     * olusturmaz; bean kosulsuz olursa uygulama prod profilinde HIC ACILMAZ (REL1 geri yukleme provasinda bulundu).
     */
    @Bean
    @ConditionalOnProperty(prefix = "springdoc.api-docs", name = "enabled", havingValue = "true", matchIfMissing = true)
    ModelConverter uniqueSchemaNames(ObjectMapperProvider mapper) {
        return new ModelResolver(mapper.jsonMapper(), new TypeNameResolver() {
            @Override
            protected String getNameOfClass(Class<?> cls) {
                String simple = cls.getSimpleName();
                if (COLLIDING.contains(simple) && cls.getEnclosingClass() != null) {
                    return cls.getEnclosingClass().getSimpleName() + simple;
                }
                return super.getNameOfClass(cls);
            }
        });
    }

    /** Birden fazla pakette bulunan DTO adlari (yeni cakisma olursa test: scripts/openapi-check.js belgesiz alan bulur). */
    private static final Set<String> COLLIDING = Set.of("MemberView", "RoleRequest");

    @Bean
    OpenAPI bingolOpenApi() {
        return new OpenAPI()
                .info(new Info().title("Bingol Universitesi API").version("1.0")
                        .description("Mobil ve web istemcileri icin REST uclari. Hata govdesi {code,message}; "
                                + "dil Accept-Language (tr|en|ar). WebSocket/STOMP /ws icin docs/MOBILE_API_GUIDE.md."))
                .components(new Components()
                        .addSecuritySchemes(BEARER, new SecurityScheme().type(SecurityScheme.Type.HTTP)
                                .scheme("bearer").bearerFormat("JWT")
                                .description("Access JWT (15 dk). /api/auth/login veya /refresh ile alinir."))
                        .addSecuritySchemes(BASIC, new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("basic")
                                .description("Yalnizca /api/admin/** ve betikler: admin:ADMIN_PASSWORD")));
    }

    /** Her islemin guvenlik gereksinimi ve ortak hata yanitlari (tum gruplar icin). */
    @Bean
    OpenApiCustomizer securityAndErrorsCustomizer() {
        return api -> {
            if (api.getComponents() == null) api.setComponents(new Components());
            api.getComponents().addSchemas("ApiError", apiErrorSchema());
            applyOps(api);
            nullableProperties(api);
        };
    }

    /**
     * Jackson null alanlari da yazar ve DTO'larda @NotNull yok; bu yuzden zorunlu (required) olmayan her
     * skaler/nesne alan belgede null olabilir diye isaretlenir (istemci null guvenligi icin dogru sozlesme).
     * Diziler (liste alanlari) null olmaz varsayilir; bu varsayim openapi-check.js ile dogrulanir.
     */
    @SuppressWarnings({"rawtypes", "unchecked"})
    private static void nullableProperties(OpenAPI api) {
        if (api.getComponents() == null || api.getComponents().getSchemas() == null) return;
        for (Schema root : api.getComponents().getSchemas().values()) nullifyChildren(root);
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    private static void nullifyChildren(Schema parent) {
        Map<String, Schema> props = parent.getProperties();
        if (props == null) return;
        List<String> required = parent.getRequired() == null ? List.of() : parent.getRequired();
        for (Map.Entry<String, Schema> e : new ArrayList<>(props.entrySet())) {
            Schema p = e.getValue();
            if (required.contains(e.getKey())) continue;
            if (p.get$ref() != null) {
                Schema nul = new Schema();
                nul.setTypes(new LinkedHashSet<>(List.of("null")));
                Schema wrap = new Schema();
                wrap.setAnyOf(List.of(p, nul));
                e.setValue(wrap);
            } else if (p.getTypes() != null && !p.getTypes().contains("null") && !p.getTypes().contains("array")) {
                Set<String> t = new LinkedHashSet<>(p.getTypes());
                t.add("null");
                p.setTypes(t);
                nullifyChildren(p);
            } else if (p.getTypes() == null && p.getType() != null && !"array".equals(p.getType())) {
                p.setTypes(new LinkedHashSet<>(List.of(p.getType(), "null")));
                nullifyChildren(p);
            }
            if (e.getValue() != p) props.put(e.getKey(), e.getValue());
            else props.put(e.getKey(), p);
        }
    }

    private static Schema<?> apiErrorSchema() {
        return new ObjectSchema()
                .addProperty("code", new StringSchema().example("VALIDATION_ERROR"))
                .addProperty("message", new StringSchema().description("Accept-Language dilinde kullaniciya gosterilebilir metin"))
                .description("Tum hata yanitlari bu bicimdedir.");
    }

    /** ResponseEntity ile calisma zamaninda secilen durum kodlari (springdoc yalniz 200 gorur): islem -> ek kodlar. */
    private static final Map<String, List<String>> EXTRA_STATUS = Map.of(
            "POST /api/events", List.of("201", "202"),
            "POST /api/conversations", List.of("201"),
            "POST /api/conversations/{id}/messages", List.of("201"));

    private static void applyOps(OpenAPI api) {
        forEachOp(api, (method, path, op) -> {
            multipartIfBinary(op);
            for (String code : EXTRA_STATUS.getOrDefault(method + " " + path, List.of())) {
                ApiResponse ok = op.getResponses().get("200");
                if (ok != null && !op.getResponses().containsKey(code)) op.getResponses().addApiResponse(code, ok);
            }
            if (isPublic(method, path)) {
                op.setSecurity(List.of()); // acikca: kimlik gerekmez
            } else if (isAdmin(path)) {
                op.setSecurity(List.of(new SecurityRequirement().addList(BEARER), new SecurityRequirement().addList(BASIC)));
                addIfAbsent(op, "403", errorResponse("ADMIN rolu gerekli"));
            } else {
                op.setSecurity(List.of(new SecurityRequirement().addList(BEARER)));
            }
            if (!isPublic(method, path) || !"GET".equals(method)) addIfAbsent(op, "401", errorResponse("Token yok/gecersiz/suresi dolmus"));
            if (!"GET".equals(method)) addIfAbsent(op, "429", errorResponse("RATE_LIMITED: istek siniri asildi"));
            addIfAbsent(op, "400", errorResponse("Dogrulama / is kurali hatasi (code alanina bakin)"));
        });
    }

    @Bean
    GroupedOpenApi publicGroup() {
        return group("1-public", "Herkese acik (kimlik gerekmez)", (m, p) -> isPublic(m, p));
    }

    @Bean
    GroupedOpenApi userGroup() {
        return group("2-authenticated", "Kimlikli kullanici (Bearer)", (m, p) -> !isPublic(m, p) && !isAdmin(p));
    }

    @Bean
    GroupedOpenApi adminGroup() {
        return group("3-admin", "Yonetici (ROLE_ADMIN)", (m, p) -> isAdmin(p));
    }

    private GroupedOpenApi group(String name, String desc, BiPredicate<String, String> keep) {
        return GroupedOpenApi.builder().group(name).displayName(desc)
                .pathsToMatch("/api/**", "/files/**")
                .addOpenApiCustomizer(api -> {
                    // kapsam disi islemleri at, bos kalan yollari sil
                    if (api.getPaths() == null) return;
                    List<String> drop = new ArrayList<>();
                    api.getPaths().forEach((path, item) -> {
                        item.readOperationsMap().forEach((hm, op) -> {
                            if (!keep.test(hm.name(), path)) removeOp(item, hm);
                        });
                        if (item.readOperationsMap().isEmpty()) drop.add(path);
                    });
                    drop.forEach(api.getPaths()::remove);
                }).build();
    }

    private static void removeOp(PathItem item, PathItem.HttpMethod m) {
        switch (m) {
            case GET -> item.setGet(null);
            case POST -> item.setPost(null);
            case PUT -> item.setPut(null);
            case DELETE -> item.setDelete(null);
            case PATCH -> item.setPatch(null);
            case HEAD -> item.setHead(null);
            case OPTIONS -> item.setOptions(null);
            case TRACE -> item.setTrace(null);
        }
    }

    private interface OpVisitor {
        void visit(String method, String path, Operation op);
    }

    private static void forEachOp(OpenAPI api, OpVisitor v) {
        if (api.getPaths() == null) return;
        for (Map.Entry<String, PathItem> e : api.getPaths().entrySet()) {
            for (Map.Entry<PathItem.HttpMethod, Operation> o : e.getValue().readOperationsMap().entrySet()) {
                Operation op = o.getValue();
                if (op.getResponses() == null) op.setResponses(new io.swagger.v3.oas.models.responses.ApiResponses());
                v.visit(o.getKey().name(), e.getKey(), op);
            }
        }
    }

    /** springdoc dosya yuklemelerini application/json diye yazabiliyor; binary alan varsa multipart/form-data yapar. */
    @SuppressWarnings("rawtypes")
    private static void multipartIfBinary(Operation op) {
        if (op.getRequestBody() == null || op.getRequestBody().getContent() == null) return;
        Content c = op.getRequestBody().getContent();
        MediaType json = c.get("application/json");
        if (json == null || json.getSchema() == null || json.getSchema().getProperties() == null) return;
        Map<String, Schema> props = json.getSchema().getProperties();
        boolean file = props.values().stream().anyMatch(p -> "binary".equals(p.getFormat()));
        if (file) {
            c.remove("application/json");
            c.addMediaType("multipart/form-data", json);
        }
    }

    private static void addIfAbsent(Operation op, String code, ApiResponse r) {
        if (!op.getResponses().containsKey(code)) op.getResponses().addApiResponse(code, r);
    }

    private static ApiResponse errorResponse(String desc) {
        return new ApiResponse().description(desc).content(new Content().addMediaType("application/json",
                new MediaType().schema(new Schema<>().$ref("#/components/schemas/ApiError"))));
    }
}
