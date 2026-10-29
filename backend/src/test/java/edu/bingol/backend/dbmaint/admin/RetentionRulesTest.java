package edu.bingol.backend.dbmaint.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.dbmaint.admin.RetentionTables.Spec;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

/** Saf kurallar: beyaz liste degismezleri ve tarih araligi dogrulamasi (asgari saklama suresi). */
class RetentionRulesTest {

    /** Bu tablolar ASLA panelden silinebilir/aktarilabilir listeye girmemeli. */
    private static final Set<String> FORBIDDEN = Set.of("app_user", "message", "message_attachment", "legal_acceptance",
            "legal_document", "post", "community", "event", "refresh_token", "app_setting", "support_ticket",
            "analytics_event_daily", "data_export_receipt", "data_purge_log", "conversation");

    private static RetentionService svc(String today) {
        Clock c = Clock.fixed(Instant.parse(today + "T12:00:00Z"), ZoneId.of("Europe/Istanbul"));
        return new RetentionService(null, null, c, 1_000_000);
    }

    @Test
    void whitelistNeverContainsCoreOrUserDataTables() {
        for (Spec s : RetentionTables.all()) {
            assertThat(FORBIDDEN).doesNotContain(s.name());
            assertThat(s.name()).matches("[a-z_]+");
            assertThat(s.columns().get(0).name()).as("keyset anahtari ilk kolon: " + s.name()).isEqualTo(s.keyColumn());
            assertThat(s.minDays()).isGreaterThanOrEqualTo(7);
        }
        assertThat(RetentionTables.find("message")).isEmpty();
        assertThat(RetentionTables.find("app_user; DROP TABLE x")).isEmpty();
    }

    @Test
    void auditTablesKeepAtLeastNinetyDaysAndAppendOnlyOneIsNotDeletable() {
        assertThat(RetentionTables.find("admin_audit").orElseThrow().minDays()).isGreaterThanOrEqualTo(90);
        assertThat(RetentionTables.find("club_audit").orElseThrow().minDays()).isGreaterThanOrEqualTo(90);
        Spec mac = RetentionTables.find("message_access_audit").orElseThrow();
        assertThat(mac.deletable()).isFalse();
        assertThat(mac.minDays()).isGreaterThanOrEqualTo(90);
    }

    @Test
    void queueTablesOnlyTouchSentAndDeadRows() {
        for (String n : List.of("mail_outbox", "push_outbox")) {
            Spec s = RetentionTables.find(n).orElseThrow();
            assertThat(s.rangeWhere()).contains("status IN ('SENT', 'DEAD')");
            // govde/yuk kolonlari asla disa aktarilmaz
            assertThat(s.columns().stream().map(RetentionTables.Col::name)).doesNotContain("vars_json", "payload_json");
        }
        assertThat(RetentionTables.find("notification").orElseThrow().rangeWhere()).contains("read_at IS NOT NULL");
    }

    @Test
    void rangeMustEndBeforeMinimumRetention() {
        RetentionService s = svc("2026-10-29");
        Spec audit = RetentionTables.find("admin_audit").orElseThrow(); // 90 gun
        LocalDate max = s.maxTo(audit);
        assertThat(max).isEqualTo(LocalDate.of(2026, 7, 31));
        assertThat(s.resolveRange(audit, null, max).toExclusive()).isEqualTo(max);
        assertThat(s.resolveRange(audit, null, max).from()).isEqualTo(LocalDate.of(1970, 1, 1));
        assertThatThrownBy(() -> s.resolveRange(audit, null, max.plusDays(1)))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.code()).isEqualTo("RETENTION_RANGE_TOO_RECENT"));
    }

    @Test
    void invalidRangesAreRejected() {
        RetentionService s = svc("2026-10-29");
        Spec ev = RetentionTables.find("analytics_event").orElseThrow(); // 7 gun
        LocalDate to = LocalDate.of(2026, 10, 1);
        assertThatThrownBy(() -> s.resolveRange(ev, to, to)).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.code()).isEqualTo("RETENTION_RANGE_INVALID"));
        assertThatThrownBy(() -> s.resolveRange(ev, to.plusDays(1), to)).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.code()).isEqualTo("RETENTION_RANGE_INVALID"));
        assertThatThrownBy(() -> s.resolveRange(ev, null, null)).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.code()).isEqualTo("RETENTION_RANGE_INVALID"));
        assertThatThrownBy(() -> s.requireSpec("message")).isInstanceOfSatisfying(ApiException.class,
                e -> assertThat(e.code()).isEqualTo("RETENTION_TABLE_UNKNOWN"));
    }
}
