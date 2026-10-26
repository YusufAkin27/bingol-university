package edu.bingol.backend.moderation;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.SlicePaging;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
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

    public BlockController(BlockService blocks, UserRepository users) {
        this.blocks = blocks;
        this.users = users;
    }

    @PostMapping("/{id}/block")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void block(@PathVariable Long id) {
        blocks.block(CurrentUser.id(), id);
    }

    @DeleteMapping("/{id}/block")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unblock(@PathVariable Long id) {
        blocks.unblock(CurrentUser.id(), id);
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
                    return new BlockedUser(u.getId(), u.getDisplayName(), u.getAvatarUrl());
                }).toList();
        return SlicePaging.respond(slice, items);
    }
}
