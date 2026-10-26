package edu.bingol.backend.moderation;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.moderation.dto.ModerationDtos.AppealDecision;
import edu.bingol.backend.moderation.dto.ModerationDtos.AppealPage;
import edu.bingol.backend.moderation.dto.ModerationDtos.AppealView;
import edu.bingol.backend.moderation.dto.ModerationDtos.BlocklistAdd;
import edu.bingol.backend.moderation.dto.ModerationDtos.BlocklistPage;
import edu.bingol.backend.moderation.dto.ModerationDtos.BlocklistView;
import edu.bingol.backend.moderation.dto.ModerationDtos.RecommendationPage;
import edu.bingol.backend.moderation.dto.ModerationDtos.RecommendationView;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Itirazlar, askiya alma onerileri ve yasakli ozet listesi (yonetici). */
@RestController
@RequestMapping("/api/admin/moderation")
public class AdminModerationExtrasController {

    private final AppealService appeals;
    private final StrikeService strikes;
    private final ContentBlocklist blocklist;

    public AdminModerationExtrasController(AppealService appeals, StrikeService strikes, ContentBlocklist blocklist) {
        this.appeals = appeals;
        this.strikes = strikes;
        this.blocklist = blocklist;
    }

    // --- itirazlar ---

    @GetMapping("/appeals")
    public AppealPage appeals(@RequestParam(defaultValue = "OPEN") ModerationAppeal.Status status,
                              @RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size) {
        int s = CursorPage.clampSize(size);
        CursorPage<AppealView> p = CursorPage.of(appeals.page(status, cursor, s), s, ModerationAppeal::getId, AppealView::of);
        return new AppealPage(p.items(), p.nextCursor());
    }

    @PostMapping("/appeals/{id}/decide")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void decide(@PathVariable Long id, @Valid @RequestBody AppealDecision d, Authentication auth) {
        appeals.decide(id, AdminModerationController.adminId(auth), d.accept(), d.note());
    }

    // --- tekrarlayan ihlal onerileri ---

    @GetMapping("/suspend-recommendations")
    public RecommendationPage recommendations(@RequestParam(defaultValue = "OPEN") SuspendRecommendation.Status status,
                                              @RequestParam(required = false) Long cursor,
                                              @RequestParam(defaultValue = "20") int size) {
        int s = CursorPage.clampSize(size);
        CursorPage<RecommendationView> p = CursorPage.of(strikes.page(status, cursor, s), s,
                SuspendRecommendation::getId, RecommendationView::of);
        return new RecommendationPage(p.items(), p.nextCursor());
    }

    /** Oneriyi kabul et = kullaniciyi askiya al. */
    @PostMapping("/suspend-recommendations/{id}/accept")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void accept(@PathVariable Long id, Authentication auth) {
        strikes.accept(id, AdminModerationController.adminId(auth));
    }

    @PostMapping("/suspend-recommendations/{id}/dismiss")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void dismiss(@PathVariable Long id, Authentication auth) {
        strikes.dismiss(id, AdminModerationController.adminId(auth));
    }

    // --- yasakli ozet listesi ---

    @GetMapping("/blocklist")
    public BlocklistPage blocklist(@RequestParam(required = false) String cursor, @RequestParam(defaultValue = "50") int size) {
        int s = CursorPage.clampSize(size);
        List<BlockedContentHash> rows = blocklist.page(cursor, s);
        boolean more = rows.size() > s;
        List<BlockedContentHash> page = more ? rows.subList(0, s) : rows;
        return new BlocklistPage(page.stream().map(BlocklistView::of).toList(),
                more ? page.get(page.size() - 1).getSha256() : null);
    }

    @PostMapping("/blocklist")
    @ResponseStatus(HttpStatus.CREATED)
    public BlocklistView addBlock(@Valid @RequestBody BlocklistAdd r, Authentication auth) {
        return BlocklistView.of(blocklist.add(r.sha256(), r.note(), AdminModerationController.adminId(auth)));
    }

    @DeleteMapping("/blocklist/{sha256}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeBlock(@PathVariable String sha256) {
        blocklist.remove(sha256);
    }
}
