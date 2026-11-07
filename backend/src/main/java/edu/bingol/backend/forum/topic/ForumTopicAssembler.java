package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.category.ForumCategory;
import edu.bingol.backend.forum.category.ForumCategoryService;
import edu.bingol.backend.forum.media.ForumMedia;
import edu.bingol.backend.forum.media.ForumMediaRepository;
import edu.bingol.backend.forum.media.ForumMediaService;
import edu.bingol.backend.forum.poll.spi.ForumPollService;
import edu.bingol.backend.forum.poll.spi.PollView;
import edu.bingol.backend.forum.topic.dto.Author;
import edu.bingol.backend.forum.topic.dto.CategoryRef;
import edu.bingol.backend.forum.topic.dto.ImageView;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.dto.TopicView;
import edu.bingol.backend.forum.topic.spi.ForumAuthorResolver;
import edu.bingol.backend.i18n.Lang;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Konu satirlarindan API gorunumleri ({@link TopicSummary}, {@link TopicView}). Listeler icin sorgu sayisi sabittir
 * (kategori, yazar, begeni, kayit, takip, gorsel, anket: her biri tek toplu sorgu).
 */
@Component
public class ForumTopicAssembler {

    static final int PREVIEW_MAX = 280;

    private final ForumCategoryService categories;
    private final ForumAuthorResolver authors;
    private final ForumTopicLikeRepository likes;
    private final ForumBookmarkRepository bookmarks;
    private final ForumTopicFollowRepository follows;
    private final ForumTopicImageRepository images;
    private final ForumMediaRepository media;
    private final ObjectProvider<ForumPollService> polls;

    public ForumTopicAssembler(ForumCategoryService categories, ForumAuthorResolver authors,
                               ForumTopicLikeRepository likes, ForumBookmarkRepository bookmarks,
                               ForumTopicFollowRepository follows, ForumTopicImageRepository images,
                               ForumMediaRepository media, ObjectProvider<ForumPollService> polls) {
        this.categories = categories;
        this.authors = authors;
        this.likes = likes;
        this.bookmarks = bookmarks;
        this.follows = follows;
        this.images = images;
        this.media = media;
        this.polls = polls;
    }

    @Transactional(readOnly = true)
    public List<TopicSummary> summaries(List<ForumTopic> topics, Long viewerId) {
        if (topics.isEmpty()) {
            return List.of();
        }
        List<Long> ids = topics.stream().map(ForumTopic::getId).toList();
        Lang lang = Lang.of(LocaleContextHolder.getLocale());
        Map<Long, ForumCategory> cats = categories.byIds(
                topics.stream().map(ForumTopic::getCategoryId).collect(Collectors.toSet()));
        List<Author> authorViews = authors.resolve(viewerId, topics.stream()
                .map(t -> new ForumAuthorResolver.Key(t.getId(), t.getUserId(), t.isAnonymous())).toList());
        Set<Long> liked = new HashSet<>(likes.likedAmong(viewerId, ids));
        Set<Long> saved = new HashSet<>(bookmarks.savedAmong(viewerId, ForumBookmark.TOPIC, ids));
        Set<Long> followed = new HashSet<>(follows.followedAmong(viewerId, ids));
        Map<Long, ImageView> thumbs = firstImages(ids);
        ForumPollService pollSvc = polls.getIfAvailable();
        Set<Long> withPoll = pollSvc == null ? Set.of() : pollSvc.topicIdsWithPoll(ids);
        boolean moderator = ForumPermissions.canModerate();
        List<TopicSummary> out = new ArrayList<>(topics.size());
        for (int i = 0; i < topics.size(); i++) {
            ForumTopic t = topics.get(i);
            ForumCategory c = cats.get(t.getCategoryId());
            CategoryRef cref = c == null ? new CategoryRef(t.getCategoryId(), "", "")
                    : new CategoryRef(c.getId(), ForumCategoryService.nameOf(c, lang), c.getSlug());
            out.add(new TopicSummary(t.getId(), t.getTitle(), ForumText.preview(t.getBody(), PREVIEW_MAX), cref,
                    authorViews.get(i), t.getCreatedAt(), t.getEditedAt(), t.getLikeCount(), t.getCommentCount(),
                    liked.contains(t.getId()), saved.contains(t.getId()), followed.contains(t.getId()),
                    thumbs.get(t.getId()), t.getImageCount(), withPoll.contains(t.getId()), t.getPinnedAt() != null,
                    t.isLocked(), t.getUserId().equals(viewerId), moderator, t.getStatus()));
        }
        return out;
    }

    @Transactional(readOnly = true)
    public TopicView view(ForumTopic t, Long viewerId) {
        TopicSummary s = summaries(List.of(t), viewerId).get(0);
        Map<Long, List<ImageView>> all = allImages(List.of(t.getId()));
        ForumPollService pollSvc = polls.getIfAvailable();
        PollView poll = pollSvc == null ? null : pollSvc.pollFor(t.getId(), viewerId);
        boolean mine = s.mine();
        boolean notifications = follows.find(t.getId(), viewerId).map(ForumTopicFollow::isNotify).orElse(true);
        // hasPoll anket yuklemesiyle tutarli olsun (liste sorgusu ile ayni kaynak)
        TopicSummary withPoll = poll != null && !s.hasPoll() ? copyWithPoll(s) : s;
        return TopicView.of(withPoll, t.getBody(), all.getOrDefault(t.getId(), List.of()), poll,
                mine && !t.isLocked() && !t.isRemoved(), mine, notifications);
    }

    private static TopicSummary copyWithPoll(TopicSummary s) {
        return new TopicSummary(s.id(), s.title(), s.bodyPreview(), s.category(), s.author(), s.createdAt(),
                s.editedAt(), s.likeCount(), s.commentCount(), s.likedByMe(), s.savedByMe(), s.followedByMe(),
                s.thumbnail(), s.imageCount(), true, s.pinned(), s.locked(), s.mine(), s.canModerate(), s.status());
    }

    // ------------------------------------------------------------------ gorseller

    private Map<Long, ImageView> firstImages(Collection<Long> topicIds) {
        Map<Long, ImageView> out = new HashMap<>();
        for (Map.Entry<Long, List<ImageView>> e : allImages(topicIds).entrySet()) {
            if (!e.getValue().isEmpty()) {
                out.put(e.getKey(), e.getValue().get(0));
            }
        }
        return out;
    }

    private Map<Long, List<ImageView>> allImages(Collection<Long> topicIds) {
        List<ForumTopicImage> links = images.forTopics(topicIds);
        if (links.isEmpty()) {
            return Map.of();
        }
        Map<Long, ForumMedia> byId = new HashMap<>();
        for (ForumMedia m : media.findByIdIn(links.stream().map(ForumTopicImage::getMediaId).toList())) {
            byId.put(m.getId(), m);
        }
        Map<Long, List<ImageView>> out = new HashMap<>();
        for (ForumTopicImage l : links) {
            ForumMedia m = byId.get(l.getMediaId());
            if (m == null || m.getHiddenAt() != null) {
                continue;
            }
            out.computeIfAbsent(l.getTopicId(), k -> new ArrayList<>()).add(new ImageView(m.getId(),
                    ForumMediaService.urlOf(m.getId(), false), ForumMediaService.urlOf(m.getId(), true),
                    m.getWidth(), m.getHeight()));
        }
        return out;
    }
}
