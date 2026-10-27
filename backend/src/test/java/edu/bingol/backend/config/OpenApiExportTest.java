package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Docker/canli sunucu olmadan docs/openapi.json uretir (scripts/openapi-export.sh bunu cagirir).
 * Her kosuda kararli (anahtarlari siralanmis) belge target/openapi-export.json'a yazilir;
 * -Dopenapi.out=../docs/openapi.json verilirse oraya da yazilir.
 * -Dopenapi.check=../docs/openapi.json verilirse commit'teki belgeyle karsilastirir (yol/islem kumesi; surum kaymasinda kirilir).
 */
@SpringBootTest
class OpenApiExportTest {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final List<String> METHODS = List.of("get", "post", "put", "patch", "delete");

    @Autowired
    WebApplicationContext ctx;

    @Test
    void exportAndOptionallyCheck() throws Exception {
        MockMvc mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
        var res = mvc.perform(get("/v3/api-docs").with(httpBasic("admin", "test-admin-pw"))).andReturn().getResponse();
        assertEquals(200, res.getStatus());
        JsonNode doc = OM.readTree(res.getContentAsString(StandardCharsets.UTF_8));
        ((ObjectNode) doc).set("servers", OM.readTree(
                "[{\"url\":\"http://localhost:8080\",\"description\":\"Yerel gelistirme (docker compose)\"}]"));
        String json = OM.writerWithDefaultPrettyPrinter().writeValueAsString(sorted(doc)) + "\n";

        Path target = Path.of("target", "openapi-export.json");
        Files.createDirectories(target.getParent());
        Files.writeString(target, json, StandardCharsets.UTF_8);
        String out = System.getProperty("openapi.out");
        if (out != null && !out.isBlank()) Files.writeString(Path.of(out), json, StandardCharsets.UTF_8);

        String check = System.getProperty("openapi.check");
        if (check != null && !check.isBlank()) {
            JsonNode committed = OM.readTree(Files.readString(Path.of(check), StandardCharsets.UTF_8));
            List<String> a = operations(committed), b = operations(doc);
            List<String> missing = new ArrayList<>(a), added = new ArrayList<>(b);
            missing.removeAll(b);
            added.removeAll(a);
            assertTrue(missing.isEmpty() && added.isEmpty(),
                    "docs/openapi.json guncel degil (scripts/openapi-export.sh calistirin). Eksik: " + missing + " Yeni: " + added);
        }
    }

    private static List<String> operations(JsonNode doc) {
        List<String> ops = new ArrayList<>();
        doc.path("paths").fields().forEachRemaining(p -> p.getValue().fieldNames().forEachRemaining(m -> {
            if (METHODS.contains(m)) ops.add(m.toUpperCase() + " " + p.getKey());
        }));
        Collections.sort(ops);
        return ops;
    }

    private static JsonNode sorted(JsonNode n) {
        if (n.isObject()) {
            ObjectNode o = OM.createObjectNode();
            List<String> names = new ArrayList<>();
            n.fieldNames().forEachRemaining(names::add);
            Collections.sort(names);
            for (String k : names) o.set(k, sorted(n.get(k)));
            return o;
        }
        if (n.isArray()) {
            ArrayNode a = OM.createArrayNode();
            n.forEach(e -> a.add(sorted(e)));
            return a;
        }
        return n;
    }
}
