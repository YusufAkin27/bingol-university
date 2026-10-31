package edu.bingol.backend.profile.privacy;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.messaging.Conversation;
import edu.bingol.backend.messaging.ConversationMember;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.ConversationRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * PGVERIFY: bekleyen (PENDING) mesaj istegi "ortak baglam" sayilmaz. Aksi halde herhangi biri hedefe DM istegi acarak
 * SHARED_CONTEXT alanlarini (bolum, biyografi, avatar, cevrimici durum) kabul beklemeden gorebilirdi.
 */
@SpringBootTest
class SharedContextRequestStateTest {

    @Autowired SharedContextRepository shared;
    @Autowired UserRepository users;
    @Autowired ConversationRepository conversations;
    @Autowired ConversationMemberRepository members;

    private User user() {
        User u = new User();
        u.setEmail("sc" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Baglam Kullanici");
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    private Long conversationWith(User creator, User peer, ConversationMember.RequestState peerState) {
        Conversation c = new Conversation();
        c.setType(Conversation.Type.DIRECT);
        c.setDirectKey(Conversation.directKey(creator.getId(), peer.getId()));
        c.setCreatedBy(creator.getId());
        c = conversations.saveAndFlush(c);
        members.saveAndFlush(ConversationMember.of(c.getId(), creator.getId(), ConversationMember.Role.MEMBER));
        ConversationMember pm = ConversationMember.of(c.getId(), peer.getId(), ConversationMember.Role.MEMBER);
        pm.setRequestState(peerState);
        members.saveAndFlush(pm);
        return c.getId();
    }

    @Test
    void pendingRequestIsNotSharedContextUntilAccepted() {
        User sender = user();
        User target = user();
        Long cid = conversationWith(sender, target, ConversationMember.RequestState.PENDING);

        assertEquals(Set.of(), shared.sharedWith(sender.getId(), List.of(target.getId())));
        assertEquals(Set.of(), shared.sharedWith(target.getId(), List.of(sender.getId())));
        assertEquals(Set.of(), shared.viewersSharingWith(target.getId(), List.of(sender.getId())));

        ConversationMember pm = members.findByConversationIdAndUserIdAndLeftAtIsNull(cid, target.getId()).orElseThrow();
        pm.setRequestState(ConversationMember.RequestState.ACCEPTED);
        members.saveAndFlush(pm);

        assertTrue(shared.sharedWith(sender.getId(), List.of(target.getId())).contains(target.getId()));
        assertTrue(shared.viewersSharingWith(target.getId(), List.of(sender.getId())).contains(sender.getId()));
    }

    @Test
    void declinedRequestIsNotSharedContext() {
        User sender = user();
        User target = user();
        conversationWith(sender, target, ConversationMember.RequestState.DECLINED);
        assertFalse(shared.sharedWith(sender.getId(), List.of(target.getId())).contains(target.getId()));
    }
}
