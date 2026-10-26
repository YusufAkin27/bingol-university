package edu.bingol.backend.crypto;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

/**
 * AAD (ek dogrulanan veri) uretici. Alanlar uzunluk onekli yazilir; boylece
 * ("a","bc") ile ("ab","c") ayni baytlari uretemez.
 */
final class Aad {

    private Aad() {}

    /** amac + konusma kimligi + cagiranin baglam baytlari (ornegin mesaj kimligi). */
    static byte[] of(String purpose, long conversationId, byte[] context) {
        byte[] p = purpose.getBytes(StandardCharsets.US_ASCII);
        byte[] c = context == null ? new byte[0] : context;
        ByteBuffer b = ByteBuffer.allocate(4 + p.length + 8 + 4 + c.length);
        b.putInt(p.length).put(p).putLong(conversationId).putInt(c.length).put(c);
        return b.array();
    }

    static byte[] concat(byte[]... parts) {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        for (byte[] p : parts) {
            o.write(p, 0, p.length);
        }
        return o.toByteArray();
    }
}
