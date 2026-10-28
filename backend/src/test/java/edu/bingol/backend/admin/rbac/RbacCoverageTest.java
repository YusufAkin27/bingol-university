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
