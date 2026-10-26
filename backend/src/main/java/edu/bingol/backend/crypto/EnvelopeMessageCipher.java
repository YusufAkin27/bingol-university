package edu.bingol.backend.crypto;

import edu.bingol.backend.crypto.ConversationKeyService.DekRef;
import javax.crypto.SecretKey;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/** Zarf sifreleme: konusma DEK'i ile AES-256-GCM, AAD = konusma + baglam. */
@Component
public class EnvelopeMessageCipher implements MessageCipher {

    private static final Logger log = LoggerFactory.getLogger(EnvelopeMessageCipher.class);
    static final String PURPOSE = "msg";

    private final ConversationKeyService keys;
    private final CryptoService crypto;
    private final CryptoMetrics metrics;

    public EnvelopeMessageCipher(ConversationKeyService keys, CryptoService crypto, CryptoMetrics metrics) {
        this.keys = keys;
        this.crypto = crypto;
        this.metrics = metrics;
    }

    @Override
    public Sealed encrypt(long conversationId, byte[] contextBytes, byte[] plaintext) {
        DekRef dek = keys.active(conversationId);
        return crypto.seal(dek.key(), Aad.of(PURPOSE, conversationId, contextBytes), plaintext, dek.version());
    }

    @Override
    public byte[] decrypt(long conversationId, byte[] contextBytes, Sealed sealed) {
        try {
            SecretKey dek = keys.key(conversationId, sealed.keyVersion());
            return crypto.open(dek, Aad.of(PURPOSE, conversationId, contextBytes), sealed.nonce(), sealed.ciphertext());
        } catch (CryptoException e) {
            // Icerik/anahtar yazilmaz; yalnizca konusma ve neden.
            metrics.failure("decrypt_" + e.reason().name().toLowerCase());
            log.warn("Mesaj cozulemedi: konusma={} surum={} neden={}", conversationId, sealed.keyVersion(), e.reason());
            throw e;
        }
    }
}
