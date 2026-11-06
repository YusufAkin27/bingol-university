package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.dto.MessagingDtos.UnreadItem;
import edu.bingol.backend.messaging.dto.MessagingDtos.UnreadSummary;
import edu.bingol.backend.moderation.BlockService;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Uye bazli konusma tercihleri (sessize alma, arsiv) ve okunmamis sayaclari. Yalnizca kullanicinin kendi
 * uyeligi degisir; uye olmayan icin 404 (varlik sizdirilmaz).
 */
@Service
public class ConversationPrefsService {

    public static final int MAX_MUTE_MINUTES = 525_600; // 1 yil
    /** "Sonsuza kadar" PostgreSQL TIMESTAMPTZ siniri icinde kalmak icin 100 yil. */
    static final Duration FOREVER = Duration.ofDays(365L * 100);

    private final ConversationMemberRepository members;
    private final MessageRepository messages;
    private final ConversationService conversations;
    private final BlockService blocks;
    private final ConversationRepository convs;

    public ConversationPrefsService(ConversationMemberRepository members, MessageRepository messages,
                                    ConversationService conversations, BlockService blocks,
                                    ConversationRepository convs) {
        this.blocks = blocks;
        this.convs = convs;
        this.members = members;
        this.messages = messages;
        this.conversations = conversations;
    }

    /** Okunmamis rozet onbellegi (setter enjeksiyonu; yoksa atlanir). */
    private UnreadBadgeCache badgeCache;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setBadgeCache(UnreadBadgeCache badgeCache) {
        this.badgeCache = badgeCache;
    }

    private void evictBadge(Long userId) {
        if (badgeCache != null) {
            badgeCache.evict(userId);
        }
    }

    /**
     * Sessiz konusma kurali: WebSocket teslimi ve okunmamis sayaci DEGISMEZ; push ve uygulama ici bildirim
     * olusturulmaz. Rozet toplami (`total`) sessizdekileri disarida birakir, `mutedTotal` ayri doner.
     */
    public UnreadSummary unreadSummary(Long userId) {
        // T-026: bekleyen istekler rozete girmez (kabul edilene kadar yok)
        List<ConversationMember> mine = members.findByUserIdAndLeftAtIsNull(userId).stream()
                .filter(ConversationMember::isAccepted).toList();
        if (mine.isEmpty()) {
            return new UnreadSummary(0, 0, List.of(), 0, 0);
        }
        // Liste satirlariyla AYNI sorgu ve ayni engel filtresi: sayilar birebir tutarli
        List<Long> ids = mine.stream().map(ConversationMember::getConversationId).toList();
        Map<Long, Long> unread = new HashMap<>();
        for (Object[] row : messages.unreadCounts(userId, ids,
                MessageRepository.excludedSenders(blocks.hiddenFrom(userId)))) {
            unread.put((Long) row[0], ((Number) row[1]).longValue());
        }
        long total = 0;
        long mutedTotal = 0;
        long archivedUnreadChats = 0;
        List<UnreadItem> items = new ArrayList<>();
        for (ConversationMember m : mine) {
            long n = unread.getOrDefault(m.getConversationId(), 0L);
            if (n == 0) {
                continue;
            }
            boolean muted = m.isMuted();
            boolean archived = m.getArchivedAt() != null;
            if (archived) {
                archivedUnreadChats++; // arsiv cubugu: sohbet basina 1 (rozet toplamina girmez)
            } else if (muted) {
                mutedTotal += n;
            } else {
                total += n;
            }
            items.add(new UnreadItem(m.getConversationId(), n, muted, archived));
        }
        boolean anyArchived = mine.stream().anyMatch(m -> m.getArchivedAt() != null);
        long archivedChats = anyArchived ? convs.countArchived(userId) : 0;
        return new UnreadSummary(total, mutedTotal, items, archivedChats, archivedUnreadChats);
    }

    /** Rozet toplami bu degerden buyukse "99+" gosterilir: sayim da burada kesilir (istemciler n > 99 icin 99+ yazar). */
    public static final long BADGE_CAP = 100;

    /**
     * Ana sayfa rozeti icin hafif sayim: SESSIZ konusmalar sorguya hic girmez (yalniz `total` kullanildigindan
     * sessizlerin sayilmasi bosuna; arsivdekiler de sayilmaz), her konusmanin katkisi ve toplam {@link #BADGE_CAP} ile sinirlanir.
     */
    public long unreadBadge(Long userId) {
        List<Long> ids = members.findByUserIdAndLeftAtIsNull(userId).stream()
                .filter(m -> !m.isMuted() && m.getArchivedAt() == null && m.isAccepted()).map(ConversationMember::getConversationId).toList();
        if (ids.isEmpty()) {
            return 0;
        }
        long total = 0;
        for (Object[] row : messages.unreadCounts(userId, ids,
                MessageRepository.excludedSenders(blocks.hiddenFrom(userId)))) {
            total += Math.min(BADGE_CAP, ((Number) row[1]).longValue());
            if (total >= BADGE_CAP) {
                return BADGE_CAP;
            }
        }
        return total;
    }

    public ConversationView mute(Long userId, Long conversationId, Integer durationMinutes, Boolean forever) {
        boolean always = Boolean.TRUE.equals(forever);
        if (always == (durationMinutes != null)
                || (durationMinutes != null && (durationMinutes < 1 || durationMinutes > MAX_MUTE_MINUTES))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR",
                    "durationMinutes (1-" + MAX_MUTE_MINUTES + ") ya da forever=true verin.");
        }
        ConversationMember m = require(conversationId, userId);
        m.setMutedUntil(Instant.now().plus(always ? FOREVER : Duration.ofMinutes(durationMinutes)));
        members.updateMute(conversationId, userId, m.getMutedUntil());
        evictBadge(userId);
        return view(userId, conversationId);
    }

    public ConversationView unmute(Long userId, Long conversationId) {
        ConversationMember m = require(conversationId, userId);
        m.setMutedUntil(null);
        members.updateMute(conversationId, userId, null);
        evictBadge(userId);
        return view(userId, conversationId);
    }

    /**
     * Arsivle. Arsivli konusma yeni mesajla arsivden CIKMAZ ve bildirim uretmez (WhatsApp gibi); `keepArchived`
     * eski istemciler icin kabul edilir ama artik etkisizdir (her arsiv "yapiskan" kaydedilir).
     */
    public ConversationView archive(Long userId, Long conversationId, boolean keepArchived) {
        ConversationMember m = require(conversationId, userId);
        m.setArchivedAt(Instant.now());
        m.setArchiveSticky(true);
        members.updateArchive(conversationId, userId, m.getArchivedAt(), true);
        evictBadge(userId);
        return view(userId, conversationId);
    }

    public ConversationView unarchive(Long userId, Long conversationId) {
        ConversationMember m = require(conversationId, userId);
        m.setArchivedAt(null);
        m.setArchiveSticky(false);
        members.updateArchive(conversationId, userId, null, false);
        evictBadge(userId);
        return view(userId, conversationId);
    }

    private ConversationView view(Long userId, Long conversationId) {
        // FIX-P03 (A02#7): hafif tekil gorunum (detail() tum uyeleri + kullanicilari + gizlilik kararlarini yukluyordu)
        return conversations.view(userId, conversationId);
    }

    private ConversationMember require(Long conversationId, Long userId) {
        return members.findByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı."));
    }
}
