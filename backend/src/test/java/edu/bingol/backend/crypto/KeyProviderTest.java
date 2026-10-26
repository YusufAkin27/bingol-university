package edu.bingol.backend.crypto;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.crypto.CryptoException.Reason;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.StandardEnvironment;

class KeyProviderTest {

    private static final String K1 = "k1:" + CryptoTestSupport.b64(1);
    private static final String K2 = "k2:" + CryptoTestSupport.b64(2);

    @Test
    void parsesMultipleVersionsLastIsActiveByDefault() {
        KeyProvider p = CryptoTestSupport.provider(K1 + "," + K2, "");
        assertEquals("k2", p.activeKeyId());
        assertEquals(2, p.keyIds().size());
        assertFalse(p.isDevKey());
        assertEquals("k1", CryptoTestSupport.provider(K1 + "," + K2, "k1").activeKeyId());
    }

    @Test
    void rejectsBadConfig() {
        for (String bad : new String[] {"k1", "k1:!!!", "k1:" + java.util.Base64.getEncoder().encodeToString(new byte[16]),
                K1 + "," + K1, "bad id:" + CryptoTestSupport.b64(1), ":" + CryptoTestSupport.b64(1)}) {
            assertThrows(IllegalStateException.class, () -> CryptoTestSupport.provider(bad, ""), bad);
        }
        assertThrows(IllegalStateException.class, () -> CryptoTestSupport.provider(K1, "yok"));
    }

    @Test
    void missingKeyFailsStartupInProductionButWarnsInDev() {
        StandardEnvironment prod = new StandardEnvironment();
        prod.setActiveProfiles("prod");
        assertThrows(IllegalStateException.class, () -> new ConfiguredKeyProvider(CryptoTestSupport.props("", ""), prod));
        assertThrows(IllegalStateException.class, () -> new ConfiguredKeyProvider(
                new CryptoProperties("", "", "", true, true, 300, 1024, 30, 200), new StandardEnvironment()));
        KeyProvider dev = new ConfiguredKeyProvider(CryptoTestSupport.props("", ""), new StandardEnvironment());
        assertTrue(dev.isDevKey());
        assertEquals("dev", dev.activeKeyId());
        // Prod'da gecerli anahtar varsa acilir
        assertEquals("k1", new ConfiguredKeyProvider(CryptoTestSupport.props(K1, ""), prod).activeKeyId());
    }

    @Test
    void unknownKeyIdIsUnavailable() {
        CryptoException e = assertThrows(CryptoException.class, () -> CryptoTestSupport.provider(K1, "").key("nope"));
        assertEquals(Reason.KEY_UNAVAILABLE, e.reason());
    }

    @Test
    void readsKeysFromFile() throws Exception {
        Path f = Files.createTempFile("mk", ".txt");
        try {
            Files.writeString(f, K1 + "\n" + K2 + "\n");
            KeyProvider p = new ConfiguredKeyProvider(
                    new CryptoProperties("", f.toString(), "", false, true, 300, 1024, 30, 200), new StandardEnvironment());
            assertEquals(2, p.keyIds().size());
        } finally {
            Files.deleteIfExists(f);
        }
    }
}
