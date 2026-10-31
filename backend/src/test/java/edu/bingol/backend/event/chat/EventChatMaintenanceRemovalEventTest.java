package edu.bingol.backend.event.chat;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.messaging.room.RoomConversations;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

/** T-031: toplu bakim ile dusen etkinlik odasi uyelerine conversation-removed olayi gider. */
class EventChatMaintenanceRemovalEventTest {

    private final RoomConversations rooms = mock(RoomConversations.class);
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final EventChatMaintenance job = new EventChatMaintenance(rooms, jdbc, 7);

    @Test
    @SuppressWarnings("unchecked")
    void everyDroppedMemberIsAnnouncedPerRoom() {
        when(jdbc.queryForList(anyString(), eq(Long.class), org.mockito.ArgumentMatchers.<Object>any())).thenReturn(List.of());
        // 1. cagri: dusecek uyelikler; 2. cagri: eksik organizatorler (bos)
        when(jdbc.queryForList(anyString())).thenReturn(
                List.of(Map.of("mid", 11L, "cid", 5L, "uid", 100L), Map.of("mid", 12L, "cid", 5L, "uid", 101L),
                        Map.of("mid", 13L, "cid", 6L, "uid", 102L)),
                List.of());
        when(jdbc.update(anyString(), eq(11L))).thenReturn(1);
        when(jdbc.update(anyString(), eq(12L))).thenReturn(0); // arada kendisi ayrilmis: olay gonderilmez
        when(jdbc.update(anyString(), eq(13L))).thenReturn(1);

        job.run();

        verify(rooms).announceRemoved(5L, List.of(100L));
        verify(rooms).announceRemoved(6L, List.of(102L));
        verify(rooms, never()).announceRemoved(eq(5L), eq(List.of(100L, 101L)));
    }

    @Test
    void nothingToDropSendsNoEvent() {
        when(jdbc.queryForList(anyString(), eq(Long.class), org.mockito.ArgumentMatchers.<Object>any())).thenReturn(List.of());
        when(jdbc.queryForList(anyString())).thenReturn(List.of());

        job.run();

        verify(rooms, never()).announceRemoved(org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.anyCollection());
    }
}
