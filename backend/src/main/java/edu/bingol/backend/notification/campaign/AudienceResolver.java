package edu.bingol.backend.notification.campaign;

import edu.bingol.backend.notification.campaign.PushCampaign.AudienceType;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Kampanya kitlesini cozer. Yalnizca aktif ve e-postasi dogrulanmis hesaplar (askidaki/silinmis/anonimlesmis atlanir);
 * sonuc kullanici kimligine gore tekillestirilir. Tercih (bildirim turu) suzmesi gonderim aninda NotificationService'tedir.
 */
@Component
public class AudienceResolver {

    /** Tek bir alici (onizleme ornegi ve dil kirilimi icin). */
    public record Member(Long id, String language, String displayName, String email) {}

    /** notFound: EMAILS/USERS listesinde bulunamayan veya uygun olmayan girdiler (en cok 50). */
    public record Resolved(List<Member> members, List<String> notFound) {}

    static final int MAX_ITEMS = 500;
    private static final String BASE =
            "SELECT id, language, display_name, email FROM app_user WHERE status = 'ACTIVE' AND email_verified = TRUE";

    private final NamedParameterJdbcTemplate jdbc;

    public AudienceResolver(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Resolved resolve(AudienceType type, String value, Long adminId) {
        List<Member> rows;
        List<String> notFound = List.of();
        switch (type) {
            case ALL -> rows = query("", new MapSqlParameterSource());
            case DEPARTMENT -> rows = query(" AND department = :v", new MapSqlParameterSource("v", value));
            case FACULTY -> rows = query(" AND faculty = :v", new MapSqlParameterSource("v", value));
            case CLASS_YEAR -> rows = query(" AND class_year = :v", new MapSqlParameterSource("v", Short.parseShort(value)));
            case LANGUAGE -> rows = query(" AND language = :v", new MapSqlParameterSource("v", value));
            case ADMINS -> rows = query(" AND role = 'ADMIN'", new MapSqlParameterSource());
            case SELF -> rows = query(" AND id = :v", new MapSqlParameterSource("v", adminId));
            case USERS -> {
                Set<Long> ids = parseIds(value);
                rows = ids.isEmpty() ? List.of() : query(" AND id IN (:v)", new MapSqlParameterSource("v", ids));
                Set<Long> found = new LinkedHashSet<>();
                rows.forEach(m -> found.add(m.id()));
                notFound = ids.stream().filter(i -> !found.contains(i)).map(String::valueOf).limit(50).toList();
            }
            case EMAILS -> {
                Tokens t = parseEmails(value);
                List<Member> byMail = t.emails().isEmpty() ? List.of()
                        : query(" AND lower(email) IN (:v)", new MapSqlParameterSource("v", t.emails()));
                List<Member> byId = t.ids().isEmpty() ? List.of()
                        : query(" AND id IN (:v)", new MapSqlParameterSource("v", t.ids()));
                rows = new ArrayList<>(byMail);
                rows.addAll(byId);
                Set<String> foundMail = new LinkedHashSet<>();
                Set<Long> foundId = new LinkedHashSet<>();
                rows.forEach(m -> {
                    foundMail.add(m.email().toLowerCase(Locale.ROOT));
                    foundId.add(m.id());
                });
                List<String> nf = new ArrayList<>();
                t.emails().stream().filter(e -> !foundMail.contains(e)).forEach(nf::add);
                t.ids().stream().filter(i -> !foundId.contains(i)).map(String::valueOf).forEach(nf::add);
                nf.addAll(t.invalid());
                notFound = nf.stream().limit(50).toList();
            }
            default -> rows = List.of();
        }
        Map<Long, Member> unique = new LinkedHashMap<>();
        for (Member m : rows) {
            unique.putIfAbsent(m.id(), m);
        }
        return new Resolved(new ArrayList<>(unique.values()), notFound);
    }

    private List<Member> query(String where, MapSqlParameterSource p) {
        return jdbc.query(BASE + where + " ORDER BY id", p,
                (rs, i) -> new Member(rs.getLong("id"), rs.getString("language"), rs.getString("display_name"),
                        rs.getString("email")));
    }

    static Set<Long> parseIds(String csv) {
        Set<Long> ids = new LinkedHashSet<>();
        if (csv == null || csv.isBlank()) {
            return ids;
        }
        for (String part : csv.split(",")) {
            try {
                ids.add(Long.parseLong(part.trim()));
            } catch (NumberFormatException e) {
                throw CampaignService.invalidAudience();
            }
        }
        return ids;
    }

    record Tokens(Set<String> emails, Set<Long> ids, List<String> invalid) {}

    /** Satir/virgul/noktalivirgul/bosluk ayrili liste: e-posta (kucuk harf) veya yalnizca rakamlardan olusan kullanici kimligi. */
    static Tokens parseEmails(String text) {
        Set<String> emails = new LinkedHashSet<>();
        Set<Long> ids = new LinkedHashSet<>();
        List<String> invalid = new ArrayList<>();
        if (text != null) {
            for (String raw : text.split("[\\s,;]+")) {
                String tok = raw.trim();
                if (tok.isEmpty()) {
                    continue;
                }
                if (tok.matches("\\d{1,18}")) {
                    ids.add(Long.parseLong(tok));
                } else if (tok.length() <= 254 && tok.matches("[^@\\s]+@[^@\\s]+\\.[^@\\s]+")) {
                    emails.add(tok.toLowerCase(Locale.ROOT));
                } else {
                    invalid.add(tok.length() > 80 ? tok.substring(0, 80) : tok);
                }
            }
        }
        if (emails.size() + ids.size() > MAX_ITEMS) {
            throw CampaignService.invalidAudience();
        }
        return new Tokens(emails, ids, invalid);
    }
}
