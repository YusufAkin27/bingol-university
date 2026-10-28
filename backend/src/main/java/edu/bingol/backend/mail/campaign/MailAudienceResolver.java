package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudienceRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.Filter;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/**
 * Kampanya hedef kitlesini cozer. Kural: yalnizca KAYITLI kullanicilar (serbest e-posta adresi yok).
 * Dinamik SQL parametrelidir. ALL/FILTER yalnizca aktif + dogrulanmis + silinmemis kullanicilari getirir;
 * USERS/EMAILS secili kullanicilardan uygun olmayanlari "atlandi" olarak isaretler (sayaclarda gorunur).
 */
@Component
public class MailAudienceResolver {

    public static final int MAX_LIST = 2000;
    private static final int CHUNK = 500;
    private static final String ELIGIBLE = "u.status = 'ACTIVE' AND u.email_verified = TRUE AND u.deleted_at IS NULL";

    /** Cozumlenmis aday kullanici (e-posta yalniz bellekte, kaydedilmez). */
    public record Candidate(long id, String email, String lang, boolean eligible) {}

    /** Bir kullanici icin karar: PENDING (gonderilecek) veya SKIPPED + neden. */
    public record Plan(long userId, MailCampaignRecipient.Status status, String skipReason, String lang,
                       boolean fallback) {}

    /** Normallestirilmis hedef: veritabaninda saklanacak tur/deger ve eslesmeyen girdi sayisi. */
    public record Normalized(MailCampaign.AudienceType type, String value, int unmatched, Integer userCount) {}

    private final NamedParameterJdbcTemplate jdbc;
    private final JsonMapper json;
    private final ObjectProvider<MailSuppressionGate> gate;

    public MailAudienceResolver(NamedParameterJdbcTemplate jdbc, JsonMapper json, ObjectProvider<MailSuppressionGate> gate) {
        this.jdbc = jdbc;
        this.json = json;
        this.gate = gate;
    }

    // ---------- dogrulama / normallestirme ----------

    public Normalized normalize(AudienceRequest a) {
        return switch (a.type()) {
            case ALL -> new Normalized(a.type(), null, 0, null);
            case FILTER -> new Normalized(a.type(), json.writeValueAsString(cleanFilter(a.filter())), 0, null);
            case USERS -> normalizeUsers(a);
            case EMAILS -> normalizeEmails(a);
        };
    }

    private Filter cleanFilter(Filter f) {
        if (f == null) {
            throw invalid();
        }
        String faculty = blankToNull(f.faculty());
        String department = blankToNull(f.department());
        String language = blankToNull(f.language());
        if (language != null) {
            language = language.toLowerCase(Locale.ROOT);
            if (!List.of("tr", "en", "ar").contains(language)) {
                throw invalid();
            }
        }
        if (f.classYear() != null && (f.classYear() < 0 || f.classYear() > 8)) {
            throw invalid();
        }
        if (f.communityId() != null && f.communityId() <= 0) {
            throw invalid();
        }
        if (faculty == null && department == null && language == null && f.classYear() == null && f.role() == null
                && f.communityId() == null) {
            throw invalid();
        }
        return new Filter(faculty, department, f.classYear(), f.role(), language, f.communityId());
    }

    private Normalized normalizeUsers(AudienceRequest a) {
        Set<Long> ids = new LinkedHashSet<>();
        if (a.userIds() != null) {
            a.userIds().stream().filter(x -> x != null && x > 0).forEach(ids::add);
        }
        if (ids.isEmpty() || ids.size() > MAX_LIST) {
            throw invalid();
        }
        Set<Long> existing = existingIds(ids);
        return pick(a.type(), existing, ids.size() - existing.size());
    }

    private Normalized normalizeEmails(AudienceRequest a) {
        Set<String> emails = new LinkedHashSet<>();
        int bad = 0;
        if (a.emails() != null) {
            for (String e : a.emails()) {
                String n = e == null ? "" : e.trim().toLowerCase(Locale.ROOT);
                if (n.isEmpty()) {
                    continue;
                }
                if (n.length() > 254 || n.indexOf('@') < 1 || n.indexOf('@') != n.lastIndexOf('@')
                        || n.chars().anyMatch(c -> c <= ' ' || c == ',' || c == ';' || c == '<' || c == '>')) {
                    bad++;
                } else {
                    emails.add(n);
                }
            }
        }
        if (emails.isEmpty() && bad == 0 || emails.size() + bad > MAX_LIST) {
            throw invalid();
        }
        Set<Long> found = new LinkedHashSet<>();
        List<String> all = new ArrayList<>(emails);
        for (int i = 0; i < all.size(); i += CHUNK) {
            List<String> part = all.subList(i, Math.min(all.size(), i + CHUNK));
            found.addAll(jdbc.queryForList("SELECT id FROM app_user WHERE LOWER(email) IN (:e)",
                    new MapSqlParameterSource("e", part), Long.class));
        }
        return pick(a.type(), found, emails.size() - found.size() + bad);
    }

    private Normalized pick(MailCampaign.AudienceType type, Set<Long> ids, int unmatched) {
        if (ids.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MAIL_CAMPAIGN_NO_RECIPIENTS", "Bu hedefte alıcı bulunamadı.");
        }
        return new Normalized(type, String.join(",", ids.stream().map(String::valueOf).toList()),
                Math.max(0, unmatched), ids.size());
    }

    private Set<Long> existingIds(Collection<Long> ids) {
        Set<Long> found = new LinkedHashSet<>();
        List<Long> all = new ArrayList<>(ids);
        for (int i = 0; i < all.size(); i += CHUNK) {
            found.addAll(jdbc.queryForList("SELECT id FROM app_user WHERE id IN (:ids)",
                    new MapSqlParameterSource("ids", all.subList(i, Math.min(all.size(), i + CHUNK))), Long.class));
        }
        return found;
    }

    public Filter parseFilter(String jsonValue) {
        return jsonValue == null ? null : json.readValue(jsonValue, Filter.class);
    }

    // ---------- cozumleme ----------

    /** Adaylar (kimlik sirali). */
    public List<Candidate> candidates(MailCampaign.AudienceType type, String value) {
        return switch (type) {
            case ALL -> query(ELIGIBLE, new MapSqlParameterSource());
            case FILTER -> filtered(parseFilter(value));
            case USERS, EMAILS -> selected(value);
        };
    }

    private List<Candidate> filtered(Filter f) {
        StringBuilder where = new StringBuilder(ELIGIBLE);
        MapSqlParameterSource p = new MapSqlParameterSource();
        if (f.faculty() != null) {
            where.append(" AND LOWER(u.faculty) = :faculty");
            p.addValue("faculty", f.faculty().toLowerCase(Locale.ROOT));
        }
        if (f.department() != null) {
            where.append(" AND LOWER(u.department) = :department");
            p.addValue("department", f.department().toLowerCase(Locale.ROOT));
        }
        if (f.classYear() != null) {
            where.append(" AND u.class_year = :classYear");
            p.addValue("classYear", f.classYear());
        }
        if (f.role() != null) {
            where.append(" AND u.role = :role");
            p.addValue("role", f.role().name());
        }
        if (f.language() != null) {
            where.append(" AND u.language = :language");
            p.addValue("language", f.language());
        }
        if (f.communityId() != null) {
            where.append(" AND u.id IN (SELECT m.user_id FROM community_member m "
                    + "WHERE m.community_id = :community AND m.status = 'ACTIVE')");
            p.addValue("community", f.communityId());
        }
        return query(where.toString(), p);
    }

    private List<Candidate> query(String where, MapSqlParameterSource p) {
        return jdbc.query("SELECT u.id, u.email, u.language, 1 AS eligible FROM app_user u WHERE " + where
                + " ORDER BY u.id", p, (rs, i) -> new Candidate(rs.getLong("id"), rs.getString("email"),
                rs.getString("language"), true));
    }

    private List<Candidate> selected(String csv) {
        List<Long> ids = new ArrayList<>();
        if (csv != null && !csv.isBlank()) {
            for (String s : csv.split(",")) {
                ids.add(Long.parseLong(s.trim()));
            }
        }
        List<Candidate> out = new ArrayList<>();
        for (int i = 0; i < ids.size(); i += CHUNK) {
            out.addAll(jdbc.query("SELECT u.id, u.email, u.language, CASE WHEN " + ELIGIBLE
                            + " THEN 1 ELSE 0 END AS eligible FROM app_user u WHERE u.id IN (:ids) ORDER BY u.id",
                    new MapSqlParameterSource("ids", ids.subList(i, Math.min(ids.size(), i + CHUNK))),
                    (rs, n) -> new Candidate(rs.getLong("id"), rs.getString("email"), rs.getString("language"),
                            rs.getInt("eligible") == 1)));
        }
        return out;
    }

    /**
     * Adaylari karara baglar: uygun olmayan -> INACTIVE; gecersiz adres -> INVALID_ADDRESS; ayni adres ikinci kez ->
     * DUPLICATE_ADDRESS; bastirilmis/duyuru tercihi kapali -> kapidan gelen neden. Dil: kullanici dili, sablonda yoksa tr.
     */
    public List<Plan> plan(MailCampaign.AudienceType type, String value, MailCustomTemplateVersion version) {
        List<Candidate> cands = candidates(type, value);
        Set<String> seen = new HashSet<>();
        List<Candidate> sendable = new ArrayList<>();
        Map<Long, Plan> skipped = new LinkedHashMap<>();
        for (Candidate c : cands) {
            if (!c.eligible()) {
                skipped.put(c.id(), skip(c, MailCampaignRecipient.INACTIVE));
            } else if (!plausible(c.email())) {
                skipped.put(c.id(), skip(c, MailCampaignRecipient.INVALID_ADDRESS));
            } else if (!seen.add(c.email().toLowerCase(Locale.ROOT))) {
                skipped.put(c.id(), skip(c, MailCampaignRecipient.DUPLICATE_ADDRESS));
            } else {
                sendable.add(c);
            }
        }
        Map<Long, String> blocked = blocked(sendable);
        List<Plan> plans = new ArrayList<>();
        for (Candidate c : cands) {
            Plan s = skipped.get(c.id());
            if (s != null) {
                plans.add(s);
            } else if (blocked.containsKey(c.id())) {
                plans.add(skip(c, blocked.get(c.id())));
            } else {
                Lang want = Lang.of(c.lang());
                boolean fb = version != null && !CustomMailRenderer.contentOf(version, want).complete();
                plans.add(new Plan(c.id(), MailCampaignRecipient.Status.PENDING, null, fb ? "tr" : want.code(), fb));
            }
        }
        return plans;
    }

    private Map<Long, String> blocked(List<Candidate> sendable) {
        MailSuppressionGate g = gate.getIfAvailable();
        if (g == null || sendable.isEmpty()) {
            return Map.of();
        }
        Map<Long, String> out = new LinkedHashMap<>();
        for (int i = 0; i < sendable.size(); i += 1000) {
            List<Long> ids = sendable.subList(i, Math.min(sendable.size(), i + 1000)).stream().map(Candidate::id).toList();
            Map<Long, String> part = g.blocked(ids);
            if (part != null) {
                out.putAll(part);
            }
        }
        return out;
    }

    private static Plan skip(Candidate c, String reason) {
        return new Plan(c.id(), MailCampaignRecipient.Status.SKIPPED, reason, Lang.of(c.lang()).code(), false);
    }

    private static boolean plausible(String a) {
        return a != null && !a.isBlank() && a.length() <= 254 && a.indexOf('@') > 0 && a.indexOf('@') == a.lastIndexOf('@')
                && a.indexOf('@') < a.length() - 1 && a.chars().noneMatch(c -> c <= ' ' || c == ',' || c == ';' || c == '<' || c == '>');
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "MAIL_CAMPAIGN_AUDIENCE_INVALID", "Hedef kitle geçersiz.");
    }
}
