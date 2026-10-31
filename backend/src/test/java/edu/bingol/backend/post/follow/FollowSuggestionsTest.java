package edu.bingol.backend.post.follow;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * T-024: takip onerileri (aday havuzu CTE + kullanici basina onbellek). Siralama CLUB > GRADE > DEPARTMENT; takip edilen,
 * engelli, pasif ve kendisi haric; onbellek takip/engel degisikligini okuma aninda suzdugu icin bayatlamaz.
 */
@SpringBootTest
class FollowSuggestionsTest {

    @Autowired FollowService follow;
    @Autowired UserRepository users;
    @Autowired UserBlockRepository blocks;
    @Autowired CommunityRepository communities;
    @Autowired CommunityMemberRepository members;

    private static String tag() {
        return UUID.randomUUID().toString().substring(0, 8);
    }

    private User user(String dept, Integer classYear) {
        User u = new User();
        u.setEmail("sg" + tag() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Oneri " + tag());
        u.setEmailVerified(true);
        u.setDepartment(dept);
        u.setClassYear(classYear == null ? null : classYear.shortValue());
        return users.saveAndFlush(u);
    }

    private Community club(User owner) {
        Community c = new Community();
        c.setName("Oneri Kulubu " + tag());
        c.setSlug("sg-" + tag());
        c.setOwnerId(owner.getId());
        c.setStatus(Community.Status.ACTIVE);
        c.setCategory("Spor");
        communities.save(c);
        members.save(new CommunityMember(c.getId(), owner.getId(), CommunityMember.Role.OWNER,
                CommunityMember.Status.ACTIVE));
        return c;
    }

    private static String reasonOf(List<FollowService.Suggestion> list, User u) {
        return list.stream().filter(s -> s.id().equals(u.getId())).map(FollowService.Suggestion::reason).findFirst()
                .orElse(null);
    }

    @Test
    void ordersClubThenGradeThenDepartmentAndExcludesIneligible() {
        String dept = "Bolum-" + tag();
        User me = user(dept, 2);
        User clubMate = user("Baska-" + tag(), 4); // farkli bolum ama ayni kulup
        User grade = user(dept, 2);
        User sameDept = user(dept, 3);
        User noDept = user("Digeri-" + tag(), 2);
        User suspended = user(dept, 2);
        suspended.setStatus(UserStatus.SUSPENDED);
        users.saveAndFlush(suspended);
        User unverified = user(dept, 2);
        unverified.setEmailVerified(false);
        users.saveAndFlush(unverified);
        Community c = club(clubMate);
        members.save(new CommunityMember(c.getId(), me.getId(), CommunityMember.Role.MEMBER,
                CommunityMember.Status.ACTIVE));

        List<FollowService.Suggestion> out = follow.suggestions(me.getId(), 20);

        assertEquals("CLUB", reasonOf(out, clubMate));
        assertEquals("GRADE", reasonOf(out, grade));
        assertEquals("DEPARTMENT", reasonOf(out, sameDept));
        assertEquals(null, reasonOf(out, noDept));
        assertEquals(null, reasonOf(out, suspended));
        assertEquals(null, reasonOf(out, unverified));
        assertEquals(null, reasonOf(out, me));
        int iClub = idx(out, clubMate);
        int iGrade = idx(out, grade);
        int iDept = idx(out, sameDept);
        assertTrue(iClub < iGrade && iGrade < iDept, "sira CLUB, GRADE, DEPARTMENT: " + out);
    }

    private static int idx(List<FollowService.Suggestion> l, User u) {
        for (int i = 0; i < l.size(); i++) {
            if (l.get(i).id().equals(u.getId())) {
                return i;
            }
        }
        return -1;
    }

    @Test
    void cachedListDropsLaterFollowedAndBlockedCandidates() {
        String dept = "Onbellek-" + tag();
        User me = user(dept, null);
        User a = user(dept, null);
        User b = user(dept, null);
        User c = user(dept, null);

        List<FollowService.Suggestion> first = follow.suggestions(me.getId(), 10); // onbellegi doldurur
        assertTrue(reasonOf(first, a) != null && reasonOf(first, b) != null && reasonOf(first, c) != null);

        follow.follow(me.getId(), a.getId());
        blocks.saveAndFlush(new UserBlock(me.getId(), b.getId()));
        List<FollowService.Suggestion> second = follow.suggestions(me.getId(), 10);

        assertFalse(reasonOf(second, a) != null, "sonradan takip edilen onerilmez");
        assertFalse(reasonOf(second, b) != null, "sonradan engellenen onerilmez");
        assertTrue(reasonOf(second, c) != null);
    }

    @Test
    void sizeIsRespectedAndEmptyForUserWithoutDepartmentOrClubs() {
        User lonely = user(null, null);
        assertTrue(follow.suggestions(lonely.getId(), 10).isEmpty());

        String dept = "Boyut-" + tag();
        User me = user(dept, null);
        for (int i = 0; i < 5; i++) {
            user(dept, null);
        }
        assertEquals(3, follow.suggestions(me.getId(), 3).size());
    }
}
