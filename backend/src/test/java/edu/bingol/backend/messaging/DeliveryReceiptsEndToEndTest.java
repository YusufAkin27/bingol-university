package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReceiptEvent;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * Teslim tikleri uc uca, IKI GERCEK HESAPLA (H2 + gercek servisler): gonder -> SENT -> alici istemci "iletildi" yazar ->
 * gonderen GET'te DELIVERED + gonderenin kuyruguna olay -> alici okur -> READ. Geri dusmeme, yetkisiz (ucuncu kisi,
 * gonderenin kendisi) sahte yazamaz, yinelenen cagri idempotent (olay tekrarlanmaz), zaman damgalari bir kez yazilir.
 * Yalniz WebSocket kopru (Redis) ve hiz siniri sahte; durum modeli ve sorgular gercek.
 */
@SpringBootTest
class DeliveryReceiptsEndToEndTest {

    /** `conversation_key` tablosu H2'de yok (Flyway kapali): mesaj sifreleme anahtarlari bellekte tutulur. */
    @org.springframework.boot.test.context.TestConfiguration
    static class MemoryKeys {
        @org.springframework.context.annotation.Bean
        @org.springframework.context.annotation.Primary
        edu.bingol.backend.crypto.ConversationKeyStore memoryKeyStore() {
            return new edu.bingol.backend.crypto.ConversationKeyStore() {
                final java.util.Map<String, StoredKey> map = new java.util.concurrent.ConcurrentHashMap<>();

                public java.util.Optional<StoredKey> find(long cid, int version) {
                    return java.util.Optional.ofNullable(map.get(cid + ":" + version));
                }

                public java.util.Optional<StoredKey> findActive(long cid) {
                    return map.values().stream().filter(k -> k.conversationId() == cid && k.active())
                            .max(java.util.Comparator.comparingInt(StoredKey::version));
                }

                public boolean insert(StoredKey k) {
                    return map.putIfAbsent(k.conversationId() + ":" + k.version(), k) == null;
                }

                public List<StoredKey> pageNotWrappedBy(String id, long after, int v, int limit) {
                    return List.of();
                }

                public boolean rewrap(long cid, int version, String o, String n, byte[] w) {
                    return false;
                }

                public java.util.Map<String, Long> countsByMasterKey() {
                    return java.util.Map.of();
                }
            };
        }
    }

    @Autowired UserRepository users;
    @Autowired ConversationService conversations;
    @Autowired MessageService messages;
    @Autowired ReceiptService receipts;
    @Autowired ConversationMemberRepository members;
    @Autowired MessageRepository messageRepo;
    @Autowired ConversationRepository convRepo;

    @MockitoBean ChatEventBus bus;
    @MockitoBean RateLimiter limiter;

    User user(String prefix) {
        User u = new User();
        u.setEmail(prefix + "-" + UUID.randomUUID() + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(prefix);
        u.setEmailVerified(true);
        u.setRole(Role.USER);
        return users.save(u);
    }

    String statusOf(Long viewer, Long cid, Long messageId) {
        return messages.history(viewer, cid, null, null, 30).items().stream()
                .filter(m -> m.id().equals(messageId)).findFirst().orElseThrow().status();
    }

    /** Birebir konusma: `openDirect` PostgreSQL'e ozel (ON CONFLICT) oldugundan H2'de depolarla kurulur. */
    Long openDirect(User a, User b) {
        Conversation c = new Conversation();
        c.setType(Conversation.Type.DIRECT);
        c.setDirectKey(Conversation.directKey(a.getId(), b.getId()));
        c.setCreatedBy(a.getId());
        c = convRepo.saveAndFlush(c);
        members.save(ConversationMember.of(c.getId(), a.getId(), ConversationMember.Role.MEMBER));
        members.save(ConversationMember.of(c.getId(), b.getId(), ConversationMember.Role.MEMBER));
        return c.getId();
    }

    @SuppressWarnings("unchecked")
    ReceiptEvent lastReceiptEventTo(Long owner, int times) {
        ArgumentCaptor<Object> payload = ArgumentCaptor.forClass(Object.class);
        verify(bus, org.mockito.Mockito.times(times)).publish(eq("message-events"), eq(List.of(owner)), payload.capture());
        return (ReceiptEvent) payload.getValue();
    }

    @Test
    void sentThenDeliveredThenReadWithEventsToTheSender() {
        User a = user("gonderen");
        User b = user("alici");
        Long cid = openDirect(a, b);

        MessageView sent = messages.send(a.getId(), cid, "merhaba", UUID.randomUUID().toString()).message();
        assertEquals("SENT", statusOf(a.getId(), cid, sent.id()), "sunucuya kaydedilmek teslim DEGILDIR");
        assertNull(messageRepo.findById(sent.id()).orElseThrow().getDeliveredAt());

        clearInvocations(bus);
        // Alici istemci mesaji aldi ve kendi adina "iletildi" yazdi
        receipts.markDelivered(b.getId(), cid, sent.id());
        assertEquals("DELIVERED", statusOf(a.getId(), cid, sent.id()));
        assertNotNull(messageRepo.findById(sent.id()).orElseThrow().getDeliveredAt());
        ReceiptEvent ev = lastReceiptEventTo(a.getId(), 1); // olay GONDERENin kuyruguna gitti
        assertEquals("delivered", ev.kind());
        assertEquals(sent.id(), ev.upToMessageId());
        assertEquals("DELIVERED", ev.status());
        assertEquals(b.getId(), ev.userId());

        // Yinelenen cagri (yeniden baglanma / cift gonderim): idempotent, ikinci olay yok, durum ayni
        receipts.markDelivered(b.getId(), cid, sent.id());
        receipts.markDelivered(b.getId(), cid, sent.id());
        verify(bus, org.mockito.Mockito.times(1)).publish(eq("message-events"), anyCollection(), any());
        assertEquals("DELIVERED", statusOf(a.getId(), cid, sent.id()));
        // Alicinin kendi gorunumunde gonderen mesajinin durumu yok (yalniz kendi mesajlarinin tiki)
        assertNull(statusOf(b.getId(), cid, sent.id()));

        // Alici okudu: READ + 'read' olayi
        messages.markRead(b.getId(), cid, sent.id());
        assertEquals("READ", statusOf(a.getId(), cid, sent.id()));
        assertNotNull(messageRepo.findById(sent.id()).orElseThrow().getReadAt());
        ReceiptEvent read = lastReceiptEventTo(a.getId(), 2);
        assertEquals("read", read.kind());
        assertEquals("READ", read.status());

        // Okundudan sonra gelen gec "iletildi" geri dusurmez
        receipts.markDelivered(b.getId(), cid, sent.id());
        assertEquals("READ", statusOf(a.getId(), cid, sent.id()));
    }

    @Test
    void readImpliesDeliveredEvenIfDeliveredAckNeverArrived() {
        User a = user("g2");
        User b = user("a2");
        Long cid = openDirect(a, b);
        MessageView m1 = messages.send(a.getId(), cid, "bir", UUID.randomUUID().toString()).message();
        messages.markRead(b.getId(), cid, m1.id()); // iletildi ack'i hic gelmedi
        assertEquals("READ", statusOf(a.getId(), cid, m1.id()));
        assertNotNull(messageRepo.findById(m1.id()).orElseThrow().getDeliveredAt(), "okundu = iletildi de yazilir");
    }

    @Test
    void ackCoversOnlyMessagesUpToTheCursorAndNeverMixesConversations() {
        User a = user("g3");
        User b = user("a3");
        User c = user("c3");
        Long cid = openDirect(a, b);
        Long other = openDirect(a, c);
        MessageView m1 = messages.send(a.getId(), cid, "bir", UUID.randomUUID().toString()).message();
        MessageView m2 = messages.send(a.getId(), cid, "iki", UUID.randomUUID().toString()).message();
        MessageView o1 = messages.send(a.getId(), other, "baska sohbet", UUID.randomUUID().toString()).message();

        receipts.markDelivered(b.getId(), cid, m1.id());
        assertEquals("DELIVERED", statusOf(a.getId(), cid, m1.id()));
        assertEquals("SENT", statusOf(a.getId(), cid, m2.id()), "imlecin otesindeki mesaj teslim sayilmaz");
        assertEquals("SENT", statusOf(a.getId(), other, o1.id()), "baska konusma / baska alici etkilenmez");
    }

    @Test
    void outsiderAndSenderCannotForgeReceipts() {
        User a = user("g4");
        User b = user("a4");
        User outsider = user("x4");
        Long cid = openDirect(a, b);
        MessageView m = messages.send(a.getId(), cid, "gizli", UUID.randomUUID().toString()).message();
        clearInvocations(bus);

        // Ucuncu kisi: konusma uyesi degil -> 404, hicbir sey yazilmaz
        ApiException ex = assertThrows(ApiException.class, () -> receipts.markDelivered(outsider.getId(), cid, m.id()));
        assertEquals("CONVERSATION_NOT_FOUND", ex.code());
        assertThrows(ApiException.class, () -> messages.markRead(outsider.getId(), cid, m.id()));
        // Gonderenin kendisi: kendi mesajini "iletildi" yapamaz (no-op, olay yok)
        receipts.markDelivered(a.getId(), cid, m.id());

        assertEquals("SENT", statusOf(a.getId(), cid, m.id()));
        verify(bus, never()).publish(eq("message-events"), anyCollection(), any());
        assertNull(messageRepo.findById(m.id()).orElseThrow().getDeliveredAt());
    }

    @Test
    void conversationListFetchByRecipientMarksLastUnreadMessageDelivered() {
        User a = user("g5");
        User b = user("a5");
        Long cid = openDirect(a, b);
        MessageView m = messages.send(a.getId(), cid, "liste", UUID.randomUUID().toString()).message();
        // Alicinin istemcisi sohbet listesini cekti (uygulama baska ekranda): cihazda demektir
        var page = conversations.list(b.getId(), null, 20, false);
        receipts.markListedDelivered(b.getId(), page.items());
        assertEquals("DELIVERED", statusOf(a.getId(), cid, m.id()));
        // Gonderenin kendi listesini cekmesi hicbir sey yazmaz
        User a2 = user("g6");
        User b2 = user("a6");
        Long cid2 = openDirect(a2, b2);
        MessageView m2 = messages.send(a2.getId(), cid2, "x", UUID.randomUUID().toString()).message();
        receipts.markListedDelivered(a2.getId(), conversations.list(a2.getId(), null, 20, false).items());
        assertEquals("SENT", statusOf(a2.getId(), cid2, m2.id()));
    }
}
