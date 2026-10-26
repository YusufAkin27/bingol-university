package edu.bingol.backend.crypto;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crypto.AdminDecryptService.Request;
import edu.bingol.backend.crypto.MessageReader.SealedMessage;
import java.nio.ByteBuffer;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class AdminDecryptServiceTest {

    private final CryptoTestSupport t = new CryptoTestSupport();
    private final EnvelopeMessageCipher cipher =
            t.cipher(t.keyService(CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(1), "")));
    private final MessageAccessAuditRepository audit = new MessageAccessAuditRepository(t.jdbc);

    private static byte[] ctx(long id) {
        return ByteBuffer.allocate(8).putLong(id).array();
    }

    /** Bellek ici sahte okuyucu: 1..n mesaj. */
    private MessageReader reader(long cid, int n) {
        List<SealedMessage> all = new ArrayList<>();
        for (long i = 1; i <= n; i++) {
            all.add(new SealedMessage(i, 5, Instant.EPOCH, ctx(i), cipher.encryptText(cid, ctx(i), "mesaj " + i)));
        }
        return (c, from, to, limit) -> c != cid ? List.of()
                : all.stream().filter(m -> m.messageId() >= from && m.messageId() <= to).limit(limit).toList();
    }

    private AdminDecryptService svc(MessageReader r, boolean enabled, int max) {
        return new AdminDecryptService(CryptoTestSupport.props("", "", enabled, max), Optional.ofNullable(r), cipher, audit);
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    private int auditRows() {
        return t.jdbc.queryForObject("SELECT COUNT(*) FROM message_access_audit", Integer.class);
    }

    @Test
    void decryptsRangeAndWritesAuditRow() {
        var s = svc(reader(3, 10), true, 200);
        var res = s.decrypt(7, new Request(3L, 2L, 4L, "  sikayet #123 incelemesi  "), "10.0.0.9");
        assertEquals(3, res.count());
        assertEquals("mesaj 2", res.messages().get(0).text());
        assertEquals("mesaj 4", res.messages().get(2).text());
        var row = t.jdbc.queryForMap("SELECT * FROM message_access_audit WHERE id = " + res.auditId());
        assertEquals(7L, ((Number) row.get("ADMIN_ID")).longValue());
        assertEquals(3L, ((Number) row.get("CONVERSATION_ID")).longValue());
        assertEquals(3, ((Number) row.get("MESSAGE_COUNT")).intValue());
        assertEquals("sikayet #123 incelemesi", row.get("REASON"));
        assertEquals("10.0.0.9", row.get("IP"));
        // Tek mesaj: to bos
        assertEquals(1, s.decrypt(7, new Request(3L, 5L, null, "gerekce yeterince uzun"), "ip").count());
        assertEquals(2, auditRows());
    }

    @Test
    void shortOrMissingReasonIsRejectedAndNothingIsLogged() {
        var s = svc(reader(3, 3), true, 200);
        for (String reason : new String[] {null, "", "kisa", "         x         ", "123456789"}) {
            assertEquals("DECRYPT_REASON_REQUIRED", code(() -> s.decrypt(1, new Request(3L, 1L, 1L, reason), "ip")));
        }
        assertEquals(0, auditRows());
    }

    @Test
    void disabledSettingBlocksEverything() {
        var s = svc(reader(3, 3), false, 200);
        assertEquals("ADMIN_DECRYPT_DISABLED", code(() -> s.decrypt(1, new Request(3L, 1L, 1L, "yeterince uzun gerekce"), "ip")));
        assertEquals(0, auditRows());
    }

    @Test
    void invalidRangeAndTooManyAreRejected() {
        var s = svc(reader(3, 10), true, 5);
        String r = "yeterince uzun gerekce";
        assertEquals("DECRYPT_RANGE_INVALID", code(() -> s.decrypt(1, new Request(null, 1L, 1L, r), "ip")));
        assertEquals("DECRYPT_RANGE_INVALID", code(() -> s.decrypt(1, new Request(3L, null, null, r), "ip")));
        assertEquals("DECRYPT_RANGE_INVALID", code(() -> s.decrypt(1, new Request(3L, 5L, 2L, r), "ip")));
        assertEquals("DECRYPT_TOO_MANY", code(() -> s.decrypt(1, new Request(3L, 1L, 10L, r), "ip")));
        assertEquals(5, s.decrypt(1, new Request(3L, 1L, 5L, r), "ip").count());
        assertEquals(1, auditRows());
    }

    @Test
    void withoutReaderReturns501() {
        var s = svc(null, true, 200);
        assertEquals("MESSAGE_READER_UNAVAILABLE", code(() -> s.decrypt(1, new Request(3L, 1L, 1L, "yeterince uzun gerekce"), "ip")));
        assertEquals(0, auditRows());
    }

    @Test
    void undecryptableMessageIsReportedWithoutLeakingAndStillAudited() {
        MessageReader good = reader(3, 2);
        MessageReader tampered = (c, f, to, l) -> {
            List<SealedMessage> l2 = new ArrayList<>(good.read(c, f, to, l));
            SealedMessage m = l2.get(0);
            byte[] ct = m.sealed().ciphertext().clone();
            ct[0] ^= 1;
            l2.set(0, new SealedMessage(m.messageId(), m.senderId(), m.createdAt(), m.contextBytes(),
                    new Sealed(ct, m.sealed().nonce(), m.sealed().keyVersion())));
            return l2;
        };
        var res = svc(tampered, true, 200).decrypt(1, new Request(3L, 1L, 2L, "yeterince uzun gerekce"), "ip");
        assertNull(res.messages().get(0).text());
        assertEquals("AUTH_FAILED", res.messages().get(0).error());
        assertEquals("mesaj 2", res.messages().get(1).text());
        assertEquals(1, auditRows());
    }

    @Test
    void auditFailureMeansNoPlaintext() {
        t.jdbc.execute("DROP TABLE message_access_audit");
        var s = svc(reader(3, 1), true, 200);
        assertThrows(RuntimeException.class, () -> s.decrypt(1, new Request(3L, 1L, 1L, "yeterince uzun gerekce"), "ip"));
        assertTrue(true);
    }
}
