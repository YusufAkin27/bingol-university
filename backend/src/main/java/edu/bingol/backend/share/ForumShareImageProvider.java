package edu.bingol.backend.share;

import org.springframework.core.io.Resource;
import org.springframework.http.ResponseEntity;

/** {@code GET /s/f/{id}/img} ve {@code /s/fc/{id}/img}: herkese acik forum konusunun ilk gorselinin kucuk resmi. */
public interface ForumShareImageProvider {

    /** @param mediaId {@link ShareService.Resolved#mediaId()} (forum_media kimligi); bulunamazsa ApiException(404) */
    ResponseEntity<Resource> servePublicPreview(long mediaId, String ifNoneMatch);
}
