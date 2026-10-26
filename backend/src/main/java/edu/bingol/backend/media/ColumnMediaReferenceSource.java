package edu.bingol.backend.media;

import edu.bingol.backend.config.MediaProperties;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Bilinen gorsel sutunlarini (+ `app.media.extra-reference-columns`) sorgulayan varsayilan kaynak. */
@Component
public class ColumnMediaReferenceSource implements MediaReferenceSource {

    private static final Logger log = LoggerFactory.getLogger(ColumnMediaReferenceSource.class);
    private static final Pattern IDENT = Pattern.compile("[a-z_][a-z0-9_]*");
    static final List<String> DEFAULTS = List.of(
            "app_user.avatar_url", "community.cover_url", "community_post.image_url", "user_event.cover_url");

    private final JdbcTemplate jdbc;
    private final List<String[]> columns = new ArrayList<>();

    public ColumnMediaReferenceSource(JdbcTemplate jdbc, MediaProperties props) {
        this.jdbc = jdbc;
        List<String> all = new ArrayList<>(DEFAULTS);
        all.addAll(props.extraReferenceColumns());
        for (String c : all) {
            String[] parts = c.trim().split("\\.");
            // Tanimlayicilar SQL'e eklenir: yalniz kati desen kabul edilir
            if (parts.length == 2 && IDENT.matcher(parts[0]).matches() && IDENT.matcher(parts[1]).matches()) {
                columns.add(parts);
            } else {
                log.warn("Gecersiz medya referans sutunu yok sayildi: {}", c);
            }
        }
    }

    @Override
    public boolean isReferenced(String url) {
        for (String[] c : columns) {
            try {
                Integer n = jdbc.queryForObject(
                        "SELECT COUNT(*) FROM " + c[0] + " WHERE " + c[1] + " = ?", Integer.class, url);
                if (n != null && n > 0) {
                    return true;
                }
            } catch (RuntimeException e) {
                // Emin degilsek dosyayi silmeyiz
                log.warn("Medya referans sorgusu basarisiz {}.{}: {}", c[0], c[1], e.toString());
                return true;
            }
        }
        return false;
    }
}
