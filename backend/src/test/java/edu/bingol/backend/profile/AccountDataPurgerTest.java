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
        verify(jdbc, times(AccountDataPurger.DELETES.size() + 1)).update(sql.capture(), org.mockito.ArgumentMatchers.eq(7L));
        List<String> all = sql.getAllValues();
        for (String table : List.of("device", "notification", "notification_pref", "notification_subtype_pref",
                "bookmark", "club_join_answer", "community_member")) {
            assertTrue(all.stream().anyMatch(s -> s.startsWith("DELETE FROM " + table + " ")), table);
        }
        assertTrue(all.contains(AccountDataPurger.LEAVE_ROOMS));
    }

    @Test
    void keepsCommunityOwnershipAndBanRecords() {
        String members = AccountDataPurger.DELETES.stream().filter(s -> s.contains("community_member")).findFirst()
                .orElseThrow();
        assertTrue(members.contains("role <> 'OWNER'"));
        assertTrue(members.contains("status <> 'BANNED'"));
    }
}
