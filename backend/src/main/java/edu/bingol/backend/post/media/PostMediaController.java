package edu.bingol.backend.post.media;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Duration;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Gonderi medyasi: yukleme (multipart `file` + video icin istege bagli `poster`) ve yetkili sunum.
 * Kota/hiz servis icinde; yetki servis katmaninda (erisimsiz = 404).
 */
@RestController
public class PostMediaController {

    private final PostMediaService service;
    private final RateLimiter limiter;

    public PostMediaController(PostMediaService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @PostMapping(path = "/api/posts/media", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PostMediaService.Uploaded upload(@RequestParam("file") MultipartFile file,
                                            @RequestParam(value = "poster", required = false) MultipartFile poster) {
        if (PostMediaService.isVideo(file)) {
            throw PostMediaService.videoNotAllowed(); // sade gonderi: video yok
        }
        return service.upload(CurrentUser.id(), file, poster);
    }

    /** Gorsel/poster: tam govde (ETag, private cache). Video: HTTP Range (206); govde dogrudan yanita yazilir (null doner). */
    @GetMapping("/api/posts/media/{id}")
    public ResponseEntity<Resource> get(@PathVariable Long id, @RequestParam(defaultValue = "false") boolean thumb,
                                        @RequestHeader(value = HttpHeaders.RANGE, required = false) String range,
                                        @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String inm,
                                        HttpServletResponse resp) {
        Long uid = CurrentUser.id();
        limiter.check("postmedia:get:" + uid, 600, Duration.ofMinutes(1));
        return service.serve(uid, id, thumb, range, inm, resp);
    }

    /** Yalnizca gonderiye eklenmemis kendi yuklemesi; bagliysa 409. */
    @DeleteMapping("/api/posts/media/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("postmedia:del:" + uid, 60, Duration.ofMinutes(1));
        service.deleteUnattached(uid, id);
    }

    /** Yonetici onizlemesi (silinmis/gizli de akar). /api/admin/** ADMIN'dir; GET olsa da denetim kaydina yazilir. */
    @GetMapping("/api/admin/posts/media/{id}")
    public ResponseEntity<Resource> adminGet(@PathVariable Long id,
                                             @RequestParam(defaultValue = "false") boolean thumb,
                                             @RequestHeader(value = HttpHeaders.RANGE, required = false) String range,
                                             @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String inm,
                                             HttpServletResponse resp, Authentication auth) {
        limiter.check("adminpostmedia:" + (auth == null ? "anon" : auth.getName()), 300, Duration.ofMinutes(1));
        return service.serveForAdmin(id, thumb, range, inm, resp);
    }
}
