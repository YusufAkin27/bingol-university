package edu.bingol.backend.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.common.SlicePaging;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.Slice;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class BlockController {

    public record BlockedUser(Long id, String displayName, String avatarUrl) {}

    private final BlockService blocks;
    private final UserRepository users;
    private final RateLimiter limiter;

    public BlockController(BlockService blocks, UserRepository users, RateLimiter limiter) {
        this.blocks = blocks;
        this.users = users;
        this.limiter = limiter;
    }

    @PostMapping("/{id}/block")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void block(@PathVariable Long id) {
        Long me = CurrentUser.id();
        // Kimlik taramasi (404/204 farki) ve engel-kaldir dongusu icin saatlik tavan (T-060)
        limiter.check("block:user:" + me, 60, Duration.ofHours(1));
        // Kendini engelleme 400 olarak servis katmaninda kalir; silinmis/askidaki/olmayan hedef 404 (gereksiz satir yok)
        if (!me.equals(id) && users.findById(id).filter(User::isActive).isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
        blocks.block(me, id);
    }

    @DeleteMapping("/{id}/block")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unblock(@PathVariable Long id) {
        Long me = CurrentUser.id();
        limiter.check("block:user:" + me, 60, Duration.ofHours(1));
        blocks.unblock(me, id);
    }

    /** Engellenenler, yeniden eskiye; devam varsa X-Next-Cursor basligi (?cursor=&limit=, en cok 50). */
    @GetMapping("/me/blocks")
    public ResponseEntity<List<BlockedUser>> myBlocks(@RequestParam(required = false) Long cursor,
                                                      @RequestParam(required = false) Integer limit) {
        Slice<UserBlock> slice = blocks.blockedPage(CurrentUser.id(), SlicePaging.request(cursor, limit));
        List<UserBlock> list = slice.getContent();
        Map<Long, User> byId = users.findAllById(list.stream().map(UserBlock::getBlockedId).toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        List<BlockedUser> items = list.stream().filter(b -> byId.containsKey(b.getBlockedId()))
                .map(b -> {
                    User u = byId.get(b.getBlockedId());
                    return new BlockedUser(u.getId(), u.getDisplayName(), null); // engel iliskisinde avatar gorunmez
                }).toList();
        ResponseEntity<List<BlockedUser>> res = SlicePaging.respond(slice, items);
        // Toplam engel sayisi ("Engellenenler (N)"): govde duz dizi kaldigindan baslikta
        return ResponseEntity.status(res.getStatusCode()).headers(res.getHeaders())
                .header("X-Total-Count", String.valueOf(blocks.blockedCount(CurrentUser.id()))).body(res.getBody());
    }
}
