package edu.bingol.backend.crypto;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/** `conversation_key` deposu (Spring Data degil; testte bellek ici uygulama kullanilabilir). */
public interface ConversationKeyStore {

    /** wrapped = nonce(12) + sarili DEK + etiket. */
    record StoredKey(long conversationId, int version, byte[] wrapped, String masterKeyId, boolean active) {}

    Optional<StoredKey> find(long conversationId, int version);

    Optional<StoredKey> findActive(long conversationId);

    /** Yaris durumunda (baska is parcacigi once ekledi) false doner; istisna firlatmaz. */
    boolean insert(StoredKey key);

    /** master_key_id'si verilenden FARKLI olanlar; (konusma, surum) imlecinden sonrasi, sirali. */
    List<StoredKey> pageNotWrappedBy(String masterKeyId, long afterConversationId, int afterVersion, int limit);

    /** Yalnizca satir hala oldKeyId ile sarili ise gunceller (rotasyon yarisina karsi). */
    boolean rewrap(long conversationId, int version, String oldKeyId, String newKeyId, byte[] newWrapped);

    Map<String, Long> countsByMasterKey();
}
