package edu.bingol.backend.messaging.room.dept;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.DepartmentChatView;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class DepartmentChatServiceTest {

    private final RoomConversations rooms = mock(RoomConversations.class);
    private final DepartmentChatRoomRepository depts = mock(DepartmentChatRoomRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final DepartmentChatService svc = new DepartmentChatService(rooms, depts, users, new edu.bingol.backend.catalog.CatalogService());

    private User user(long id, String dept, Role role) {
        User u = new User();
        u.setId(id);
        u.setDepartment(dept);
        u.setRole(role);
        when(users.findById(id)).thenReturn(Optional.of(u));
        return u;
    }

    private DepartmentChatRoom room(long id, String key) {
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(id);
        r.setDeptKey(key);
        r.setName("Bilgisayar Mühendisliği");
        when(depts.findByDeptKey(key)).thenReturn(Optional.of(r));
        return r;
    }

    @Test
    void getWithoutDepartmentIsUnavailable() {
        user(1L, null, Role.USER);
        DepartmentChatView v = svc.get(1L);
        assertFalse(v.available());
        assertNull(v.conversationId());
    }

    @Test
    void getBeforeRoomExistsIsAvailableButNotJoined() {
        user(1L, "Bilgisayar Mühendisliği", Role.USER);
        when(depts.findByDeptKey(any())).thenReturn(Optional.empty());
        DepartmentChatView v = svc.get(1L);
        assertTrue(v.available());
        assertFalse(v.joined());
        assertEquals(0, v.memberCount());
    }

    @Test
    void joinRequiresDepartment() {
        user(1L, "  ", Role.USER);
        ApiException e = assertThrows(ApiException.class, () -> svc.join(1L));
        assertEquals("DEPARTMENT_REQUIRED", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());
    }

    @Test
    void joinCreatesRoomWithAdminOwnerAndAddsMember() {
        user(5L, "Bilgisayar Mühendisliği", Role.USER);
        User admin = new User();
        admin.setId(99L);
        admin.setRole(Role.ADMIN);
        when(users.findAllAdmins()).thenReturn(List.of(admin));
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        r.setName("Bilgisayar Mühendisliği");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        RoomInfo info = new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, false);
        when(rooms.find(RoomKind.DEPARTMENT, 7L)).thenReturn(Optional.empty(), Optional.of(info));
        when(rooms.addMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);
        when(rooms.isMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);
        when(rooms.memberCount(RoomKind.DEPARTMENT, 7L)).thenReturn(2L);

        DepartmentChatView v = svc.join(5L);

        verify(rooms).ensureRoom(eq(RoomKind.DEPARTMENT), eq(7L), any(), eq(99L));
        assertTrue(v.joined());
        assertEquals(300L, v.conversationId());
        assertEquals(2L, v.memberCount());
    }

    @Test
    void joinReopensLegacyClosedRoomInsteadOfRejecting() {
        user(5L, "Bilgisayar Mühendisliği", Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        r.setName("x");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, true)));
        when(rooms.addMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);
        DepartmentChatView v = svc.join(5L);
        verify(rooms).openRoom(RoomKind.DEPARTMENT, 7L, List.of());
        verify(rooms).addMember(RoomKind.DEPARTMENT, 7L, 5L);
        assertFalse(v.closed());
    }

    @Test
    void adminCannotCloseDepartmentRoom() {
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        when(depts.findById(7L)).thenReturn(Optional.of(r));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, false)));
        ApiException e = assertThrows(ApiException.class, () -> svc.adminSetClosed(7L, true));
        assertEquals("DEPT_ROOM_CANNOT_CLOSE", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());
        verify(rooms, never()).closeRoom(any(), anyLong());
    }

    @Test
    void leaveRemovesMembership() {
        user(5L, "Bilgisayar Mühendisliği", Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        svc.leave(5L);
        verify(rooms).removeMember(RoomKind.DEPARTMENT, 7L, 5L);
    }

    @Test
    void canJoinAnotherDepartmentWithoutChangingProfile() {
        User u = user(5L, "Hukuk", Role.USER);
        DepartmentChatRoom r = room(7L, edu.bingol.backend.unitnews.UnitKeys.deptKey("Bilgisayar Mühendisliği"));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, false)));
        when(rooms.addMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);
        when(rooms.isMember(RoomKind.DEPARTMENT, 7L, 5L)).thenReturn(true);

        DepartmentChatView v = svc.join(5L, "Bilgisayar Mühendisliği");

        assertTrue(v.joined());
        assertEquals(r.getName(), v.departmentName());
        assertEquals("Hukuk", u.getDepartment());
    }

    @Test
    void rejectsDepartmentOutsideCatalog() {
        user(5L, "Hukuk", Role.USER);
        assertThrows(ApiException.class, () -> svc.join(5L, "uydurma bölüm"));
        verify(rooms, never()).addMember(any(), anyLong(), anyLong());
    }

    @Test
    void canLeaveAnotherDepartmentByConversationIdWithoutProfileDepartment() {
        user(5L, null, Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        when(depts.findByConversationId(300L)).thenReturn(Optional.of(r));
        svc.leave(5L, 300L);
        verify(rooms).removeMember(RoomKind.DEPARTMENT, 7L, 5L);
    }

    @Test
    void joinAllowsDepartmentOfActiveUserOutsideCatalog() {
        user(5L, "Hukuk", Role.USER);
        when(users.existsActiveDepartment("Spor Medyası")).thenReturn(true);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(8L);
        r.setName("Spor Medyası");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        when(rooms.find(RoomKind.DEPARTMENT, 8L))
                .thenReturn(Optional.of(new RoomInfo(310L, RoomKind.DEPARTMENT, 8L, false)));
        when(rooms.addMember(RoomKind.DEPARTMENT, 8L, 5L)).thenReturn(true);
        when(rooms.isMember(RoomKind.DEPARTMENT, 8L, 5L)).thenReturn(true);
        assertTrue(svc.join(5L, "Spor Medyası").joined());
    }

    private void usersDepts(String... names) {
        when(users.pageActiveDepartments(any(), any())).thenAnswer(inv -> {
            String after = inv.getArgument(0);
            org.springframework.data.domain.Pageable pg = inv.getArgument(1);
            return java.util.Arrays.stream(names).filter(n -> n.compareTo(after) > 0).sorted()
                    .limit(pg.getPageSize()).toList();
        });
    }

    @Test
    void browseListsOnlyDepartmentsOfRealUsersWithBatchRoomLookup() {
        user(5L, null, Role.USER);
        usersDepts("Hukuk", "Spor Medyası");
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(7L);
        r.setDeptKey(edu.bingol.backend.unitnews.UnitKeys.deptKey("Hukuk"));
        r.setName("Hukuk");
        when(depts.findByDeptKeyIn(any())).thenReturn(List.of(r));
        when(rooms.stats(eq(RoomKind.DEPARTMENT), any(), eq(5L))).thenReturn(java.util.Map.of(7L,
                new RoomConversations.RoomStat(300L, false, 4L, true)));
        var result = svc.browse(5L, null, null, null);
        assertEquals(2, result.size());
        assertEquals("Hukuk", result.get(0).departmentName());
        assertTrue(result.get(0).joined());
        assertEquals(4L, result.get(0).memberCount());
        assertEquals(300L, result.get(0).conversationId());
        assertEquals("Spor Medyası", result.get(1).departmentName());
        assertFalse(result.get(1).joined());
        verify(rooms, never()).find(any(), anyLong()); // N+1 yok
        verify(rooms, never()).memberCount(any(), anyLong());
    }

    @Test
    void browseKeysetPagesAndCapsSize() {
        user(5L, null, Role.USER);
        String[] names = new String[120];
        for (int i = 0; i < names.length; i++) names[i] = String.format("Bölüm %03d", i);
        usersDepts(names);
        var p1 = svc.browse(5L, 1000, null, null); // tavan 50
        assertEquals(50, p1.size());
        var p2 = svc.browse(5L, 50, p1.get(49).departmentName(), null);
        assertEquals(50, p2.size());
        assertEquals("Bölüm 050", p2.get(0).departmentName());
        var p3 = svc.browse(5L, 50, p2.get(49).departmentName(), null);
        assertEquals(20, p3.size()); // son sayfa: dönen sayı < size
        assertEquals(30, svc.browse(5L, null, null, null).size()); // varsayilan 30
    }

    @Test
    void browseSearchIsTurkishAwareAndLikeCharsAreLiteral() {
        user(5L, null, Role.USER);
        usersDepts("İşletme", "Bilgisayar Mühendisliği", "Hukuk 100%", "Hukuk 100x");
        assertEquals(List.of("İşletme"), svc.browse(5L, null, null, "isletme").stream().map(DepartmentChatView::departmentName).toList());
        assertEquals(List.of("Bilgisayar Mühendisliği"),
                svc.browse(5L, null, null, "MUHENDİS").stream().map(DepartmentChatView::departmentName).toList());
        assertEquals(List.of("Hukuk 100%"), svc.browse(5L, null, null, "100%").stream().map(DepartmentChatView::departmentName).toList());
        assertTrue(svc.browse(5L, null, null, "zzz").isEmpty());
    }

    @Test
    void browseSkipsBlankAndDedupesSpellingVariants() {
        user(5L, null, Role.USER);
        usersDepts("Hukuk", "Hukuk Bölümü", "  ");
        assertEquals(1, svc.browse(5L, null, null, null).size());
    }

    @Test
    void signupJoinsOwnDepartment() {
        user(5L, "Hukuk", Role.USER);
        room(7L, edu.bingol.backend.unitnews.UnitKeys.deptKey("Hukuk"));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, false)));
        svc.joinOnSignup(5L);
        verify(rooms).addMemberIfSpace(RoomKind.DEPARTMENT, 7L, 5L);
    }

    @Test
    void closedDepartmentIsReopenedOnSignup() {
        user(5L, "Hukuk", Role.USER);
        room(7L, edu.bingol.backend.unitnews.UnitKeys.deptKey("Hukuk"));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, true)));
        svc.joinOnSignup(5L);
        verify(rooms).openRoom(RoomKind.DEPARTMENT, 7L, List.of());
        verify(rooms).addMemberIfSpace(RoomKind.DEPARTMENT, 7L, 5L);
    }

    @Test
    void firstUserOfDepartmentCreatesRoomAndSecondReusesIt() {
        user(5L, "Spor Medyası", Role.USER);
        user(6L, "Spor Medyası", Role.USER);
        DepartmentChatRoom r = new DepartmentChatRoom();
        r.setId(9L);
        r.setName("Spor Medyası");
        when(depts.findByDeptKey(any())).thenReturn(Optional.of(r));
        when(rooms.find(RoomKind.DEPARTMENT, 9L)).thenReturn(Optional.empty(),
                Optional.of(new RoomInfo(320L, RoomKind.DEPARTMENT, 9L, false)));
        svc.joinOnSignup(5L);
        svc.joinOnSignup(6L);
        verify(rooms, org.mockito.Mockito.times(1)).ensureRoom(eq(RoomKind.DEPARTMENT), eq(9L), any(), anyLong());
        verify(rooms).addMemberIfSpace(RoomKind.DEPARTMENT, 9L, 5L);
        verify(rooms).addMemberIfSpace(RoomKind.DEPARTMENT, 9L, 6L);
    }

    @Test
    void firstDepartmentAssignmentJoinsRoom() {
        user(5L, "Spor Medyası", Role.USER);
        room(7L, edu.bingol.backend.unitnews.UnitKeys.deptKey("Spor Medyası"));
        when(rooms.find(RoomKind.DEPARTMENT, 7L))
                .thenReturn(Optional.of(new RoomInfo(300L, RoomKind.DEPARTMENT, 7L, false)));
        svc.joinOnFirstDepartment(5L, "Spor Medyası");
        verify(rooms).addMemberIfSpace(RoomKind.DEPARTMENT, 7L, 5L);
    }

    @Test
    void sameDepartmentSpellingVariantsShareOneKey() {
        user(1L, "Bilgisayar Mühendisliği Bölümü", Role.USER);
        user(2L, "bilgisayar muhendisligi (İkinci Öğretim)", Role.USER);
        when(depts.findByDeptKey(any())).thenReturn(Optional.empty());
        svc.get(1L);
        svc.get(2L);
        org.mockito.ArgumentCaptor<String> k = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(depts, org.mockito.Mockito.times(2)).findByDeptKey(k.capture());
        assertEquals(k.getAllValues().get(0), k.getAllValues().get(1));
    }

    @Test
    void onlyFullOrModeratorAdminsModerate() {
        UserRepository repo = mock(UserRepository.class);
        DepartmentRoomModerators m = new DepartmentRoomModerators(repo);
        User admin = new User();
        admin.setId(1L);
        admin.setRole(Role.ADMIN);
        User viewer = new User();
        viewer.setId(2L);
        viewer.setRole(Role.ADMIN);
        viewer.setAdminProfile(AdminProfile.VIEWER);
        User plain = new User();
        plain.setId(3L);
        plain.setRole(Role.USER);
        when(repo.findById(1L)).thenReturn(Optional.of(admin));
        when(repo.findById(2L)).thenReturn(Optional.of(viewer));
        when(repo.findById(3L)).thenReturn(Optional.of(plain));
        assertTrue(m.canModerate(7L, 1L));
        assertFalse(m.canModerate(7L, 2L));
        assertFalse(m.canModerate(7L, 3L));
        assertEquals(RoomKind.DEPARTMENT, m.kind());
    }
}
