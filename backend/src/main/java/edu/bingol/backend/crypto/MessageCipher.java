package edu.bingol.backend.crypto;

import java.nio.charset.StandardCharsets;

/**
 * Mesaj govdesi sifreleme arayuzu (messaging bunu kullanir). `contextBytes` AAD'ye baglanir
 * (ornegin mesaj kimligi + gonderen): ayni baglam verilmezse sifreli metin cozulmez.
 * Hatalar {@link CryptoException} olarak firlar.
 */
public interface MessageCipher {

    Sealed encrypt(long conversationId, byte[] contextBytes, byte[] plaintext);

    byte[] decrypt(long conversationId, byte[] contextBytes, Sealed sealed);

    default Sealed encryptText(long conversationId, byte[] contextBytes, String text) {
        return encrypt(conversationId, contextBytes, text.getBytes(StandardCharsets.UTF_8));
    }

    default String decryptText(long conversationId, byte[] contextBytes, Sealed sealed) {
        return new String(decrypt(conversationId, contextBytes, sealed), StandardCharsets.UTF_8);
    }
}
