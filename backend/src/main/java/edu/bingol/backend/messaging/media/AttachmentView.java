package edu.bingol.backend.messaging.media;

/**
 * Mesaj gorunumundeki ek meta verisi. `url`/`thumbUrl` KIMLIKLI (Bearer) API yollaridir; &lt;img&gt; icin kisa omurlu
 * imzali adres `GET .../link` ile alinir. Gizlenen ekte (`removed`) adresler null'dir, boyutlar yer tutucu icin kalir.
 * Tek gosterimlikte (`viewOnce`) `thumbUrl` HIC verilmez; `url` yalniz henuz acmamis aliciya doludur.
 * `viewed`: alici icin "ben actim", gonderen icin "karsi taraf (grupta en az biri) acti".
 */
public record AttachmentView(Long id, String kind, Integer width, Integer height, long bytes, String contentType,
                             boolean removed, String url, String thumbUrl, boolean viewOnce, boolean viewed,
                             Integer durationMs, long sizeBytes) {

    public AttachmentView(Long id, String kind, int width, int height, long bytes, String contentType,
                          boolean removed, String url, String thumbUrl) {
        this(id, kind, width, height, bytes, contentType, removed, url, thumbUrl, false, false, null, bytes);
    }

    public AttachmentView(Long id, String kind, int width, int height, long bytes, String contentType,
                          boolean removed, String url, String thumbUrl, boolean viewOnce, boolean viewed) {
        this(id, kind, width, height, bytes, contentType, removed, url, thumbUrl, viewOnce, viewed, null, bytes);
    }

    private static Integer dim(MessageAttachment a, int v) {
        return v <= 0 && a.isVideo() ? null : v; // videoda bilinmeyen boyut null
    }

    public static AttachmentView of(MessageAttachment a) {
        return of(a, null, false);
    }

    /** `viewerId` null ise normal (tek gosterimlik degil) gorunum; `viewed` yukaridaki anlamda onceden hesaplanir. */
    public static AttachmentView of(MessageAttachment a, Long viewerId, boolean viewed) {
        if (a.isHidden()) {
            return new AttachmentView(a.getId(), a.getKind(), dim(a, a.getWidth()), dim(a, a.getHeight()), 0, null, true,
                    null, null, a.isViewOnce(), viewed, a.getDurationMs(), 0);
        }
        String base = base(a.getConversationId(), a.getId());
        if (!a.isViewOnce()) {
            return new AttachmentView(a.getId(), a.getKind(), dim(a, a.getWidth()), dim(a, a.getHeight()), a.getBytes(),
                    a.getContentType(), false, base, a.getThumbKey() == null ? null : base + "/thumb", false, false,
                    a.getDurationMs(), a.getBytes());
        }
        boolean sender = a.getUploaderId().equals(viewerId);
        boolean openable = viewerId != null && !sender && !viewed && a.getPurgedAt() == null;
        return new AttachmentView(a.getId(), a.getKind(), dim(a, a.getWidth()), dim(a, a.getHeight()), a.getBytes(),
                a.getContentType(), false, openable ? base : null, null, true, viewed, a.getDurationMs(), a.getBytes());
    }

    /** Gonderenin gorunumunden aliciya: tek gosterimlik ek acilabilir (henuz acmadi). */
    public AttachmentView forRecipient(Long conversationId) {
        if (!viewOnce || removed) {
            return this;
        }
        return new AttachmentView(id, kind, width, height, bytes, contentType, false, base(conversationId, id), null,
                true, false, durationMs, sizeBytes);
    }

    private static String base(Long conversationId, Long attachmentId) {
        return "/api/conversations/" + conversationId + "/media/" + attachmentId;
    }

    /** `GET .../link` yaniti: imzali, kisa omurlu adresler (epoch saniye). */
    public record Link(String url, String thumbUrl, long expiresAt) {}
}
