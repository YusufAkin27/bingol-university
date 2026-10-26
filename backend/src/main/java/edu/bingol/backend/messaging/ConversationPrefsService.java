package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.dto.MessagingDtos.UnreadItem;
import edu.bingol.backend.messaging.dto.MessagingDtos.UnreadSummary;
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

    public ConversationPrefsService(ConversationMemberRepository members, MessageRepository messages,
                                    ConversationService conversations) {
        this.members = members;
        this.messages = messages;
        this.conversations = conversations;
    }

    /**
     * Sessiz konusma kurali: WebSocket teslimi ve okunmamis sayaci DEGISMEZ; push ve uygulama ici bildirim
     * olusturulmaz. Rozet toplami (`total`) sessizdekileri disarida birakir, `mutedTotal` ayri doner.
     */
    public UnreadSummary unreadSummary(Long userId) {
        Map<Long, Long> unread = new HashMap<>();
        for (Object[] row : messages.unreadAll(userId)) {
            unread.put((Long) row[0], ((Number) row[1]).longValue());
        }
        long total = 0;
        long mutedTotal = 0;
        List<UnreadItem> items = new ArrayList<>();
        for (ConversationMember m : members.findByUserIdAndLeftAtIsNull(userId)) {
            long n = unread.getOrDefault(m.getConversationId(), 0L);
            if (n == 0) {
                continue;
            }
            boolean muted = m.isMuted();
            if (muted) {
                mutedTotal += n;
            } else {
                total += n;
            }
            items.add(new UnreadItem(m.getConversationId(), n, muted));
        }
        return new UnreadSummary(total, mutedTotal, items);
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
        members.save(m);
        return view(userId, conversationId);
    }

    public ConversationView unmute(Long userId, Long conversationId) {
        ConversationMember m = require(conversationId, userId);
        m.setMutedUntil(null);
        members.save(m);
        return view(userId, conversationId);
    }

    public ConversationView archive(Long userId, Long conversationId, boolean keepArchived) {
        ConversationMember m = require(conversationId, userId);
        m.setArchivedAt(Instant.now());
        m.setArchiveSticky(keepArchived);
        members.save(m);
        return view(userId, conversationId);
    }

    public ConversationView unarchive(Long userId, Long conversationId) {
        ConversationMember m = require(conversationId, userId);
        m.setArchivedAt(null);
        m.setArchiveSticky(false);
        members.save(m);
        return view(userId, conversationId);
    }

    private ConversationView view(Long userId, Long conversationId) {
        return conversations.detail(userId, conversationId).conversation();
    }

    private ConversationMember require(Long conversationId, Long userId) {
        return members.findByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı."));
    }
}
