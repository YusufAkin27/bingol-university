package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;

class AccountDataPurgerTest {

    @Test
    void purgesAllPersonalTablesAndLeavesRooms() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        new AccountDataPurger(jdbc).purge(7L);

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc, times(AccountDataPurger.DELETES.size() + AccountDataPurger.SCRUBS.size() + 1)).update(sql.capture(), org.mockito.ArgumentMatchers.eq(7L));
        List<String> all = sql.getAllValues();
        for (String table : List.of("device", "notification", "notification_pref", "notification_subtype_pref",
                "bookmark", "club_join_answer", "community_member", "feedback_vote", "event_feedback", "user_block")) {
            assertTrue(all.stream().anyMatch(s -> s.startsWith("DELETE FROM " + table + " ")), table);
        }
        assertTrue(all.contains(AccountDataPurger.LEAVE_ROOMS));
    }

    /** T-063: log/kayit tablolari (A8-16) hesap silmede user_id ile silinir. */
    @Test
    void purgesLogAndViewTables() {
        for (String table : List.of("blocked_attempt_log", "profanity_hit_log", "message_attachment_view",
                "message_reaction", "club_member_grant", "conversation_add_ban", "event_co_organizer")) {
            assertTrue(AccountDataPurger.DELETES.stream().anyMatch(s -> s.startsWith("DELETE FROM " + table + " ")), table);
        }
    }

    /** T-063: e-posta kuyrugunda silinen kisinin adresi (kucuk harfli) silinir; "hesap silindi" postasi muaf. */
    @Test
    void deletesQueuedMailByOldAddress() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        new AccountDataPurger(jdbc).purge(7L, "  Ali.Veli@Bingol.edu.tr ");

        verify(jdbc).update(AccountDataPurger.MAIL_BY_ADDRESS, "ali.veli@bingol.edu.tr");
        assertTrue(AccountDataPurger.MAIL_BY_ADDRESS.contains("ACCOUNT_DELETED"));
    }

    @Test
    void noAddressMeansNoMailDelete() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        new AccountDataPurger(jdbc).purge(7L);
        assertTrue(org.mockito.Mockito.mockingDetails(jdbc).getInvocations().stream()
                .noneMatch(i -> i.getArguments().length > 0 && AccountDataPurger.MAIL_BY_ADDRESS.equals(i.getArguments()[0])));
    }

    @Test
    void ledgerIsWrittenAfterPurge() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        AccountDataPurger purger = new AccountDataPurger(jdbc);
        DeletionLedger ledger = mock(DeletionLedger.class);
        purger.setLedger(ledger);

        purger.purge(7L);

        verify(ledger).record(7L); // islem yok: AfterCommit hemen calisir
    }

    @Test
    void scrubsFreeTextButNeverTouchesLegalAcceptance() {
        List<String> scrubs = AccountDataPurger.SCRUBS;
        for (String table : List.of("feedback", "support_ticket", "support_message", "moderation_appeal", "report",
                "event_application", "event_certificate")) {
            assertTrue(scrubs.stream().anyMatch(s -> s.startsWith("UPDATE " + table + " ")), table);
        }
        assertTrue(scrubs.stream().noneMatch(s -> s.contains("legal_acceptance")));
        assertTrue(AccountDataPurger.DELETES.stream().noneMatch(s -> s.contains("legal_acceptance")));
        assertTrue(scrubs.stream().allMatch(s -> s.startsWith("UPDATE ")));
    }

    @Test
    void keepsCommunityOwnershipAndBanRecords() {
        String members = AccountDataPurger.DELETES.stream().filter(s -> s.contains("community_member")).findFirst()
                .orElseThrow();
        assertTrue(members.contains("role <> 'OWNER'"));
        assertTrue(members.contains("status <> 'BANNED'"));
    }
}
