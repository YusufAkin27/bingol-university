package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.DepartmentChannel;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.DepartmentChannelPage;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.MyChannel;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Bolum kanallari (v2): her ogrenci herhangi bir bolumun kanalina isteyerek katilip ayrilir. `{key}` katalog bolum
 * kimligidir (GET /api/catalog/academic). Yalnizca HTTP eslemesi + rate limit; kurallar DepartmentChatService'te.
 */
@RestController
@RequestMapping("/api/chat/departments")
public class DepartmentChannelController {

    private final DepartmentChatService chat;
    private final RateLimiter limiter;

    public DepartmentChannelController(DepartmentChatService chat, RateLimiter limiter) {
        this.chat = chat;
        this.limiter = limiter;
    }

    /** Tum bolumler: `q` arama, `page`/`size` (en cok 200). Yanit `ownKey` kendi bolumunun anahtari. */
    @GetMapping
    public DepartmentChannelPage list(@RequestParam(defaultValue = "") String q,
                                      @RequestParam(defaultValue = "0") int page,
                                      @RequestParam(defaultValue = "100") int size) {
        Long me = CurrentUser.id();
        limiter.check("dept-chan-read:user:" + me, 120, Duration.ofMinutes(1));
        return chat.listChannels(me, q, page, size);
    }

    /** Katildigim bolum kanallari (sohbet sekmesi seridi). */
    @GetMapping("/mine")
    public List<MyChannel> mine() {
        Long me = CurrentUser.id();
        limiter.check("dept-chan-read:user:" + me, 120, Duration.ofMinutes(1));
        return chat.myChannels(me);
    }

    @PostMapping("/{key}/join")
    public DepartmentChannel join(@PathVariable String key) {
        Long me = CurrentUser.id();
        limiter.check("dept-chan:user:" + me, 60, Duration.ofMinutes(10));
        return chat.joinChannel(me, key);
    }

    @PostMapping("/{key}/leave")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@PathVariable String key) {
        Long me = CurrentUser.id();
        limiter.check("dept-chan:user:" + me, 60, Duration.ofMinutes(10));
        chat.leaveChannel(me, key);
    }
}
