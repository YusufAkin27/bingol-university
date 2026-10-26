package edu.bingol.backend.crypto;

/**
 * Sifreli mesaj govdesi: ciphertext (GCM etiketi sonda), 96-bit nonce ve konusma DEK surumu.
 * Uc alan da veritabaninda saklanir; hicbiri gizli degildir.
 */
public record Sealed(byte[] ciphertext, byte[] nonce, int keyVersion) {
}
