package edu.bingol.backend.forum.notify;

import edu.bingol.backend.i18n.Lang;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Bildirim kararinin ihtiyac duydugu forum okumalari (konu, yorum, takip, takma ad, sessize alma). Arayuz, karar
 * mantiginin (ForumNotifier) veritabani olmadan birim testlenmesi icindir; uretimde {@link JdbcForumNotifyReader}.
 */
public interface ForumNotifyReader {

    /** Konu ozeti; {@code visible}: durum ACTIVE ve silinmemis. */
    record TopicInfo(long id, long authorId, boolean anonymous, String title, long categoryId, boolean visible) {}

    /** Yorum ozeti; {@code parentAuthorId} ust yorum yoksa null. {@code visible}: ACTIVE ve silinmemis. */
    record CommentInfo(long id, long topicId, long authorId, boolean anonymous, Long parentId, Long parentAuthorId,
                       String body, boolean visible) {}

    Optional<TopicInfo> topic(long topicId);

    Optional<CommentInfo> comment(long commentId);

    /** Kategori adi alicinin dilinde (yoksa null). */
    String categoryName(long categoryId, Lang lang);

    /** (konu, kullanici) anonim takma ad numarasi; yoksa null (sizdirmadan "Anonim" gosterilir). */
    Integer anonAlias(long topicId, long userId);

    /** Konuda bildirimleri KAPALI takipci satiri var mi (kullanici bu konu icin bildirimi kapatmis). */
    boolean topicNotificationsOff(long topicId, long userId);

    /** Konuyu takip eden VE bildirimi acik kullanicilar (kimlik sirali, en cok {@code limit}). */
    List<Long> notifyingFollowers(long topicId, int limit);

    /** {@code muterId}, {@code mutedId} kullanicisini sessize almis mi (tek yonlu). */
    boolean muted(long muterId, long mutedId);

    /** {@code muterIds} icinden {@code mutedId} kullanicisini sessize alanlar (toplu). */
    Set<Long> mutersAmong(Collection<Long> muterIds, long mutedId);

    /** Konunun ilk gorseli var mi (bildirim kucuk resmi `/s/f/{id}/img`). */
    boolean topicHasImage(long topicId);
}
