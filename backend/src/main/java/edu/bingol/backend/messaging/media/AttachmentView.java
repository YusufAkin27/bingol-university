package edu.bingol.backend.messaging.media;

/**
 * Mesaj gorunumundeki ek meta verisi. `url`/`thumbUrl` KIMLIKLI (Bearer) API yollaridir; &lt;img&gt; icin kisa omurlu
 * imzali adres `GET .../link` ile alinir. Gizlenen ekte (`removed`) adresler null'dir, boyutlar yer tutucu icin kalir.
 */
public record AttachmentView(Long id, String kind, int width, int height, long bytes, String contentType,
                             boolean removed, String url, String thumbUrl) {

    public static AttachmentView of(MessageAttachment a) {
        if (a.isHidden()) {
            return new AttachmentView(a.getId(), a.getKind(), a.getWidth(), a.getHeight(), 0, null, true, null, null);
        }
        String base = "/api/conversations/" + a.getConversationId() + "/media/" + a.getId();
        return new AttachmentView(a.getId(), a.getKind(), a.getWidth(), a.getHeight(), a.getBytes(),
                a.getContentType(), false, base, base + "/thumb");
    }

    /** `GET .../link` yaniti: imzali, kisa omurlu adresler (epoch saniye). */
    public record Link(String url, String thumbUrl, long expiresAt) {}
}
