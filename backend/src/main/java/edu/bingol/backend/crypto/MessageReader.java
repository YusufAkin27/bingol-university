package edu.bingol.backend.crypto;

import java.time.Instant;
import java.util.List;

/**
 * Yonetici cozme icin sifreli mesajlari okuyan kaynak. Asama 2'de messaging paketi uygular
 * (bean yoksa cozme ucu 501 MESSAGE_READER_UNAVAILABLE doner).
 */
public interface MessageReader {

    /** contextBytes: mesaji sifrelerken AAD'ye verilen baglamin AYNISI. */
    record SealedMessage(long messageId, long senderId, Instant createdAt, byte[] contextBytes, Sealed sealed) {}

    /** [fromMessageId, toMessageId] araligi, kimlige gore artan, en fazla limit kayit. */
    List<SealedMessage> read(long conversationId, long fromMessageId, long toMessageId, int limit);
}
