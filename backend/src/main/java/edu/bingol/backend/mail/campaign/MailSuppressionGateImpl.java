package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.mail.MailSuppressionService;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Kampanya sayaclari icin bastirma kapisi: mail modulunun bastirma listesindeki (abonelikten cikmis, bounce,
 * sikayet) adresler SUPPRESSED olarak atlanir. Duyuru tercihi bastirma listesi ile aynidir (ayri bir bayrak yoktur).
 * Kuyruk iscisi gonderim aninda ayrica yeniden kontrol eder.
 */
@Component
public class MailSuppressionGateImpl implements MailSuppressionGate {

    private final NamedParameterJdbcTemplate jdbc;
    private final MailSuppressionService suppression;

    public MailSuppressionGateImpl(NamedParameterJdbcTemplate jdbc, MailSuppressionService suppression) {
        this.jdbc = jdbc;
        this.suppression = suppression;
    }

    @Override
    public Map<Long, String> blocked(Collection<Long> userIds) {
        Map<Long, String> out = new LinkedHashMap<>();
        if (userIds.isEmpty()) {
            return out;
        }
        jdbc.query("SELECT id, email FROM app_user WHERE id IN (:ids)", new MapSqlParameterSource("ids", userIds), rs -> {
            String email = rs.getString("email");
            if (email != null && suppression.isSuppressed(email)) {
                out.put(rs.getLong("id"), MailCampaignRecipient.SUPPRESSED);
            }
        });
        return out;
    }
}
