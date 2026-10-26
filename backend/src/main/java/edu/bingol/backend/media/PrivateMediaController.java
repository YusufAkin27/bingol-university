package edu.bingol.backend.media;

import org.springframework.core.io.Resource;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Imzali ozel medya ucu. /files/** zaten herkese acik gecer; yetki imzadadir. Imza/sure gecersizse de
 * dosya yoksa da AYNI 404 doner (varlik sizmaz).
 */
@RestController
public class PrivateMediaController {

    private final PrivateMediaStore store;
    private final MediaUrlSigner signer;

    public PrivateMediaController(PrivateMediaStore store, MediaUrlSigner signer) {
        this.store = store;
        this.signer = signer;
    }

    @GetMapping("/files/p/{bucket:[a-z]{1,20}}/{key:[A-Za-z0-9\\-]+\\.(?:jpg|png)}")
    public ResponseEntity<Resource> get(@PathVariable String bucket, @PathVariable String key,
                                        @RequestParam(defaultValue = "0") long exp,
                                        @RequestParam(defaultValue = "") String sig) {
        if (!signer.verify(bucket, key, exp, sig)) {
            return ResponseEntity.notFound().build();
        }
        return store.serve(bucket, key);
    }
}
