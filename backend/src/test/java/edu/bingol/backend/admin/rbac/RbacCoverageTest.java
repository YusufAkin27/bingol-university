package edu.bingol.backend.admin.rbac;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

/**
 * KAPSAM TESTI (P16): kayitli HER /api/admin/** uc (yol x yontem) {@link AdminPermissionPolicy}'de ACIKCA bir izne
 * eslenmis olmali. Eslenmemis uc varsayilan olarak yalniz FULL'a acik kalir (guvenli) ama bu test basarisiz olur:
 * yeni admin ucu eklenince bilincli bir izin karari (politika kurali) zorunludur.
 */
@SpringBootTest
class RbacCoverageTest {

    @Autowired @Qualifier("requestMappingHandlerMapping") RequestMappingHandlerMapping mapping;

    @Test
    void everyAdminEndpointMapsToAKnownPermission() {
        List<String> unmapped = new ArrayList<>();
        List<String> unknownPerm = new ArrayList<>();
        Set<String> checked = new TreeSet<>();
        for (RequestMappingInfo info : mapping.getHandlerMethods().keySet()) {
            if (info.getPathPatternsCondition() == null) {
                continue;
            }
            Set<RequestMethod> methods = info.getMethodsCondition().getMethods();
            List<String> verbs = methods.isEmpty() ? List.of("GET", "POST", "PUT", "PATCH", "DELETE")
                    : methods.stream().map(Enum::name).toList();
            for (String pattern : info.getPathPatternsCondition().getPatternValues()) {
                if (!pattern.startsWith("/api/admin")) {
                    continue;
                }
                String sample = pattern.replaceAll("\\{[^}]*}", "1");
                for (String verb : verbs) {
                    checked.add(verb + " " + pattern);
                    var perm = AdminPermissionPolicy.explicit(verb, sample);
                    if (perm.isEmpty()) {
                        unmapped.add(verb + " " + pattern);
                    } else if (!PermissionMatrix.isKnown(perm.get())) {
                        unknownPerm.add(verb + " " + pattern + " -> " + perm.get());
                    }
                }
            }
        }
        assertThat(checked).as("admin uc sayisi (tarama calisiyor mu)").hasSizeGreaterThan(200);
        assertThat(unmapped).as("izne ESLENMEMIS admin uclari: AdminPermissionPolicy'ye kural ekleyin").isEmpty();
        assertThat(unknownPerm).as("PermissionMatrix'te olmayan izin").isEmpty();
    }

    /**
     * T-010: HER yonetici ucunun, harflerinden biri (ya da hepsi) yuzde-kodlanmis TUREV yollari (/%63onversations...) ayni
     * izin, gerekce ve denetim karariyla sonuclanmali; yoksa kodlu segment yetki atlatma yoludur.
     */
    @Test
    void percentEncodedVariantsGetTheSameDecisions() {
        int variants = 0;
        List<String> wrong = new ArrayList<>();
        for (RequestMappingInfo info : mapping.getHandlerMethods().keySet()) {
            if (info.getPathPatternsCondition() == null) {
                continue;
            }
            Set<RequestMethod> methods = info.getMethodsCondition().getMethods();
            List<String> verbs = methods.isEmpty() ? List.of("GET", "POST", "PUT", "PATCH", "DELETE")
                    : methods.stream().map(Enum::name).toList();
            for (String pattern : info.getPathPatternsCondition().getPatternValues()) {
                if (!pattern.startsWith("/api/admin")) {
                    continue;
                }
                String sample = pattern.replaceAll("\\{[^}]*}", "1");
                for (String verb : verbs) {
                    for (String v : encodedVariants(sample)) {
                        variants++;
                        String d = edu.bingol.backend.admin.AdminPaths.decode(v);
                        if (!d.equals(sample)
                                || !AdminPermissionPolicy.required(verb, d).equals(AdminPermissionPolicy.required(verb, sample))
                                || edu.bingol.backend.admin.AdminGuardPolicy.reasonMin(verb, d)
                                != edu.bingol.backend.admin.AdminGuardPolicy.reasonMin(verb, sample)
                                || edu.bingol.backend.admin.AuditRecorder.shouldAudit(verb, d)
                                != edu.bingol.backend.admin.AuditRecorder.shouldAudit(verb, sample)) {
                            wrong.add(verb + " " + v);
                        }
                    }
                }
            }
        }
        assertThat(variants).as("turetilmis varyant sayisi").isGreaterThan(5000);
        assertThat(wrong).as("kodlu yol farkli karar veriyor").isEmpty();
    }

    /** Interceptor katmani: kodlu yol, kodsuz yolla AYNI izin sonucunu verir (VIEWER ve MODERATOR). */
    @Test
    void interceptorTreatsEncodedVariantsLikePlainPaths() {
        int denied = 0;
        List<String> wrong = new ArrayList<>();
        for (AdminProfile profile : List.of(AdminProfile.VIEWER, AdminProfile.MODERATOR, AdminProfile.SUPPORT)) {
            AdminProfileResolver resolver = org.mockito.Mockito.mock(AdminProfileResolver.class);
            org.mockito.Mockito.when(resolver.resolve(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
                    .thenReturn(new AdminProfileResolver.Resolved(profile, false));
            AdminPermissionInterceptor icp = new AdminPermissionInterceptor(resolver);
            for (RequestMappingInfo info : mapping.getHandlerMethods().keySet()) {
                if (info.getPathPatternsCondition() == null) {
                    continue;
                }
                Set<RequestMethod> methods = info.getMethodsCondition().getMethods();
                List<String> verbs = methods.isEmpty() ? List.of("GET", "POST") : methods.stream().map(Enum::name).toList();
                for (String pattern : info.getPathPatternsCondition().getPatternValues()) {
                    if (!pattern.startsWith("/api/admin")) {
                        continue;
                    }
                    String sample = pattern.replaceAll("\\{[^}]*}", "1");
                    for (String verb : verbs) {
                        boolean plain = passes(icp, verb, sample);
                        if (!plain) {
                            denied++;
                        }
                        for (String v : encodedVariants(sample)) {
                            if (passes(icp, verb, v) != plain) {
                                wrong.add(profile + " " + verb + " " + v);
                            }
                        }
                    }
                }
            }
        }
        assertThat(denied).as("reddedilen kodsuz istek sayisi (test anlamli mi)").isGreaterThan(300);
        assertThat(wrong).as("kodlu yol izin katmanini atliyor").isEmpty();
    }

    private static boolean passes(AdminPermissionInterceptor icp, String verb, String rawUri) {
        org.springframework.mock.web.MockHttpServletRequest r = new org.springframework.mock.web.MockHttpServletRequest(verb, rawUri);
        r.setRequestURI(rawUri);
        try {
            return icp.preHandle(r, new org.springframework.mock.web.MockHttpServletResponse(), null);
        } catch (edu.bingol.backend.common.ApiException e) {
            return false;
        }
    }

    /** Yolun '/api/admin/' sonrasindaki her harfi/rakami tek tek, ve tum harfleri birlikte %xx yapar. */
    private static List<String> encodedVariants(String sample) {
        String prefix = "/api/admin/";
        List<String> out = new ArrayList<>();
        String tail = sample.substring(prefix.length());
        StringBuilder all = new StringBuilder();
        for (int i = 0; i < tail.length(); i++) {
            char c = tail.charAt(i);
            boolean enc = Character.isLetterOrDigit(c);
            all.append(enc ? String.format("%%%02x", (int) c) : String.valueOf(c));
            if (enc) {
                out.add(prefix + tail.substring(0, i) + String.format("%%%02X", (int) c) + tail.substring(i + 1));
            }
        }
        out.add(prefix + all);
        return out;
    }

    @Test
    void unmappedPathDefaultsToFullOnly() {
        assertThat(AdminPermissionPolicy.explicit("GET", "/api/admin/yeni-bilinmeyen-modul")).isEmpty();
        assertThat(AdminPermissionPolicy.required("GET", "/api/admin/yeni-bilinmeyen-modul"))
                .isEqualTo(PermissionMatrix.FULL_ONLY);
        for (AdminProfile p : AdminProfile.values()) {
            assertThat(PermissionMatrix.allows(p, PermissionMatrix.FULL_ONLY)).isEqualTo(p == AdminProfile.FULL);
        }
    }
}
