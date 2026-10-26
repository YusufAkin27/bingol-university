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
