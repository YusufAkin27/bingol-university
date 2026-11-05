package edu.bingol.backend.forum.topic;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.category.ForumCategoryService;
import edu.bingol.backend.forum.media.ForumMediaService;
import edu.bingol.backend.forum.poll.spi.ForumPollService;
import edu.bingol.backend.forum.topic.ForumTopicDtos.CreateTopicRequest;
import edu.bingol.backend.forum.topic.ForumTopicDtos.UpdateTopicRequest;
import edu.bingol.backend.forum.topic.dto.TopicView;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Konu olusturma / duzenleme / silme / okuma. Sahiplik ve gorunurluk kararlari burada (sunucu); entity API'ye donmez.
 * Olusturma TEK transaction: konu + takma ad + gorsel baglama + anket (biri basarisizsa hicbiri kalmaz).
 */
@Service
public class ForumTopicService {

    public static final int TITLE_MAX = 150;
    public static final int BODY_MAX = 10_000;
    private static final Pattern IDEM = Pattern.compile("[A-Za-z0-9._:-]{8,100}");
    private static final Logger log = LoggerFactory.getLogger(ForumTopicService.class);

    private final ForumTopicRepository topics;
    private final ForumCategoryService categories;
    private final ForumMediaService mediaService;
    private final ForumAnonAliasService aliases;
    private final ForumTopicAssembler assembler;
    private final ForumViewerFilter filter;
    private final ContentGuard guard;
    private final ObjectProvider<ForumPollService> polls;
    private final TransactionTemplate tx;

    public ForumTopicService(ForumTopicRepository topics, ForumCategoryService categories,
                             ForumMediaService mediaService, ForumAnonAliasService aliases,
                             ForumTopicAssembler assembler, ForumViewerFilter filter, ContentGuard guard,
                             ObjectProvider<ForumPollService> polls, PlatformTransactionManager tm) {
        this.topics = topics;
        this.categories = categories;
        this.mediaService = mediaService;
        this.aliases = aliases;
        this.assembler = assembler;
        this.filter = filter;
        this.guard = guard;
        this.polls = polls;
        this.tx = new TransactionTemplate(tm);
    }

    // ------------------------------------------------------------------ olustur

    /** @param idemKey {@code Idempotency-Key} basligi (yoksa/bicimsizse cift gonderim korumasi yok) */
    public TopicView create(Long userId, CreateTopicRequest req, String idemKey) {
        String key = idemKey != null && IDEM.matcher(idemKey.trim()).matches() ? idemKey.trim() : null;
        if (key != null) {
            Optional<ForumTopic> prior = topics.findByUserIdAndIdemKey(userId, key);
            if (prior.isPresent()) {
                return replay(prior.get(), userId);
            }
        }
        if (req == null) {
            throw titleRequired();
        }
        String title = cleanTitle(req.title());
        String body = cleanBody(req.body());
        categories.requireOpen(req.categoryId());
        List<Long> imageIds = req.imageIds() == null ? List.of() : req.imageIds();
        if (imageIds.size() > ForumMediaService.MAX_PER_TOPIC) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_TOO_MANY_IMAGES",
                    "Bir konuya en çok " + ForumMediaService.MAX_PER_TOPIC + " görsel eklenebilir.",
                    String.valueOf(ForumMediaService.MAX_PER_TOPIC));
        }
        guard.assertClean(ContentGuard.Entity.OTHER, "title", userId, title);
        guard.assertClean(ContentGuard.Entity.OTHER, "body", userId, body);
        ForumPollService pollService = polls.getIfAvailable();
        if (req.poll() != null && pollService == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_POLL_UNAVAILABLE", "Anket şu anda eklenemiyor.");
        }
        Long id;
        try {
            id = tx.execute(st -> {
                ForumTopic t = new ForumTopic();
                t.setUserId(userId);
                t.setCategoryId(req.categoryId());
                t.setTitle(title);
                t.setBody(body);
                t.setAnonymous(req.anonymous());
                t.setIdemKey(key);
                t.setImageCount((short) imageIds.size());
                Instant now = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
                t.setCreatedAt(now);
                t.setUpdatedAt(now);
                t.setLastActivityAt(now);
                t = topics.saveAndFlush(t);
                if (t.isAnonymous()) {
                    aliases.allocateInCurrentTx(t.getId(), userId);
                }
                mediaService.attach(t.getId(), userId, imageIds);
                if (req.poll() != null) {
                    pollService.createForTopic(t.getId(), req.poll());
                }
                return t.getId();
            });
        } catch (DataIntegrityViolationException e) {
            // Ayni Idempotency-Key ile yarisan ikinci istek: ilkinin konusunu don
            if (key != null) {
                Optional<ForumTopic> prior = topics.findByUserIdAndIdemKey(userId, key);
                if (prior.isPresent()) {
                    return replay(prior.get(), userId);
                }
            }
            throw e;
        }
        return get(userId, id);
    }

    private TopicView replay(ForumTopic prior, Long userId) {
        if (prior.getDeletedAt() != null) {
            throw notFound();
        }
        return assembler.view(prior, userId);
    }

    // ------------------------------------------------------------------ oku

    public TopicView get(Long viewerId, Long topicId) {
        ForumTopic t = visibleOrThrow(topicId, viewerId);
        return assembler.view(t, viewerId);
    }

    // ------------------------------------------------------------------ duzenle

    public TopicView update(Long userId, Long topicId, UpdateTopicRequest req) {
        ForumTopic t = visibleOrThrow(topicId, userId);
        requireOwner(t, userId);
        if (t.isLocked()) {
            throw new ApiException(HttpStatus.CONFLICT, "FORUM_TOPIC_LOCKED",
                    "Bu konu yorumlara ve düzenlemeye kapatıldı.");
        }
        String title = req != null && req.title() != null ? cleanTitle(req.title()) : null;
        String body = req != null && req.body() != null ? cleanBody(req.body()) : null;
        Long cat = req == null ? null : req.categoryId();
        if (cat != null && !cat.equals(t.getCategoryId())) {
            categories.requireOpen(cat);
        }
        ContentGuard.changed(guard, ContentGuard.Entity.OTHER, "title", userId, t.getTitle(), title);
        ContentGuard.changed(guard, ContentGuard.Entity.OTHER, "body", userId, t.getBody(), body);
        Long id = t.getId();
        tx.executeWithoutResult(st -> {
            ForumTopic fresh = topics.findByIdAndDeletedAtIsNull(id)
                    .orElseThrow(ForumTopicService::notFound); // eszamanli silinmis
            boolean changed = false;
            if (title != null && !title.equals(fresh.getTitle())) {
                fresh.setTitle(title);
                changed = true;
            }
            if (body != null && !body.equals(fresh.getBody())) {
                fresh.setBody(body);
                changed = true;
            }
            if (cat != null && !cat.equals(fresh.getCategoryId())) {
                fresh.setCategoryId(cat);
                changed = true;
            }
            if (changed) {
                Instant now = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
                fresh.setEditedAt(now);
                fresh.setUpdatedAt(now);
            }
        });
        return get(userId, topicId);
    }

    // ------------------------------------------------------------------ sil

    /** Sahip siler (yumusak). Zaten silinmisse 404 (idempotent degil: eszamanli silme acikca bildirilir). */
    public void delete(Long userId, Long topicId) {
        ForumTopic t = visibleOrThrow(topicId, userId);
        requireOwner(t, userId);
        tx.executeWithoutResult(st -> {
            ForumTopic fresh = topics.findByIdAndDeletedAtIsNull(topicId).orElseThrow(ForumTopicService::notFound);
            fresh.setDeletedAt(Instant.now());
            fresh.setPinnedAt(null);
        });
    }

    // ------------------------------------------------------------------ yardimcilar

    ForumTopic visibleOrThrow(Long topicId, Long viewerId) {
        if (topicId == null) {
            throw notFound();
        }
        return topics.findVisible(topicId, viewerId, filter.hiddenFrom(viewerId)).orElseThrow(ForumTopicService::notFound);
    }

    private static void requireOwner(ForumTopic t, Long userId) {
        if (!t.getUserId().equals(userId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORUM_NOT_OWNER", "Bu işlemi yalnızca içeriğin sahibi yapabilir.");
        }
    }

    private static String cleanTitle(String raw) {
        String s = ForumText.line(raw);
        if (s.isEmpty()) {
            throw titleRequired();
        }
        if (s.length() > TITLE_MAX) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_TITLE_TOO_LONG",
                    "Başlık en çok " + TITLE_MAX + " karakter olabilir.", String.valueOf(TITLE_MAX));
        }
        return s;
    }

    private static String cleanBody(String raw) {
        String s = ForumText.block(raw);
        if (s.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_BODY_REQUIRED", "Açıklama boş olamaz.");
        }
        if (s.length() > BODY_MAX) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_BODY_TOO_LONG",
                    "Açıklama en çok " + BODY_MAX + " karakter olabilir.", String.valueOf(BODY_MAX));
        }
        return s;
    }

    private static ApiException titleRequired() {
        return new ApiException(HttpStatus.BAD_REQUEST, "FORUM_TITLE_REQUIRED", "Başlık boş olamaz.");
    }

    static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "FORUM_TOPIC_NOT_FOUND", "Konu bulunamadı.");
    }
}
