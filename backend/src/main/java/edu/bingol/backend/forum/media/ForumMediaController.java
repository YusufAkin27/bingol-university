package edu.bingol.backend.forum.media;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Forum gorseli: yukleme (multipart `file`, jpeg/png/webp, en cok 10 MB), yetkili sunum, yukleme iptali. */
@RestController
public class ForumMediaController {

    private final ForumMediaService service;
    private final RateLimiter limiter;

    public ForumMediaController(ForumMediaService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @PostMapping(path = "/api/forum/media", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public ForumMediaService.Uploaded upload(@RequestParam("file") MultipartFile file) {
        Long uid = CurrentUser.id();
        limiter.check("forum:media:" + uid, 20, Duration.ofHours(1));
        return service.upload(uid, file);
    }

    /** Gorsel/kucuk resim; yetki servis katmaninda (erisimsiz = 404). */
    @GetMapping("/api/forum/media/{id}")
    public ResponseEntity<Resource> get(@PathVariable Long id, @RequestParam(defaultValue = "false") boolean thumb,
                                        @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String inm) {
        Long uid = CurrentUser.id();
        limiter.check("forum:mediaget:" + uid, 600, Duration.ofMinutes(1));
        return service.serve(uid, id, thumb, inm);
    }

    /** Yalnizca konuya eklenmemis kendi yuklemesi; bagliysa 409. */
    @DeleteMapping("/api/forum/media/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:mediadel:" + uid, 60, Duration.ofMinutes(1));
        service.deleteUnattached(uid, id);
    }
}
