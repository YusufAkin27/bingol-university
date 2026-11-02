package edu.bingol.backend.campus;

import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/** units_json / footprint_json / boundary_json metin sutunlari icin okuma-yazma yardimcilari (hata vermez, bos doner). */
final class CampusJson {

    private static final Logger log = LoggerFactory.getLogger(CampusJson.class);
    private static final JsonMapper MAPPER = JsonMapper.builder().build();
    private static final TypeReference<List<String>> STRINGS = new TypeReference<>() { };
    private static final TypeReference<List<List<Double>>> POINTS = new TypeReference<>() { };

    private CampusJson() {}

    static List<String> units(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            List<String> v = MAPPER.readValue(json, STRINGS);
            return v == null ? List.of() : v;
        } catch (RuntimeException e) {
            log.warn("Kampus birim listesi okunamadi: {}", e.toString());
            return List.of();
        }
    }

    /** {@code [[lat,lng],...]}; bozuk/bos ise bos liste, gecersiz cift atlanir. */
    static List<double[]> points(String json) {
        if (json == null || json.isBlank()) {
            return List.of();
        }
        try {
            List<List<Double>> raw = MAPPER.readValue(json, POINTS);
            List<double[]> out = new ArrayList<>();
            if (raw != null) {
                for (List<Double> p : raw) {
                    if (p != null && p.size() == 2 && p.get(0) != null && p.get(1) != null) {
                        out.add(new double[] {p.get(0), p.get(1)});
                    }
                }
            }
            return out;
        } catch (RuntimeException e) {
            log.warn("Kampus nokta listesi okunamadi: {}", e.toString());
            return List.of();
        }
    }

    static String write(Object value) {
        return MAPPER.writeValueAsString(value);
    }

    static String writePoints(List<double[]> pts) {
        List<List<Double>> raw = new ArrayList<>(pts.size());
        for (double[] p : pts) {
            raw.add(List.of(p[0], p[1]));
        }
        return write(raw);
    }
}
