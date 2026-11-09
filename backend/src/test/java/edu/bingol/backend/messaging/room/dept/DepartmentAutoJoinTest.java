package edu.bingol.backend.messaging.room.dept;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppSetting;
import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.AutoAdd;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.AutoJoinResult;
import edu.bingol.backend.unitnews.UnitKeys;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;

/** Otomatik bolum kanali uyeligi: ilk atama, opt-out, kapasite, sessiz varsayilan, geri doldurma. */
class DepartmentAutoJoinTest {

    private static final String DEPT = "Bilgisayar Mühendisliği";

    private final RoomConversations rooms = mock(RoomConversations.class);
    private final DepartmentChatRoomRepository depts = mock(DepartmentChatRoomRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final DepartmentChatOptoutRepository optouts = mock(DepartmentChatOptoutRepository.class);
    private final DepartmentChatService svc = new DepartmentChatService(rooms, depts, users,
            new edu.bingol.backend.catalog.CatalogService(), mock(edu.bingol.backend.messaging.ConversationService.class),
            optouts);

    private String key() {
        return UnitKeys.deptKey(DEPT);
    }

    private User user(long id) {
        User u = new User();
        u.setId(id);
        u.setEmailVerified(true);
        u.setDepartment(DEPT);
        u.setRole(Role.USER);
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    private void roomExists() {
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        r.setDeptKey(key());
        r.setName(DEPT);
        when(depts.findByDeptKey(key())).thenReturn(Optional.of(r));
        when(rooms.find(RoomKind.DEPARTMENT, 7L)).thenReturn(Optional.of(new RoomInfo(70L, RoomKind.DEPARTMENT, 7L, false)));
    }

    @Test
    void firstAssignmentAddsQuietly() {
        user(1L);
        roomExists();
        when(rooms.addMemberQuietly(RoomKind.DEPARTMENT, 7L, 1L)).thenReturn(AutoAdd.ADDED);
        assertEquals(AutoJoinResult.ADDED, svc.autoJoinOwn(1L));
    }

    @Test
    void optedOutUserIsNeverReAdded() {
        user(1L);
        roomExists();
        when(optouts.existsByUserIdAndDeptKey(1L, key())).thenReturn(true);
        assertEquals(AutoJoinResult.OPTED_OUT, svc.autoJoinOwn(1L));
        verify(rooms, never()).addMemberQuietly(any(), anyLong(), anyLong());
    }

    @Test
    void fullRoomDoesNotThrow() {
        user(1L);
        roomExists();
        when(rooms.addMemberQuietly(RoomKind.DEPARTMENT, 7L, 1L)).thenReturn(AutoAdd.FULL);
        assertEquals(AutoJoinResult.FULL, svc.autoJoinOwn(1L));
    }

    @Test
    void unverifiedOrNoDepartmentSkipped() {
        User u = user(1L);
        u.setEmailVerified(false);
        assertEquals(AutoJoinResult.SKIPPED, svc.autoJoinOwn(1L));
        User v = user(2L);
        v.setDepartment(null);
        assertEquals(AutoJoinResult.SKIPPED, svc.autoJoinOwn(2L));
    }

    @Test
    void leavingRecordsOptOutAndManualJoinClearsIt() {
        user(1L);
        roomExists();
        when(rooms.removeMember(RoomKind.DEPARTMENT, 7L, 1L)).thenReturn(true);
        svc.leave(1L);
        verify(optouts).save(any(DepartmentChatOptout.class));
        when(rooms.addMember(RoomKind.DEPARTMENT, 7L, 1L)).thenReturn(true);
        svc.join(1L);
        verify(optouts).deleteOne(eq(1L), eq(key()));
    }

    @Test
    void backfillIsIdempotentAndResumesFromCursor() {
        AppSettingRepository settings = mock(AppSettingRepository.class);
        SchedulerLock lock = mock(SchedulerLock.class);
        DepartmentChatService s = mock(DepartmentChatService.class);
        AppSetting cursor = new AppSetting();
        cursor.setKey(DepartmentChatBackfillJob.CURSOR_KEY);
        cursor.setValue("10");
        when(settings.findById(DepartmentChatBackfillJob.CURSOR_KEY)).thenReturn(Optional.of(cursor));
        when(settings.findById(DepartmentChatBackfillJob.DONE_KEY)).thenReturn(Optional.empty());
        when(users.deptUserIdsAfter(eq(10L), any(Pageable.class))).thenReturn(List.of(11L, 12L));
        when(users.deptUserIdsAfter(eq(12L), any(Pageable.class))).thenReturn(List.of());
        when(s.autoJoinOwn(anyLong())).thenReturn(AutoJoinResult.ADDED);
        new DepartmentChatBackfillJob(s, users, settings, lock, true, 0).runAll();
        verify(s).autoJoinOwn(11L);
        verify(s).autoJoinOwn(12L);
        verify(s, never()).autoJoinOwn(10L);
        verify(settings, org.mockito.Mockito.atLeastOnce()).save(any(AppSetting.class));
    }
}
