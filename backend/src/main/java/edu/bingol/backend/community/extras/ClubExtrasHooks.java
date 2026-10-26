package edu.bingol.backend.community.extras;

import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomKind;
import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

/**
 * Uyelik degisimlerini kulup sohbet odasina ve basvuru yanitlarina yansitan kanca. CommunityService / ClubInviteService
 * uyelik satirini yazdiktan sonra cagirir (ayni islemde). Servis sozlesmesi: hicbir kanca exception sizdirmaz;
 * oda senkronu basarisiz olsa uyelik islemi bozulmaz (bir sonraki degisimde / GET chat-room ile duzelir).
 */
@Component
public class ClubExtrasHooks {

    private static final Logger log = LoggerFactory.getLogger(ClubExtrasHooks.class);
    private static final int PAGE = 500;

    private final RoomConversations rooms;
    private final CommunityRepository communities;
    private final ClubMemberQueryRepository memberQuery;
    private final ClubJoinAnswerRepository answers;

    public ClubExtrasHooks(RoomConversations rooms, CommunityRepository communities,
                           ClubMemberQueryRepository memberQuery, ClubJoinAnswerRepository answers) {
        this.rooms = rooms;
        this.communities = communities;
        this.memberQuery = memberQuery;
        this.answers = answers;
    }

    /** Kulup yayina girdi (veya oda ilk istekte kuruluyor): odayi kurar ve tum aktif uyeleri ekler. */
    public void onCommunityActivated(Community c) {
        try {
            rooms.ensureRoom(RoomKind.COMMUNITY, c.getId(), c.getName(), c.getOwnerId());
            rooms.addMembers(RoomKind.COMMUNITY, c.getId(), activeUserIds(c.getId()));
        } catch (RuntimeException e) {
            log.warn("Kulup sohbet odasi kurulamadi (kulup {}): {}", c.getId(), e.toString());
        }
    }

    /** Kullanici kulubun ACTIVE uyesi oldu (acik katilim, onay, davet). */
    public void onMemberActivated(Long communityId, Long userId) {
        try {
            if (rooms.find(RoomKind.COMMUNITY, communityId).isPresent()) {
                rooms.addMember(RoomKind.COMMUNITY, communityId, userId);
            } else {
                communities.findById(communityId).filter(c -> c.getStatus() == Community.Status.ACTIVE)
                        .ifPresent(this::onCommunityActivated);
            }
        } catch (RuntimeException e) {
            log.warn("Odaya eklenemedi (kulup {}, kullanici {}): {}", communityId, userId, e.toString());
        }
    }

    /**
     * Kullanici uyelikten dustu (ayrildi, cikarildi, yasaklandi, istegi reddedildi): odadan cikar, basvuru yanitlarini
     * sil (KVKK veri azaltma).
     */
    public void onMemberGone(Long communityId, Long userId) {
        try {
            rooms.removeMember(RoomKind.COMMUNITY, communityId, userId);
        } catch (RuntimeException e) {
            log.warn("Odadan cikarilamadi (kulup {}, kullanici {}): {}", communityId, userId, e.toString());
        }
        dropAnswers(communityId, userId);
    }

    /** Yalniz basvuru yanitlarini siler (uyelik odayi etkilemiyorsa, ornegin reddedilen bekleyen istek). */
    public void dropAnswers(Long communityId, Long userId) {
        try {
            answers.deleteMember(communityId, userId);
        } catch (RuntimeException e) {
            log.warn("Basvuru yanitlari silinemedi (kulup {}, kullanici {}): {}", communityId, userId, e.toString());
        }
    }

    public void onRenamed(Community c) {
        try {
            rooms.renameRoom(RoomKind.COMMUNITY, c.getId(), c.getName());
        } catch (RuntimeException e) {
            log.warn("Oda basligi guncellenemedi (kulup {}): {}", c.getId(), e.toString());
        }
    }

    /** Kulubun tum etkin (hesabi aktif) uyelerinin kullanici id'leri. */
    List<Long> activeUserIds(Long communityId) {
        List<Long> all = new ArrayList<>();
        long after = 0;
        while (true) {
            List<Long> page = memberQuery.activeUserIdsAfter(communityId, after, PageRequest.of(0, PAGE));
            all.addAll(page);
            if (page.size() < PAGE) {
                return all;
            }
            after = page.get(page.size() - 1);
        }
    }
}
