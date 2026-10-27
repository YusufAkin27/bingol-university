package edu.bingol.backend.media.transcode;

import edu.bingol.backend.post.media.PostMediaService;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * CDN origin ucu. Yetki IMZADADIR (oturum yok; /files/** herkese acik gecer). Imza/sure gecersiz, medya yok,
 * gizli ya da gonderi silinmisse AYNI 404 doner. Yanit {@code Cache-Control: public, max-age<=imza omru}
 * tasir: CDN yalnizca bu imzali URL ile, imza suresi kadar onbellekler.
 */
@RestController
public class PostMediaCdnController {

    private final MediaCdnLinks links;
    private final PostMediaService media;

    public PostMediaCdnController(MediaCdnLinks links, PostMediaService media) {
        this.links = links;
        this.media = media;
    }

    @GetMapping("/files/cdn/post/{id:[0-9]{1,18}}")
    public ResponseEntity<Resource> get(@PathVariable long id, @RequestParam(defaultValue = "0") int t,
                                        @RequestParam(defaultValue = "0") long exp,
                                        @RequestParam(defaultValue = "") String sig,
                                        @RequestHeader(value = HttpHeaders.RANGE, required = false) String range,
                                        @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String inm,
                                        HttpServletResponse resp) {
        boolean thumb = t == 1;
        if (!links.verify(id, thumb, exp, sig)) {
            return ResponseEntity.notFound().build();
        }
        return media.serveSigned(id, thumb, range, inm, links.maxAgeSeconds(exp), resp);
    }
}
