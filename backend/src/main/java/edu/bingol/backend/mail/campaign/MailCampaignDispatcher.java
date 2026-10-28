package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.mail.MailTemplate;
import edu.bingol.backend.mail.campaign.MailAudienceResolver.Plan;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Zamani gelen mail kampanyalarini dagitir (push CampaignService kalibi). Her turda: kampanyayi kilitle
 * (FOR UPDATE SKIP LOCKED) ve SCHEDULED ise GONDERILIYOR yap; alicilari bir kez coz (satirlar yazilir); bekleyen
 * alicilarin bir kismini {@code MailService.enqueue} ile kuyruga yaz. Gonderim hizi kuyruk iscisinde sinirlanir; burada
 * yalniz tur basina parti boyutu vardir. Alici basina islem tek transaction'dadir: "QUEUED" isareti ve kuyruk satiri ya
 * birlikte yazilir ya hic: cokme/yeniden deneme/cift calisma durumunda ayni kisiye ikinci e-posta olusmaz.
 * Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class MailCampaignDispatcher {

    private static final Logger log = LoggerFactory.getLogger(MailCampaignDispatcher.class);
    private static final int CHECK_EVERY = 25;

    private final MailCampaignRepository campaigns;
    private final MailCustomTemplateVersionRepository versions;
    private final MailAudienceResolver resolver;
    private final MailService mail;
    private final MailCampaignSupport support;
    private final NamedParameterJdbcTemplate jdbc;
    private final TransactionTemplate tx;
    private final SchedulerLock lock;
    private final ObjectProvider<MailSuppressionGate> gate;
    private final int batchSize;
    private final int retentionDays;

    public MailCampaignDispatcher(MailCampaignRepository campaigns, MailCustomTemplateVersionRepository versions,
                                  MailAudienceResolver resolver, MailService mail, MailCampaignSupport support,
                                  NamedParameterJdbcTemplate jdbc, TransactionTemplate tx, SchedulerLock lock,
                                  ObjectProvider<MailSuppressionGate> gate,
                                  @Value("${app.mail.campaign-batch:200}") int batchSize,
                                  @Value("${app.mail.campaign-retention-days:180}") int retentionDays) {
        this.campaigns = campaigns;
        this.versions = versions;
        this.resolver = resolver;
        this.mail = mail;
        this.support = support;
        this.jdbc = jdbc;
        this.tx = tx;
        this.lock = lock;
        this.gate = gate;
        this.batchSize = Math.max(1, batchSize);
        this.retentionDays = Math.max(1, retentionDays);
    }

    @Scheduled(fixedDelayString = "${app.mail.campaign-poll-ms:10000}")
    public void poll() {
        try {
            lock.tryRun("mail-campaign", Duration.ofMinutes(5), this::tick);
        } catch (RuntimeException e) {
            log.error("Mail kampanya dagiticisi hata verdi: {}", e.toString());
        }
    }

    /** KVKK: bitmis kampanyalar ve alici satirlari {@code app.mail.campaign-retention-days} (180) gun sonra silinir. */
    @Scheduled(cron = "0 20 3 * * *", zone = "Europe/Istanbul")
    public void purgeOld() {
        try {
            lock.tryRun("mail-campaign-purge", Duration.ofMinutes(10), () -> purge(Instant.now()));
        } catch (RuntimeException e) {
            log.warn("Mail kampanya temizligi basarisiz: {}", e.toString());
        }
    }

    int purge(Instant now) {
        Instant cutoff = now.minus(Duration.ofDays(retentionDays));
        List<Long> ids = campaigns.findExpiredIds(cutoff, List.of(MailCampaign.Status.DRAFT, MailCampaign.Status.PAUSED));
        for (Long id : ids) {
            tx.executeWithoutResult(s -> {
                jdbc.update("DELETE FROM mail_campaign_recipient WHERE campaign_id = :id", Map.of("id", id));
                jdbc.update("DELETE FROM mail_campaign WHERE id = :id", Map.of("id", id));
            });
        }
        if (!ids.isEmpty()) {
            log.info("{} eski mail kampanyasi silindi", ids.size());
        }
        return ids.size();
    }

    /** Bir tur: en fazla 10 kampanya, her biri icin bir parti. Testler dogrudan cagirir. */
    public void tick() {
        List<Long> ids = campaigns.findActiveIds(Instant.now(), PageRequest.of(0, 10));
        for (Long id : ids) {
            try {
                process(id);
            } catch (RuntimeException e) {
                log.error("Mail kampanyasi {} islenemedi", id, e);
                fail(id, e);
            }
        }
    }

    private void process(Long id) {
        boolean ready = Boolean.TRUE.equals(tx.execute(s -> {
            MailCampaign c = campaigns.lockById(id).orElse(null);
            if (c == null) {
                return false; // baska ornek kilitli (SKIP LOCKED) ya da silinmis
            }
            if (c.getStatus() == MailCampaign.Status.SCHEDULED && c.getScheduledAt() != null
                    && !c.getScheduledAt().isAfter(Instant.now())) {
                c.setStatus(MailCampaign.Status.SENDING);
                c.setStartedAt(Instant.now());
                c.setUpdatedAt(Instant.now());
                campaigns.save(c);
            }
            return c.getStatus() == MailCampaign.Status.SENDING;
        }));
        if (!ready) {
            return;
        }
        MailCampaign c = campaigns.findById(id).orElse(null);
        if (c == null) {
            return;
        }
        if (c.getResolvedAt() == null) {
            resolve(c);
        }
        sendBatch(c);
    }

    /** Alicilari bir kez yazar. Yarida kalmissa (cokme) var olan (campaign,user) satirlari atlanir. */
    void resolve(MailCampaign c) {
        MailCustomTemplateVersion v = versions.findByTemplateIdAndVersion(c.getTemplateId(), c.getTemplateVersion()).orElseThrow();
        List<Plan> plans = resolver.plan(c.getAudienceType(), c.getAudienceValue(), v);
        Set<Long> existing = new HashSet<>(jdbc.queryForList("SELECT user_id FROM mail_campaign_recipient WHERE campaign_id = :c",
                Map.of("c", c.getId()), Long.class));
        List<Plan> fresh = plans.stream().filter(p -> !existing.contains(p.userId())).toList();
        tx.executeWithoutResult(s -> {
            Timestamp now = Timestamp.from(Instant.now());
            SqlParameterSource[] batch = fresh.stream().map(p -> (SqlParameterSource) new MapSqlParameterSource()
                    .addValue("c", c.getId()).addValue("u", p.userId()).addValue("st", p.status().name())
                    .addValue("sr", p.skipReason()).addValue("l", p.lang()).addValue("fb", p.fallback())
                    .addValue("now", now)).toArray(SqlParameterSource[]::new);
            jdbc.batchUpdate("INSERT INTO mail_campaign_recipient (campaign_id, user_id, status, skip_reason, lang, "
                    + "lang_fallback, updated_at) VALUES (:c, :u, :st, :sr, :l, :fb, :now)", batch);
            int n = jdbc.update("UPDATE mail_campaign SET resolved_at = :now, target_count = :t, updated_at = :now "
                    + "WHERE id = :c AND status = 'SENDING'", new MapSqlParameterSource("now", now)
                    .addValue("t", plans.size()).addValue("c", c.getId()));
            if (n == 0) {
                s.setRollbackOnly(); // bu arada iptal/duraklatildi: alici satirlari yazilmaz
            }
        });
    }

    private void sendBatch(MailCampaign c) {
        Long id = c.getId();
        List<long[]> rows = new ArrayList<>(); // {rowId, userId}
        List<String> langs = new ArrayList<>();
        jdbc.query("SELECT id, user_id, lang FROM mail_campaign_recipient WHERE campaign_id = :c AND status = 'PENDING' "
                + "ORDER BY id LIMIT :lim", new MapSqlParameterSource("c", id).addValue("lim", batchSize), rs -> {
            rows.add(new long[] {rs.getLong("id"), rs.getLong("user_id")});
            langs.add(rs.getString("lang"));
        });
        if (!rows.isEmpty()) {
            Map<Long, UserRow> users = loadUsers(rows);
            Map<Long, String> blocked = blocked(rows);
            for (int i = 0; i < rows.size(); i++) {
                if (i % CHECK_EVERY == 0 && !"SENDING".equals(status(id))) {
                    return; // duraklatildi/iptal edildi: kalan satirlar bekler (iptalde CANCELLED olur)
                }
                sendOne(c, rows.get(i)[0], users.get(rows.get(i)[1]), langs.get(i), blocked.get(rows.get(i)[1]));
            }
        }
        finishIfDone(id);
    }

    private void sendOne(MailCampaign c, long rowId, UserRow u, String lang, String blockedReason) {
        if (u == null || !u.eligible()) {
            mark(rowId, "SKIPPED", MailCampaignRecipient.INACTIVE, null);
            return;
        }
        if (blockedReason != null) {
            mark(rowId, "SKIPPED", blockedReason, null);
            return;
        }
        try {
            tx.executeWithoutResult(s -> {
                int n = jdbc.update("UPDATE mail_campaign_recipient SET status = 'QUEUED', updated_at = :now "
                        + "WHERE id = :id AND status = 'PENDING'", new MapSqlParameterSource("now", Timestamp.from(Instant.now()))
                        .addValue("id", rowId));
                if (n == 0) {
                    return; // iptal edilmis ya da baska ornek gondermis: dokunma
                }
                Map<String, String> vars = support.recipientVars(u.id(), u.email(), u.name(), u.department(),
                        u.faculty(), u.classYear(), Lang.of(lang));
                vars.put("tplId", String.valueOf(c.getTemplateId()));
                vars.put("tplVer", String.valueOf(c.getTemplateVersion()));
                // Kategori: duyuru (ANNOUNCEMENT). MailCategory/abonelik katmani geldiginde yalniz bu cagri guncellenir.
                mail.enqueue(u.email(), MailTemplate.CUSTOM, Lang.of(lang), vars);
            });
        } catch (RuntimeException e) {
            String code = e instanceof ApiException a ? a.code() : "ENQUEUE_ERROR";
            log.warn("Kampanya {} alici {} kuyruga alinamadi: {}", c.getId(), rowId, code);
            mark(rowId, "FAILED", null, code);
        }
    }

    private void mark(long rowId, String status, String reason, String errorCode) {
        jdbc.update("UPDATE mail_campaign_recipient SET status = :st, skip_reason = :sr, error_code = :ec, updated_at = :now "
                + "WHERE id = :id AND status = 'PENDING'", new MapSqlParameterSource("st", status).addValue("sr", reason)
                .addValue("ec", errorCode).addValue("now", Timestamp.from(Instant.now())).addValue("id", rowId));
    }

    private void finishIfDone(Long id) {
        jdbc.update("UPDATE mail_campaign SET status = 'DONE', finished_at = :now, updated_at = :now WHERE id = :id "
                + "AND status = 'SENDING' AND resolved_at IS NOT NULL AND NOT EXISTS (SELECT 1 FROM mail_campaign_recipient r "
                + "WHERE r.campaign_id = :id AND r.status = 'PENDING')", new MapSqlParameterSource("now", Timestamp.from(Instant.now()))
                .addValue("id", id));
    }

    private void fail(Long id, RuntimeException e) {
        try {
            String msg = e.toString();
            jdbc.update("UPDATE mail_campaign SET status = 'FAILED', error = :err, finished_at = :now, updated_at = :now "
                    + "WHERE id = :id AND status IN ('SCHEDULED', 'SENDING')", new MapSqlParameterSource("err",
                    msg.substring(0, Math.min(msg.length(), 300))).addValue("now", Timestamp.from(Instant.now())).addValue("id", id));
        } catch (RuntimeException ex) {
            log.error("Kampanya {} FAILED isaretlenemedi", id, ex);
        }
    }

    private String status(Long id) {
        List<String> r = jdbc.queryForList("SELECT status FROM mail_campaign WHERE id = :id", Map.of("id", id), String.class);
        return r.isEmpty() ? null : r.get(0);
    }

    private Map<Long, String> blocked(List<long[]> rows) {
        MailSuppressionGate g = gate.getIfAvailable();
        if (g == null) {
            return Map.of();
        }
        Map<Long, String> b = g.blocked(rows.stream().map(r -> r[1]).toList());
        return b == null ? Map.of() : b;
    }

    private record UserRow(Long id, String email, String name, String department, String faculty, Short classYear,
                           boolean eligible) {}

    private Map<Long, UserRow> loadUsers(List<long[]> rows) {
        List<Long> ids = rows.stream().map(r -> r[1]).toList();
        Map<Long, UserRow> out = new java.util.HashMap<>();
        jdbc.query("SELECT id, email, display_name, department, faculty, class_year, CASE WHEN status = 'ACTIVE' "
                + "AND email_verified = TRUE AND deleted_at IS NULL THEN 1 ELSE 0 END AS ok FROM app_user WHERE id IN (:ids)",
                new MapSqlParameterSource("ids", ids), rs -> {
                    short cy = rs.getShort("class_year");
                    Short classYear = rs.wasNull() ? null : cy; // wasNull son okunan sutun icin gecerlidir
                    out.put(rs.getLong("id"), new UserRow(rs.getLong("id"), rs.getString("email"), rs.getString("display_name"),
                            rs.getString("department"), rs.getString("faculty"), classYear, rs.getInt("ok") == 1));
                });
        return out;
    }
}
