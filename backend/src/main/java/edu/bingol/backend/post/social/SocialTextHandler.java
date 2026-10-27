package edu.bingol.backend.post.social;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.post.SocialTextEvent;
import edu.bingol.backend.post.notify.PostNotifier;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.event.EventListener;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Gonderi/yorum metni kaydedilirken (ayni islemde) #etiket ve @etiketleri esitler. Ihlal (cok fazla etiket,
 * yasakli #etiket) ApiException ile islemi geri alir. Bildirimler islem basariyla bitince, yalniz YENI etiketlenenlere.
 */
@Component
public class SocialTextHandler {

    private static final Logger log = LoggerFactory.getLogger(SocialTextHandler.class);

    private final PostMentionRepository mentions;
    private final HashtagRepository hashtags;
    private final PostHashtagRepository links;
    private final UserRepository users;
    private final BlockService blocks;
    private final ContentGuard guard;
    private final ObjectProvider<PostNotifier> notifier;

    public SocialTextHandler(PostMentionRepository mentions, HashtagRepository hashtags, PostHashtagRepository links,
                             UserRepository users, BlockService blocks, ContentGuard guard,
                             ObjectProvider<PostNotifier> notifier) {
        this.mentions = mentions;
        this.hashtags = hashtags;
        this.links = links;
        this.users = users;
        this.blocks = blocks;
        this.guard = guard;
        this.notifier = notifier;
    }

    @EventListener
    public void on(SocialTextEvent e) {
        String text = e.text();
        if (SocialText.countMentions(text) > SocialText.MAX_MENTIONS) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MENTION_TOO_MANY",
                    "Bir metinde en çok {0} kişi etiketlenebilir.", String.valueOf(SocialText.MAX_MENTIONS));
        }
        if (e.commentId() == null) {
            syncHashtags(e);
        }
        syncMentions(e);
    }

    // ---------------------------------------------------------------- #etiket

    private void syncHashtags(SocialTextEvent e) {
        Map<String, String> wanted = SocialText.hashtags(e.text());
        for (String display : wanted.values()) {
            guard.assertClean(ContentGuard.Entity.POST, "hashtag", e.actorId(), display);
        }
        Map<String, Hashtag> byTag = new LinkedHashMap<>();
        if (!wanted.isEmpty()) {
            hashtags.findByTagIn(wanted.keySet()).forEach(h -> byTag.put(h.getTag(), h));
        }
        Set<Long> want = new HashSet<>();
        for (Map.Entry<String, String> en : wanted.entrySet()) {
            Hashtag h = byTag.get(en.getKey());
            if (h == null) {
                h = new Hashtag();
                h.setTag(en.getKey());
                h.setDisplay(en.getValue());
                h = hashtags.saveAndFlush(h);
            }
            want.add(h.getId());
        }
        Set<Long> have = new HashSet<>(links.hashtagIdsOf(e.postId()));
        for (Long id : want) {
            if (!have.contains(id)) {
                links.save(new PostHashtag(e.postId(), id));
            }
        }
        for (Long id : have) {
            if (!want.contains(id)) {
                links.deleteById(new PairId(e.postId(), id));
            }
        }
    }

    // ---------------------------------------------------------------- @etiket

    private void syncMentions(SocialTextEvent e) {
        List<Long> candidates = SocialText.mentionedIds(e.text());
        Set<Long> valid = new HashSet<>();
        if (!candidates.isEmpty()) {
            Set<Long> hidden = blocks.hiddenFrom(e.actorId());
            for (User u : users.findAllById(candidates)) {
                if (u.isActive() && u.isEmailVerified() && (hidden == null || !hidden.contains(u.getId()))) {
                    valid.add(u.getId());
                }
            }
        }
        List<PostMention> rows = e.commentId() == null ? mentions.ofPost(e.postId())
                : mentions.findByCommentId(e.commentId());
        Set<Long> have = new HashSet<>();
        for (PostMention m : rows) {
            if (valid.contains(m.getUserId()) && have.add(m.getUserId())) {
                continue;
            }
            mentions.delete(m);
        }
        List<Long> added = new ArrayList<>();
        for (Long id : candidates) {
            if (valid.contains(id) && !have.contains(id)) {
                mentions.save(new PostMention(e.postId(), e.commentId(), id));
                added.add(id);
            }
        }
        if (!added.isEmpty()) {
            afterCommit(() -> notifyAll(e, added));
        }
    }

    private void notifyAll(SocialTextEvent e, List<Long> targets) {
        PostNotifier n = notifier.getIfAvailable();
        if (n == null) {
            return;
        }
        for (Long id : targets) {
            try {
                n.onMention(e.actorId(), e.postId(), e.commentId(), id);
            } catch (RuntimeException ex) {
                log.warn("Etiket bildirimi atlandi ({}): {}", id, ex.toString());
            }
        }
    }

    private static void afterCommit(Runnable r) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    r.run();
                }
            });
        } else {
            r.run();
        }
    }
}
