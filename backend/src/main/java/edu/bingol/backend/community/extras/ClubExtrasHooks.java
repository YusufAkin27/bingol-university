package edu.bingol.backend.community.extras;

import edu.bingol.backend.community.ClubDeletedEvent;
import edu.bingol.backend.community.ClubMemberLeftEvent;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomKind;
import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Uyelik degisimlerini kulup sohbet odasina ve basvuru yanitlarina yansitan kanca. CommunityService / ClubInviteService
 * uyelik satirini yazdiktan sonra cagirir. Servis sozlesmesi: hicbir kanca exception sizdirmaz; oda senkronu
 * basarisiz olsa uyelik islemi bozulmaz (bir sonraki degisimde / GET chat-room ile duzelir).
 *
 * <p>FIX-P05 (A05#8): oda senkronu uyelik islemiyle AYNI islemde degil, commit SONRASI ve ayri (REQUIRES_NEW) islemde
 * calisir. Eskiden oda sorgusundaki DB hatasi (kilit zaman asimi, benzersizlik yarisi) catch ile yutulsa bile ortak
 * islemi rollback-only yapiyor; join/decide commit'te 500 verip uyeligi de geri aliyordu. Aktif islem yoksa (birim
 * testleri, elle cagri) senkron calisir. Basvuru yanitlarinin silinmesi KVKK geregi uyelik islemiyle birlikte kalir.
 */
@Component
public class ClubExtrasHooks {

    private static final Logger log = LoggerFactory.getLogger(ClubExtrasHooks.class);
    private static final int PAGE = 500;

    private final RoomConversations rooms;
    private final CommunityRepository communities;
    private final ClubMemberQueryRepository memberQuery;
    private final ClubJoinAnswerRepository answers;
    private final ApplicationEventPublisher events;

    /** Commit sonrasi ayri islem sablonu; islem yoneticisi yoksa (elle kurulan testler) dogrudan calisir. */
    private TransactionTemplate isolatedTx;

    public ClubExtrasHooks(RoomConversations rooms, CommunityRepository communities,
                           ClubMemberQueryRepository memberQuery, ClubJoinAnswerRepository answers,
                           ApplicationEventPublisher events) {
        this.events = events;
        this.rooms = rooms;
        this.communities = communities;
        this.memberQuery = memberQuery;
        this.answers = answers;
    }

    @Autowired(required = false)
    void setTxManager(PlatformTransactionManager tm) {
        if (tm != null) {
            this.isolatedTx = new TransactionTemplate(tm);
            this.isolatedTx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        }
    }

    /**
     * Oda senkronunu commit sonrasina erteler (islem yoksa hemen) ve ayri islemde calistirir. Is kendi exception'larini
     * yutar; ayri islemin commit hatasi (rollback-only) burada loglanir.
     */
    private void later(String what, Runnable work) {
        Runnable safe = () -> {
            try {
                if (isolatedTx == null) {
                    work.run();
                } else {
                    isolatedTx.executeWithoutResult(s -> work.run());
                }
            } catch (RuntimeException e) {
                log.warn("Kulup oda senkronu basarisiz ({}): {}", what, e.toString());
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    safe.run();
                }
            });
        } else {
            safe.run();
        }
    }

    /** Kulup yayina girdi (veya oda ilk istekte kuruluyor): odayi kurar ve tum aktif uyeleri ekler. */
    public void onCommunityActivated(Community c) {
        later("activate " + c.getId(), () -> doActivate(c));
    }

    private void doActivate(Community c) {
        try {
            rooms.ensureRoom(RoomKind.COMMUNITY, c.getId(), c.getName(), c.getOwnerId());
            rooms.addMembers(RoomKind.COMMUNITY, c.getId(), activeUserIds(c.getId()));
        } catch (RuntimeException e) {
            log.warn("Kulup sohbet odasi kurulamadi (kulup {}): {}", c.getId(), e.toString());
            throw e; // ayri islem geri alinsin (kismi oda yazimi kalmasin)
        }
    }

    /** Kullanici kulubun ACTIVE uyesi oldu (acik katilim, onay, davet). */
    public void onMemberActivated(Long communityId, Long userId) {
        later("member+ " + communityId + "/" + userId, () -> {
            try {
                if (rooms.find(RoomKind.COMMUNITY, communityId).isPresent()) {
                    rooms.addMember(RoomKind.COMMUNITY, communityId, userId);
                } else {
                    communities.findById(communityId).filter(c -> c.getStatus() == Community.Status.ACTIVE)
                            .ifPresent(this::doActivate);
                }
            } catch (RuntimeException e) {
                log.warn("Odaya eklenemedi (kulup {}, kullanici {}): {}", communityId, userId, e.toString());
                throw e;
            }
        });
    }

    /**
     * Kullanici uyelikten dustu (ayrildi, cikarildi, yasaklandi, istegi reddedildi): odadan cikar, basvuru yanitlarini
     * sil (KVKK veri azaltma).
     */
    public void onMemberGone(Long communityId, Long userId) {
        later("member- " + communityId + "/" + userId, () -> {
            try {
                rooms.removeMember(RoomKind.COMMUNITY, communityId, userId);
            } catch (RuntimeException e) {
                log.warn("Odadan cikarilamadi (kulup {}, kullanici {}): {}", communityId, userId, e.toString());
                throw e;
            }
        });
        dropAnswers(communityId, userId);
        try {
            events.publishEvent(new ClubMemberLeftEvent(communityId, userId));
        } catch (RuntimeException e) {
            // Dis dinleyici (ornegin etkinlik odalari) hatasi uyelik islemini bozmaz.
            log.warn("Uyelik olayi dinleyicisi hata verdi (kulup {}, kullanici {}): {}", communityId, userId, e.toString());
        }
    }

    /** Yalniz basvuru yanitlarini siler (uyelik odayi etkilemiyorsa, ornegin reddedilen bekleyen istek). */
    public void dropAnswers(Long communityId, Long userId) {
        try {
            answers.deleteMember(communityId, userId);
        } catch (RuntimeException e) {
            log.warn("Basvuru yanitlari silinemedi (kulup {}, kullanici {}): {}", communityId, userId, e.toString());
        }
    }

    /** Kulup silindi: sohbet odasi kapanir (herkes cikar, kimse goremez); bagli etkinlikler olay dinleyicisinde iptal edilir. */
    public void onCommunityDeleted(Community c) {
        later("delete " + c.getId(), () -> {
            try {
                rooms.closeRoom(RoomKind.COMMUNITY, c.getId());
            } catch (RuntimeException e) {
                log.warn("Kulup odasi kapatilamadi (kulup {}): {}", c.getId(), e.toString());
                throw e;
            }
        });
        try {
            events.publishEvent(new ClubDeletedEvent(c.getId()));
        } catch (RuntimeException e) {
            log.warn("Kulup silme olayi dinleyicisi hata verdi (kulup {}): {}", c.getId(), e.toString());
        }
    }

    public void onRenamed(Community c) {
        later("rename " + c.getId(), () -> {
            try {
                rooms.renameRoom(RoomKind.COMMUNITY, c.getId(), c.getName());
            } catch (RuntimeException e) {
                log.warn("Oda basligi guncellenemedi (kulup {}): {}", c.getId(), e.toString());
                throw e;
            }
        });
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
