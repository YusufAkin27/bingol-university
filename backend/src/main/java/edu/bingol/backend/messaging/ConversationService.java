package edu.bingol.backend.messaging;

import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.ShortTx;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationDetail;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.dto.MessagingDtos.MemberView;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.UserSummary;
import edu.bingol.backend.messaging.media.AttachmentView;
import edu.bingol.backend.messaging.media.MessageAttachmentService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Konusma olusturma/listeleme ve grup yonetimi. Yonetici = grubu olusturan (ayrilirsa en eski uye devralir).
 * Engelli birebir konusmalar listede KALIR (`blocked=true`), gecmis okunabilir ama gonderim 403 BLOCKED olur.
 */
@Service
public class ConversationService {

    public static final int MAX_MEMBERS = 50;
    private static final java.util.EnumSet<edu.bingol.backend.profile.privacy.AvatarVisibility.Field> PROFILE_FIELDS =
            java.util.EnumSet.of(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.AVATAR,
                    edu.bingol.backend.profile.privacy.AvatarVisibility.Field.DEPARTMENT,
                    edu.bingol.backend.profile.privacy.AvatarVisibility.Field.CLASS_YEAR);
    /** T-025: kullanici basina gunde acilabilecek YENI birebir konusma (yeni karsi taraf) ve yeni grup sayisi (eskiden 30). */
    static final int NEW_CONVERSATIONS_PER_DAY = 10;
    /** T-025: grup uye ekleme cagrisi gunluk tavani. */
    static final int ADD_MEMBER_CALLS_PER_DAY = 30;

    /** `created` false ise birebir konusma zaten vardi. */
    public record Opened(ConversationView conversation, boolean created) {}

    private final ConversationRepository convs;
    private final ConversationMemberRepository members;
    private final MessageRepository messages;
    private final UserRepository users;
    private final BlockService blocks;
    private final MessageCodec codec;
    /** T8: son mesaj onizlemesinde gorsel ekleri (setter enjeksiyonu; yoksa eksiz). */
    private MessageAttachmentService attachments;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAttachments(MessageAttachmentService attachments) {
        this.attachments = attachments;
    }

    /** Kulup/etkinlik odasi baglantilari: gorunumde tur (CLUB/EVENT) ve kaynak kimligi buradan turetilir. */
    private edu.bingol.backend.messaging.room.ChatRoomLinkRepository roomLinks;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setRoomLinks(edu.bingol.backend.messaging.room.ChatRoomLinkRepository roomLinks) {
        this.roomLinks = roomLinks;
    }

    /** Grup fotografi (herkese acik avatar hatti) ve uyelere olay bildirimi (setter enjeksiyonu; yoksa ozellik kapali). */
    private edu.bingol.backend.media.MediaService media;
    private edu.bingol.backend.messaging.ws.ChatEventBus bus;

    /** Kisa DB islemi (T-068: gorsel isleme islem disinda); yoksa dogrudan calisir (elle kurulan testler). */
    private ShortTx tx = ShortTx.direct();

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setTxManager(org.springframework.transaction.PlatformTransactionManager tm) {
        this.tx = ShortTx.of(tm);
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMedia(edu.bingol.backend.media.MediaService media) {
        this.media = media;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setBus(edu.bingol.backend.messaging.ws.ChatEventBus bus) {
        this.bus = bus;
    }

    private ReceiptService receipts;

    /** Profil gizlilik karari (bolum/sinif); yoksa alanlar gonderilmez. */
    private edu.bingol.backend.profile.privacy.AvatarVisibility visibility;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setVisibility(edu.bingol.backend.profile.privacy.AvatarVisibility visibility) {
        this.visibility = visibility;
    }

    /** Birebir karsi tarafin cevrimici noktasi (tek MGET; yoksa alan gonderilmez). */
    private edu.bingol.backend.messaging.ws.PresenceService presence;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setPresence(edu.bingol.backend.messaging.ws.PresenceService presence) {
        this.presence = presence;
    }

    /** T-025: cikan/cikarilan uyeyi onu ekleyen kisinin yeniden eklemesini engelleyen kayitlar (yoksa kontrol yok). */
    private ConversationAddBanRepository addBans;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAddBans(ConversationAddBanRepository addBans) {
        this.addBans = addBans;
    }

    /** T-025: yeni karsi taraf / grup sayisi gunluk siniri (yoksa uygulanmaz). */
    private edu.bingol.backend.common.RateLimiter limiter;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setLimiter(edu.bingol.backend.common.RateLimiter limiter) {
        this.limiter = limiter;
    }

    /** C1: kulup/etkinlik odasi moderasyon yetkisi (yoksa odada canModerate=false). */
    private edu.bingol.backend.messaging.room.RoomModeration roomModeration;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setRoomModeration(edu.bingol.backend.messaging.room.RoomModeration roomModeration) {
        this.roomModeration = roomModeration;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setReceipts(ReceiptService receipts) {
        this.receipts = receipts;
    }

    /** Herkese acik metin denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

    public ConversationService(ConversationRepository convs, ConversationMemberRepository members,
                               MessageRepository messages, UserRepository users, BlockService blocks, MessageCodec codec) {
        this.codec = codec;
        this.convs = convs;
        this.members = members;
        this.messages = messages;
        this.users = users;
        this.blocks = blocks;
    }

    /** Birebir konusmayi acar; varsa mevcudu doner. Benzersiz `direct_key` yaris kosulunda cift olusmasini onler. */
    @Transactional
    public Opened openDirect(Long me, Long otherId) {
        if (otherId == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "userId gerekli.");
        }
        if (me.equals(otherId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CANNOT_MESSAGE_SELF", "Kendinizle konuşma başlatamazsınız.");
        }
        requireMessageable(List.of(otherId));
        // Golge engel: engel iliskisinde de konusma acilir (mesajlar gonderimde bastirilir)
        String key = Conversation.directKey(me, otherId);
        boolean created = convs.insertDirect(key, me, Instant.now()) == 1;
        Conversation c = convs.findByDirectKey(key).orElseThrow();
        if (created) {
            // Yeni karsi taraf: gunluk sinir (islem geri alinir; mevcut konusmayi yeniden acmak sayilmaz)
            limitDaily("conv:newpeer:", me);
            members.save(ConversationMember.of(c.getId(), me, ConversationMember.Role.MEMBER));
            members.save(ConversationMember.of(c.getId(), otherId, ConversationMember.Role.MEMBER));
        }
        return new Opened(views(me, List.of(c)).get(0), created);
    }

    @Transactional
    public ConversationView createGroup(Long me, String title, List<Long> memberIds) {
        String t = title == null ? "" : title.trim();
        if (t.isEmpty() || t.length() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Grup başlığı 1-100 karakter olmalı.");
        }
        ContentGuard.clean(guard, Entity.GROUP_TITLE, "title", me, t);
        Set<Long> ids = new LinkedHashSet<>(memberIds == null ? List.of() : memberIds);
        ids.remove(me);
        if (ids.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "En az bir üye ekleyin.");
        }
        if (ids.size() + 1 > MAX_MEMBERS) {
            throw groupFull();
        }
        requireMessageable(ids);
        Set<Long> addable = addable(me, ids);
        limitDaily("conv:newgroup:", me);

        Conversation c = new Conversation();
        c.setType(Conversation.Type.GROUP);
        c.setTitle(t);
        c.setCreatedBy(me);
        c = convs.save(c);
        members.save(ConversationMember.of(c.getId(), me, ConversationMember.Role.ADMIN));
        for (Long id : addable) {
            ConversationMember m = ConversationMember.of(c.getId(), id, ConversationMember.Role.MEMBER);
            m.setAddedBy(me);
            members.save(m);
        }
        return views(me, List.of(c)).get(0);
    }

    /** Mesaji olan konusmalar, en yeni mesaj once. Imlec = onceki sayfanin son `lastMessage.id` degeri. */
    @Transactional(readOnly = true)
    public CursorPage<ConversationView> list(Long me, Long cursor, int size) {
        return list(me, cursor, size, false);
    }

    /** `archived` true: yalniz arsivdekiler; false: arsivdekiler listelenmez. */
    @Transactional(readOnly = true)
    public CursorPage<ConversationView> list(Long me, Long cursor, int size, boolean archived) {
        int s = CursorPage.clampSize(size);
        List<Conversation> rows = convs.page(me, cursor, archived, PageRequest.of(0, s + 1));
        boolean more = rows.size() > s;
        List<Conversation> page = more ? rows.subList(0, s) : rows;
        Long next = null;
        if (more) {
            Conversation lastRow = page.get(page.size() - 1);
            next = lastKey(lastRow, members.findByConversationIdAndUserId(lastRow.getId(), me).stream().toList(), me);
        }
        return new CursorPage<>(views(me, page), next);
    }

    @Transactional(readOnly = true)
    public ConversationDetail detail(Long me, Long id) {
        requireMember(id, me);
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        List<ConversationMember> active = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(id);
        Map<Long, User> byId = users.findAllById(active.stream().map(ConversationMember::getUserId).toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        Set<Long> hidden = blocks.hiddenFrom(me); // engel iliskisi olanin avatari gorunmez
        Set<Long> deptOk = Set.of();
        Set<Long> yearOk = Set.of();
        Set<Long> avatarOk = Set.of(); // T-027: gizlilik karari yoksa avatar GONDERILMEZ (fail-closed)
        if (visibility != null && !byId.isEmpty()) {
            var vis = visibility.visibleOwners(me, byId.keySet(), PROFILE_FIELDS);
            deptOk = vis.get(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.DEPARTMENT);
            yearOk = vis.get(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.CLASS_YEAR);
            avatarOk = vis.get(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.AVATAR);
        }
        final Set<Long> deptVisible = deptOk;
        final Set<Long> yearVisible = yearOk;
        final Set<Long> avatarVisible = avatarOk;
        List<MemberView> list = active.stream().filter(m -> byId.containsKey(m.getUserId()))
                .map(m -> {
                    Long uid = m.getUserId();
                    boolean shown = !hidden.contains(uid);
                    return new MemberView(uid, byId.get(uid).getDisplayName(),
                            shown && avatarVisible.contains(uid) ? byId.get(uid).getAvatarUrl() : null,
                            m.getRole().name(), shown && deptVisible.contains(uid) ? byId.get(uid).getDepartment() : null,
                            shown && yearVisible.contains(uid) ? byId.get(uid).getClassYear() : null);
                }).toList();
        return new ConversationDetail(views(me, List.of(c)).get(0), list);
    }

    /** Tek konusmanin gorunumu (yalnizca aktif uye). Kulup/etkinlik sohbet uclari kullanir. */
    @Transactional(readOnly = true)
    public ConversationView view(Long me, Long id) {
        requireMember(id, me);
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        return views(me, List.of(c)).get(0);
    }

    @Transactional
    public ConversationView rename(Long me, Long id, String title) {
        Conversation c = requireUserGroupAdmin(id, me);
        String t = title == null ? "" : title.trim();
        if (t.isEmpty() || t.length() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Grup başlığı 1-100 karakter olmalı.");
        }
        ContentGuard.changed(guard, Entity.GROUP_TITLE, "title", me, c.getTitle(), t);
        c.setTitle(t);
        convs.save(c);
        notifyUpdated(c, me);
        return views(me, List.of(c)).get(0);
    }

    /** Grup fotografi (yalniz kullanici gruplari, yalniz yonetici). Avatar hattindan gecer: tur/boyut, yeniden kodlama, EXIF. */
    public ConversationView setAvatar(Long me, Long id, org.springframework.web.multipart.MultipartFile file) {
        requireUserGroupAdmin(id, me);
        if (media == null) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "STORAGE_UNAVAILABLE", "Depolama kullanılamıyor.");
        }
        // T-068: gorsel isleme islem DISINDA; yetki kisa islemde yeniden dogrulanir, yalniz URL yazimi islemdedir
        String url = media.storeImage(file, edu.bingol.backend.media.ImageKind.AVATAR).url();
        ShortTx.Replaced<ConversationView> r = tx.call(() -> {
            Conversation c = requireUserGroupAdmin(id, me);
            String old = c.getAvatarUrl();
            c.setAvatarUrl(url);
            convs.saveAndFlush(c);
            notifyUpdated(c, me);
            return new ShortTx.Replaced<>(views(me, List.of(c)).get(0), old);
        });
        if (r.old() != null && !r.old().equals(url)) {
            media.release(r.old());
        }
        return r.value();
    }

    /** Grup fotografini kaldirir (idempotent). */
    @Transactional
    public void removeAvatar(Long me, Long id) {
        Conversation c = requireUserGroupAdmin(id, me);
        String old = c.getAvatarUrl();
        if (old == null) {
            return;
        }
        c.setAvatarUrl(null);
        convs.saveAndFlush(c);
        if (media != null) {
            media.release(old);
        }
        notifyUpdated(c, me);
    }

    @Transactional
    public ConversationView addMembers(Long me, Long id, List<Long> userIds) {
        Conversation c = requireGroupAdmin(id, me);
        convs.lockById(id); // uye sayisi siniri es zamanli eklemelerde asilmasin
        Set<Long> ids = new LinkedHashSet<>(userIds);
        ids.remove(me);
        if (ids.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Eklenecek üye yok.");
        }
        requireMessageable(ids);
        limitDaily("conv:addmem:", me, ADD_MEMBER_CALLS_PER_DAY);
        // Beni engelleyenler ve cikisindan sonra beni yeniden eklememe yasagi olanlar SESSIZCE atlanir (T-025/T-028)
        ids = addable(me, ids);

        long current = members.countByConversationIdAndLeftAtIsNull(id);
        final Set<Long> toAdd = ids;
        long adding = toAdd.stream().filter(uid -> members.findByConversationIdAndUserIdAndLeftAtIsNull(id, uid).isEmpty()).count();
        if (current + adding > MAX_MEMBERS) {
            throw groupFull();
        }
        for (Long uid : toAdd) {
            ConversationMember m = members.findByConversationIdAndUserId(id, uid).orElse(null);
            if (m == null) {
                m = ConversationMember.of(id, uid, ConversationMember.Role.MEMBER);
            } else if (m.getLeftAt() == null) {
                continue; // zaten uye
            } else {
                // Yeniden ekleme: onceki mesajlar okunmamis sayilmaz, onceki gecmis gorunmez.
                m.setLeftAt(null);
                m.setJoinedAt(Instant.now());
                m.setRole(ConversationMember.Role.MEMBER);
            }
            m.setAddedBy(me);
            m.setHiddenAt(null); // sohbeti silmis olsa da yeniden eklenince listede gorunur
            m.setLastReadMessageId(c.getLastMessageId() == null ? 0L : c.getLastMessageId());
            m.setLastDeliveredMessageId(m.getLastReadMessageId());
            members.save(m);
        }
        return views(me, List.of(c)).get(0);
    }

    /** Yonetici baskasini cikarir; kendi id'si verilirse ayrilma sayilir. */
    @Transactional
    public void removeMember(Long me, Long id, Long targetId) {
        if (me.equals(targetId)) {
            leave(me, id);
            return;
        }
        requireGroupAdmin(id, me);
        ConversationMember target = members.findByConversationIdAndUserIdAndLeftAtIsNull(id, targetId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "MEMBER_NOT_FOUND", "Üye bulunamadı."));
        target.setLeftAt(Instant.now());
        members.save(target);
        recordAddBan(target, id);
        notifyRemoved(id, List.of(targetId)); // C3: cikarilan uyenin istemcisi sohbeti kapatsin
    }

    /** Gruptan ayril. Yonetici ayrilirsa en eski uye yonetici olur. */
    @Transactional
    public void leave(Long me, Long id) {
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        ConversationMember self = requireMember(id, me);
        // Kulup/etkinlik odasindan elle ayrilinmaz: uyelik kaynaga (kulup/RSVP) bagli, oradan senkronlanir.
        if (c.getType() != Conversation.Type.GROUP || (roomLinks != null && !roomLinks.findByConversationIdIn(List.of(id)).isEmpty())) {
            throw notGroup();
        }
        self.setLeftAt(Instant.now());
        members.save(self);
        recordAddBan(self, id);
        notifyRemoved(id, List.of(me)); // C3: kullanicinin diger cihazlari da sohbeti kapatsin
        if (self.isAdmin()) {
            List<ConversationMember> rest = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(id);
            if (!rest.isEmpty() && rest.stream().noneMatch(ConversationMember::isAdmin)) {
                rest.get(0).setRole(ConversationMember.Role.ADMIN);
                members.save(rest.get(0));
            }
        }
    }

    /**
     * "Sohbeti sil" (yalniz cagiran icin; idempotent). Birebir: imlec son mesaja alinir ve konusma listeden gizlenir;
     * karsi taraf ve mesajlar degismez, yeni mesajla konusma yalniz yeni mesajlarla yeniden belirir. Kullanici grubu:
     * {@link #leave} ile ayni etki + gizleme. Kulup/etkinlik odasi: 400 CONVERSATION_NOT_DELETABLE. Uye degilse 404.
     * Sessize alma / arsiv durumu sifirlanir.
     */
    @Transactional
    public void delete(Long me, Long id) {
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        ConversationMember self = members.findByConversationIdAndUserId(id, me).orElseThrow(ConversationService::notFound);
        if (roomLinks != null && !roomLinks.findByConversationIdIn(List.of(id)).isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CONVERSATION_NOT_DELETABLE",
                    "Kulüp ve etkinlik sohbetleri silinemez.");
        }
        if (c.getType() == Conversation.Type.GROUP && self.getLeftAt() == null) {
            leave(me, id);
            self = members.findByConversationIdAndUserId(id, me).orElseThrow(ConversationService::notFound);
        } else if (c.getType() == Conversation.Type.DIRECT && self.getLeftAt() != null) {
            throw notFound();
        }
        long last = c.getLastMessageId() == null ? 0L : c.getLastMessageId();
        self.setClearedUpToMessageId(Math.max(self.getClearedUpToMessageId(), last));
        if (self.getHiddenAt() == null) {
            self.setHiddenAt(Instant.now());
        }
        self.setMutedUntil(null);
        self.setArchivedAt(null);
        self.setArchiveSticky(false);
        members.save(self);
    }

    // --- yardimcilar ---

    /** Her biri var, aktif ve e-postasi dogrulanmis olmali; yoksa 404 (hangisinin gecersiz oldugu soylenmez). */
    private void requireMessageable(Collection<Long> ids) {
        List<User> found = users.findAllById(ids);
        if (found.size() != ids.size() || found.stream().anyMatch(u -> !u.isActive() || !u.isEmailVerified())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı.");
        }
    }

    /**
     * Gruba eklenebilecekler. GOLGE ENGEL (T-028): ben engellediysem bilgilendirici 403 BLOCKED; beni engelleyen kisi
     * SESSIZCE atlanir (hata yok: engellenen taraf engellendigini ogrenmez). Cikis sonrasi yeniden ekleme yasagi olanlar
     * (T-025) da sessizce atlanir.
     */
    private Set<Long> addable(Long me, Collection<Long> ids) {
        Set<Long> related = blocks.hiddenFrom(me);
        Set<Long> out = new LinkedHashSet<>();
        for (Long id : ids) {
            if (related.contains(id)) {
                if (blocks.hasBlocked(me, id)) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "BLOCKED", "Engel ilişkisi olan kullanıcı eklenemez.");
                }
                continue;
            }
            out.add(id);
        }
        if (addBans != null && !out.isEmpty()) {
            out.removeAll(addBans.bannedUsers(me, out));
        }
        return out;
    }

    /** Gunluk sinir (RateLimiter yoksa uygulanmaz); asinca 429. */
    private void limitDaily(String prefix, Long me) {
        limitDaily(prefix, me, NEW_CONVERSATIONS_PER_DAY);
    }

    private void limitDaily(String prefix, Long me, int max) {
        if (limiter != null) {
            limiter.check(prefix + me, max, java.time.Duration.ofDays(1));
        }
    }

    /** Cikan/cikarilan uyeyi onu ekleyen kisinin tekrar eklemesini engeller (T-025). */
    private void recordAddBan(ConversationMember leaver, Long conversationId) {
        Long adder = leaver.getAddedBy();
        if (addBans == null || adder == null || adder.equals(leaver.getUserId())) {
            return;
        }
        ConversationAddBan.Key key = new ConversationAddBan.Key(leaver.getUserId(), adder);
        if (!addBans.existsById(key)) {
            addBans.save(new ConversationAddBan(leaver.getUserId(), adder, conversationId));
        }
    }

    private ConversationMember requireMember(Long conversationId, Long userId) {
        return members.findByConversationIdAndUserIdAndLeftAtIsNull(conversationId, userId)
                .orElseThrow(ConversationService::notFound);
    }

    /** Kullanici grubu yoneticisi; kulup/etkinlik odalari (kaynaga bagli) ve birebir konusmalar 400 NOT_A_GROUP. */
    private Conversation requireUserGroupAdmin(Long id, Long me) {
        Conversation c = requireGroupAdmin(id, me);
        if (roomLinks != null && !roomLinks.findByConversationIdIn(List.of(id)).isEmpty()) {
            throw notGroup();
        }
        return c;
    }

    /** Ad/foto degisikligini commit SONRASI tum aktif uyelere bildirir (`/user/queue/message-events`). */
    private void notifyUpdated(Conversation c, Long actor) {
        if (bus == null) {
            return;
        }
        afterCommit(() -> {
            try {
                List<Long> ids = members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(c.getId()).stream()
                        .map(ConversationMember::getUserId).toList();
                bus.publish("message-events", ids, new edu.bingol.backend.messaging.dto.MessagingDtos.ConversationUpdatedEvent(
                        "conversation-updated", c.getId(), actor, c.getTitle(), c.getAvatarUrl(), Instant.now().toString()));
            } catch (RuntimeException e) {
                // teslim hatasi islemi bozmaz
            }
        });
    }

    /**
     * C3: cikarilan/ayrilan kullanicilarin `/user/queue/message-events` kuyruguna conversation-removed (commit SONRASI).
     * Istemci konusmayi listeden ve acik ekrandan kaldirir; teslim hatasi islemi bozmaz.
     */
    private void notifyRemoved(Long conversationId, Collection<Long> userIds) {
        if (bus == null || userIds.isEmpty()) {
            return;
        }
        List<Long> to = List.copyOf(userIds);
        afterCommit(() -> {
            try {
                bus.publish("message-events", to, new edu.bingol.backend.messaging.dto.MessagingDtos.ConversationRemovedEvent(
                        "conversation-removed", conversationId, Instant.now().toString()));
            } catch (RuntimeException e) {
                // teslim hatasi islemi bozmaz; istemci listeyi yenileyince konusma zaten gelmez
            }
        });
    }

    private static void afterCommit(Runnable send) {
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            send.run();
                        }
                    });
        } else {
            send.run();
        }
    }

    private Conversation requireGroupAdmin(Long id, Long me) {
        ConversationMember m = requireMember(id, me);
        Conversation c = convs.findById(id).orElseThrow(ConversationService::notFound);
        if (c.getType() != Conversation.Type.GROUP) {
            throw notGroup();
        }
        if (!m.isAdmin()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "NOT_GROUP_ADMIN", "Bu işlem için grup yöneticisi olmalısınız.");
        }
        return c;
    }

    /** Toplu gorunum: uyeler, karsi taraf profilleri, son mesajlar ve okunmamis sayilari tek seferde yuklenir. */
    private List<ConversationView> views(Long me, List<Conversation> page) {
        if (page.isEmpty()) {
            return List.of();
        }
        List<Long> ids = page.stream().map(Conversation::getId).toList();
        Map<Long, List<ConversationMember>> membersBy = members.findByConversationIdInAndLeftAtIsNull(ids).stream()
                .collect(Collectors.groupingBy(ConversationMember::getConversationId));
        List<Long> peerIds = page.stream().filter(c -> c.getType() == Conversation.Type.DIRECT)
                .map(c -> peerOf(membersBy.getOrDefault(c.getId(), List.of()), me)).filter(java.util.Objects::nonNull).toList();
        Map<Long, User> peers = users.findAllById(peerIds).stream().collect(Collectors.toMap(User::getId, Function.identity()));
        // Birebir karsi tarafin cevrimici durumu: tek toplu okuma (N+1 yok); Redis yoksa bos kume
        // (T-025: gizlilik/engel/birebir karsilikliligi kurallari presence ucuyla ayni)
        Set<Long> onlinePeers = presence == null ? Set.of() : presence.onlineVisibleTo(me, peerIds);
        // Birebir karsi tarafin bolum/sinifi: tek gizlilik sorgusu (alan kapaliysa gonderilmez)
        Set<Long> deptOk = Set.of();
        Set<Long> yearOk = Set.of();
        Set<Long> avatarOk = Set.of(); // T-027: gizlilik karari yoksa avatar GONDERILMEZ (fail-closed)
        if (visibility != null && !peerIds.isEmpty()) {
            var vis = visibility.visibleOwners(me, peerIds, PROFILE_FIELDS);
            deptOk = vis.get(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.DEPARTMENT);
            yearOk = vis.get(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.CLASS_YEAR);
            avatarOk = vis.get(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.AVATAR);
        }
        final Set<Long> deptVisible = deptOk;
        final Set<Long> yearVisible = yearOk;
        final Set<Long> avatarVisible = avatarOk;
        // Golge engel: goruntuleyene gorunur son mesaj (bastirilmis mesajlar alicida yok sayilir)
        Map<Long, Long> keyBy = new HashMap<>();
        for (Conversation c : page) {
            keyBy.put(c.getId(), lastKey(c, membersBy.getOrDefault(c.getId(), List.of()), me));
        }
        Map<Long, Message> lastMessages = messages.findAllById(
                keyBy.values().stream().filter(java.util.Objects::nonNull).toList()).stream()
                .collect(Collectors.toMap(Message::getId, Function.identity()));
        codec.openAll(new java.util.ArrayList<>(lastMessages.values())); // son mesaj onizlemesi: sifre cozulur
        Map<Long, List<AttachmentView>> lastAtt = attachments == null ? Map.of() : attachments.viewsFor(me, lastMessages.keySet());
        Set<Long> related = blocks.hiddenFrom(me);
        // Son mesajim ise makbuz durumu: uyeler zaten yuklu, ek sorgu yalniz askidaki kullanici denetimi
        Map<Long, String> lastStatus = receipts == null ? Map.of() : receipts.statuses(me, lastMessages.values(), membersBy,
                page.stream().collect(Collectors.toMap(Conversation::getId, c -> c.getType() == Conversation.Type.DIRECT)));
        // Grup/kulup/etkinlik onizlemesi icin son mesaji gonderenlerin adlari: tek toplu yukleme
        Set<Long> directIds = page.stream().filter(c -> c.getType() == Conversation.Type.DIRECT).map(Conversation::getId)
                .collect(Collectors.toSet());
        Set<Long> senderIds = new java.util.HashSet<>();
        for (Conversation c : page) {
            Message lm = keyBy.get(c.getId()) == null ? null : lastMessages.get(keyBy.get(c.getId()));
            if (lm != null && !directIds.contains(c.getId()) && lm.getSenderId() != null) {
                senderIds.add(lm.getSenderId());
            }
        }
        Map<Long, String> senderNames = new HashMap<>();
        if (!senderIds.isEmpty()) {
            for (User u : users.findAllById(senderIds)) {
                senderNames.put(u.getId(), u.getDisplayName());
            }
        }
        Map<Long, Long> unread = new HashMap<>();
        for (Object[] row : messages.unreadCounts(me, ids, MessageRepository.excludedSenders(related))) {
            unread.put((Long) row[0], ((Number) row[1]).longValue());
        }
        Map<Long, edu.bingol.backend.messaging.room.ChatRoomLink> roomOf = roomLinks == null ? Map.of()
                : roomLinks.findByConversationIdIn(ids).stream().collect(Collectors.toMap(
                        edu.bingol.backend.messaging.room.ChatRoomLink::getConversationId, Function.identity(), (x, y) -> x));

        return page.stream().map(c -> {
            List<ConversationMember> ms = membersBy.getOrDefault(c.getId(), List.of());
            boolean direct = c.getType() == Conversation.Type.DIRECT;
            Long peerId = direct ? peerOf(ms, me) : null;
            UserSummary peer = peerId == null || !peers.containsKey(peerId) ? null
                    : related.contains(peerId) ? new UserSummary(peerId, peers.get(peerId).getDisplayName(), null) // engel: avatar yok
                    : UserSummary.of(peers.get(peerId)).withAvatar(
                            avatarVisible.contains(peerId) ? peers.get(peerId).getAvatarUrl() : null)
                    .withOnline(onlinePeers.contains(peerId)).withProfile(
                            deptVisible.contains(peerId) ? peers.get(peerId).getDepartment() : null,
                            yearVisible.contains(peerId) ? peers.get(peerId).getClassYear() : null);
            Message last = keyBy.get(c.getId()) == null ? null : lastMessages.get(keyBy.get(c.getId()));
            // Gruba sonradan katilan, katilmadan onceki son mesaji onizlemede de gormez (gecmisle tutarli).
            Instant joined = ms.stream().filter(m -> m.getUserId().equals(me)).map(ConversationMember::getJoinedAt)
                    .findFirst().orElse(Instant.EPOCH);
            ConversationMember mineM = ms.stream().filter(m -> m.getUserId().equals(me)).findFirst().orElse(null);
            long clearedUpTo = mineM == null ? 0L : mineM.getClearedUpToMessageId();
            MessageView lastView = last == null || last.getId() <= clearedUpTo
                    || (!direct && last.getCreatedAt().isBefore(joined)) ? null
                    : MessageView.of(last, !direct && related.contains(last.getSenderId()) && !last.getSenderId().equals(me))
                    .withAttachments(lastAtt.get(last.getId())).withStatus(lastStatus.get(last.getId()))
                    .withSenderName(direct || related.contains(last.getSenderId()) && !last.getSenderId().equals(me) ? null
                            : senderNames.get(last.getSenderId()));
            boolean admin = ms.stream().anyMatch(m -> m.getUserId().equals(me) && m.isAdmin());
            ConversationMember mine = ms.stream().filter(m -> m.getUserId().equals(me)).findFirst().orElse(null);
            boolean muted = mine != null && mine.isMuted();
            var room = roomOf.get(c.getId());
            boolean club = room != null && room.getKind() == edu.bingol.backend.messaging.room.RoomKind.COMMUNITY;
            boolean event = room != null && room.getKind() == edu.bingol.backend.messaging.room.RoomKind.EVENT;
            String type = club ? "CLUB" : event ? "EVENT" : c.getType().name();
            // Golge engel (T-028): `blocked` yalniz ENGELLEYEN tarafta true; engellenen taraf bunu goremez
            boolean iBlockedPeer = direct && peerId != null && related.contains(peerId) && blocks.hasBlocked(me, peerId);
            // C1: oda moderatoru/organizatoru ya da grup yoneticisi baskasinin mesajini silebilir; birebirde yok
            boolean canModerate = !direct && (room != null
                    ? roomModeration != null && roomModeration.canModerate(c.getId(), me) : admin);
            return new ConversationView(c.getId(), type, c.getTitle(), peer, ms.size(), admin, lastView,
                    unread.getOrDefault(c.getId(), 0L), iBlockedPeer,
                    c.getCreatedAt().toString(), muted, muted ? mine.getMutedUntil().toString() : null,
                    mine != null && mine.getArchivedAt() != null, mine != null && mine.isMutedForever(),
                    club ? room.getRefId() : null, event ? room.getRefId() : null, c.getAvatarUrl(), canModerate);
        }).toList();
    }

    /**
     * Goruntuleyenin listede gorecegi son mesaj kimligi. Golge engel yoksa `lastMessageId`; varsa gorunur son mesaj ile
     * goruntuleyenin kendi bastirilmis son mesajindan buyugu. Yoksa null.
     */
    static Long lastKey(Conversation c, List<ConversationMember> ms, Long me) {
        if (!c.isShadowed()) {
            return c.getLastMessageId();
        }
        long vis = c.getLastVisibleMessageId() == null ? 0L : c.getLastVisibleMessageId();
        long own = ms.stream().filter(m -> m.getUserId().equals(me)).mapToLong(ConversationMember::getLastOwnSuppressedMessageId)
                .findFirst().orElse(0L);
        long k = Math.max(vis, own);
        return k > 0 ? k : null;
    }

    private static Long peerOf(List<ConversationMember> ms, Long me) {
        return ms.stream().map(ConversationMember::getUserId).filter(id -> !id.equals(me)).findFirst().orElse(null);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı.");
    }

    private static ApiException notGroup() {
        return new ApiException(HttpStatus.BAD_REQUEST, "NOT_A_GROUP", "Bu işlem yalnızca gruplarda yapılabilir.");
    }

    private static ApiException groupFull() {
        return new ApiException(HttpStatus.BAD_REQUEST, "GROUP_FULL", "Bir grupta en fazla " + MAX_MEMBERS + " üye olabilir.",
                String.valueOf(MAX_MEMBERS));
    }
}
