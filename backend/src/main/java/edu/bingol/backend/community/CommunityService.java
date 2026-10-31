package edu.bingol.backend.community;

import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.extras.ClubExtrasHooks;
import edu.bingol.backend.media.ImageKind;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.community.Community.JoinPolicy;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.dto.CommunityDtos.CategoryCount;
import edu.bingol.backend.community.dto.CommunityDtos.CommunityView;
import edu.bingol.backend.community.dto.CommunityDtos.CreateCommunityRequest;
import edu.bingol.backend.community.dto.CommunityDtos.MemberView;
import edu.bingol.backend.community.dto.CommunityDtos.UpdateCommunityRequest;
import edu.bingol.backend.community.permissions.ClubAuditService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.community.permissions.ClubPermissions;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/** Topluluk yasam dongusu ve uyelik. Yetki kararlari ClubPermissions'ta; sistem ADMIN'i hepsini asar. */
@Service
public class CommunityService {

    static final int MAX_OWNED = 3;
    private static final List<Community.Status> LIVE = List.of(Community.Status.PENDING_REVIEW, Community.Status.ACTIVE);

    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final UserRepository users;
    private final BlockService blocks;
    private final NotificationService notifications;
    private final MediaService media;
    private final ClubPermissions permissions;
    private final ClubAuditService audit;
    private final ClubExtrasHooks hooks;

    /** Herkese acik metin denetimi (istege bagli: guard'siz kurulan testler icin). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private ContentGuard guard;

    /** Kategori dogrulamasi (istege bagli: null iken serbest metin, eski davranis). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private edu.bingol.backend.community.category.CommunityCategoryService categoryService;

    /** T-040: sistem yoneticisi mudahalesi denetimi (istege bagli: birim testlerinde yok). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAdminAudit(SystemAdminAudit adminAudit) {
        this.adminAudit = adminAudit;
    }

    private SystemAdminAudit adminAudit;

    void setCategoryService(edu.bingol.backend.community.category.CommunityCategoryService s) { // testler icin
        this.categoryService = s;
    }

    /** Profil gizlilik karari (bolum / sinif alanlari); yoksa (testler) alanlar gonderilmez. */
    private edu.bingol.backend.profile.privacy.AvatarVisibility visibility;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setVisibility(edu.bingol.backend.profile.privacy.AvatarVisibility visibility) {
        this.visibility = visibility;
    }

    /**
     * T-027: avatar URL'lerinin TEK karar noktasi (kulup / etkinlik DTO'lari buradan alir): engel iliskisi (`hide`) +
     * profil gizliligi (ONLY_ME / SHARED_CONTEXT) + moderasyon `avatar_hidden`. Gizlilik karari verilemiyorsa
     * (visibility yok: yalniz birim testleri) kapali basarisiz olur, avatar gonderilmez. Anahtar yoksa avatar yok.
     */
    public Map<Long, String> avatarsFor(Long viewerId, Collection<User> us, Set<Long> hide) {
        Map<Long, String> out = new HashMap<>();
        if (visibility == null || us.isEmpty()) {
            return out;
        }
        Set<Long> ok = visibility.visibleOwners(viewerId, us.stream().map(User::getId).toList(),
                edu.bingol.backend.profile.privacy.AvatarVisibility.Field.AVATAR);
        for (User u : us) {
            if (u.getAvatarUrl() != null && ok.contains(u.getId()) && !hide.contains(u.getId())) {
                out.put(u.getId(), u.getAvatarUrl());
            }
        }
        return out;
    }

    /** Uye satirina eklenen profil bilgisi: bolum + sinif (gizlilik ayarina gore bakana acik olanlar). */
    public record ProfileExtra(String department, Short classYear) {
        public static final ProfileExtra NONE = new ProfileExtra(null, null);
    }

    /**
     * Tek gizlilik sorgusuyla (N+1 yok) bakanin gorebildigi bolum/sinif. `hide` = engel iliskisi olanlar (hicbiri gorunmez).
     * KVKK: gizlilik ayari kapali olan alan hic doldurulmaz.
     */
    public Map<Long, ProfileExtra> profileExtras(Long viewerId, Collection<User> us, Set<Long> hide) {
        Map<Long, ProfileExtra> out = new HashMap<>();
        if (visibility == null || us.isEmpty()) {
            return out;
        }
        var fields = java.util.EnumSet.of(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.DEPARTMENT,
                edu.bingol.backend.profile.privacy.AvatarVisibility.Field.CLASS_YEAR);
        var vis = visibility.visibleOwners(viewerId, us.stream().map(User::getId).toList(), fields);
        for (User u : us) {
            if (hide.contains(u.getId())) {
                continue;
            }
            Long id = u.getId();
            out.put(id, new ProfileExtra(
                    vis.get(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.DEPARTMENT).contains(id) ? u.getDepartment() : null,
                    vis.get(edu.bingol.backend.profile.privacy.AvatarVisibility.Field.CLASS_YEAR).contains(id) ? u.getClassYear() : null));
        }
        return out;
    }

    private String category(String raw, String current) {
        return categoryService == null ? Texts.blankToNull(raw) : categoryService.resolveForWrite(raw, current);
    }

    public CommunityService(CommunityRepository communities, CommunityMemberRepository members, UserRepository users,
                            BlockService blocks, NotificationService notifications, MediaService media,
                            ClubPermissions permissions, ClubAuditService audit, ClubExtrasHooks hooks) {
        this.hooks = hooks;
        this.communities = communities;
        this.members = members;
        this.users = users;
        this.blocks = blocks;
        this.notifications = notifications;
        this.media = media;
        this.permissions = permissions;
        this.audit = audit;
    }

    // ---- olusturma / okuma ----

    @Transactional
    public Community create(Actor a, CreateCommunityRequest r) {
        if (r.name().trim().length() < 3) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Topluluk adı en az 3 karakter olmalı.");
        }
        ContentGuard.clean(guard, Entity.CLUB, "name", a.id(), r.name());
        ContentGuard.clean(guard, Entity.CLUB, "description", a.id(), r.description());
        ContentGuard.clean(guard, Entity.CLUB, "category", a.id(), r.category());
        // Sayim ile ekleme arasindaki yarisi kapatir: ayni kullanicinin istekleri bu satirda siralanir.
        communities.lockOwner(a.id());
        if (communities.countByOwnerIdAndStatusIn(a.id(), LIVE) >= MAX_OWNED) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_LIMIT",
                    "En fazla " + MAX_OWNED + " topluluğun sahibi olabilirsiniz.", String.valueOf(MAX_OWNED));
        }
        Community c = new Community();
        c.setName(r.name().trim());
        c.setSlug(uniqueSlug(c.getName()));
        c.setDescription(Texts.blankToNull(r.description()));
        c.setCategory(category(r.category(), null));
        if (r.joinPolicy() != null) {
            c.setJoinPolicy(r.joinPolicy());
        }
        if (r.visibility() != null) {
            c.setVisibility(r.visibility());
        }
        c.setOwnerId(a.id());
        // auto-approve (varsayilan acik): kulup hemen yayinda; kapaliysa eski yonetici onayi akisi.
        c.setStatus(autoApprove ? Community.Status.ACTIVE : Community.Status.PENDING_REVIEW);
        try {
            communities.saveAndFlush(c);
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "SLUG_CONFLICT", "Topluluk adı çakıştı, tekrar deneyin.");
        }
        members.save(new CommunityMember(c.getId(), a.id(), Role.OWNER, CommunityMember.Status.ACTIVE));
        if (autoApprove) {
            hooks.onCommunityActivated(c); // sohbet odasi kurulur, sahip odaya girer
        }
        return c;
    }

    /** Yeni kulup yonetici onayi beklemeden yayina girsin mi (app.community.auto-approve). */
    @Value("${app.community.auto-approve:true}")
    private boolean autoApprove;

    void setAutoApprove(boolean v) { // testler icin
        this.autoApprove = v;
    }

    /**
     * Sahip (veya ADMIN) kulubu siler (yumusak, DELETED): kesfet/aramadan duser, sohbet odasi kapanir (herkes
     * odadan cikar), bagli gelecek etkinlikler iptal edilir (ClubDeletedEvent dinleyicisi), uyeler bilgilendirilir.
     */
    @Transactional
    public void delete(Actor a, Long id) {
        delete(a, id, "notif.community.deleted", null);
    }

    /** Yonetici silmesi (P06): ayni islem, uyelere "sahibi tarafindan" demeyen metinle; denetim detayina yonetici notu. */
    @Transactional
    public void deleteByAdmin(Actor admin, Long id, String reason) {
        if (!admin.systemAdmin(PermissionMatrix.CONTENT_WRITE)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        delete(admin, id, "notif.community.adminDeleted", "admin" + (reason == null ? "" : " reason=" + reason));
    }

    private void delete(Actor a, Long id, String notifKey, String auditDetail) {
        Community c = loadVisible(a, id);
        boolean owner = c.getOwnerId().equals(a.id());
        if (!owner && !a.systemAdmin(PermissionMatrix.CONTENT_WRITE)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için topluluk sahibi olmalısınız.");
        }
        if (!owner) {
            SystemAdminAudit.used(adminAudit, a, "COMMUNITY", id, "kulup silme");
        }
        String cover = c.getCoverUrl();
        String logo = c.getLogoUrl();
        c.setStatus(Community.Status.DELETED);
        c.setCoverUrl(null);
        c.setLogoUrl(null);
        c.setUpdatedAt(Instant.now());
        communities.saveAndFlush(c);
        media.release(cover);
        media.release(logo);
        audit.record(id, a.id(), null, ClubAuditService.COMMUNITY_DELETED, auditDetail);
        // Uyelere haber (500 ile sinirli); silen kisi haric.
        for (Long uid : members.userIdsByStatus(id, CommunityMember.Status.ACTIVE, PageRequest.of(0, 500))) {
            if (!uid.equals(a.id())) {
                notifications.sendTemplated(uid, NotificationType.COMMUNITY, notifKey, data(id), c.getName());
            }
        }
        hooks.onCommunityDeleted(c);
    }

    /** Ad'dan benzersiz slug: cakisirsa -2, -3 ... eklenir; cok cakisirsa rastgele ek. */
    String uniqueSlug(String name) {
        String base = Texts.slugify(name);
        if (!communities.existsBySlug(base)) {
            return base;
        }
        for (int i = 2; i <= 20; i++) {
            String s = base + "-" + i;
            if (!communities.existsBySlug(s)) {
                return s;
            }
        }
        return base + "-" + UUID.randomUUID().toString().substring(0, 8);
    }

    /** Kesfet: yalnizca ACTIVE + PUBLIC. */
    @Transactional(readOnly = true)
    public CursorPage<CommunityView> discover(Actor a, String category, String q, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<Community> rows = communities.discover(Community.Status.ACTIVE, Community.Visibility.PUBLIC,
                category == null ? "" : category.trim(), Texts.likePattern(q), Paging.descStart(cursor),
                PageRequest.of(0, s + 1));
        return Paging.map(rows, s, Community::getId, items -> views(items, a));
    }

    /** Kategori filtresi icin: kesfette gorunen kulupler sayilir, ozel/bekleyen/gizli kulup sizmaz. */
    @Transactional(readOnly = true)
    public List<CategoryCount> categories() {
        return communities.categoryCounts(Community.Status.ACTIVE, Community.Visibility.PUBLIC).stream()
                .map(r -> new CategoryCount((String) r[0], (Long) r[1])).toList();
    }

    @Transactional(readOnly = true)
    public CommunityView get(Actor a, Long id) {
        return views(List.of(loadVisible(a, id)), a).get(0);
    }

    /** Benim topluluklarim: aktif uyeliklerim (bekleyen/reddedilen toplulugu olmayanlar). */
    @Transactional(readOnly = true)
    public CursorPage<CommunityView> mine(Actor a, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<CommunityMember> rows = members.mine(a.id(), CommunityMember.Status.ACTIVE, Paging.descStart(cursor),
                PageRequest.of(0, s + 1));
        return Paging.map(rows, s, CommunityMember::getId, items -> {
            Map<Long, Community> byId = new HashMap<>();
            communities.findAllById(items.stream().map(CommunityMember::getCommunityId).toList())
                    .forEach(c -> byId.put(c.getId(), c));
            List<Community> ordered = items.stream().map(m -> byId.get(m.getCommunityId()))
                    .filter(c -> c != null && (c.getStatus() == Community.Status.ACTIVE
                            || c.getStatus() == Community.Status.PENDING_REVIEW))
                    .toList();
            return views(ordered, a);
        });
    }

    @Transactional
    public CommunityView update(Actor a, Long id, UpdateCommunityRequest r) {
        return update(a, id, r, true);
    }

    /**
     * Yonetici duzenlemesi (P06): kufur suzgeci ATLANIR (yonetici ihlalli metni temizlemek icin duzenler; islem
     * denetim kaydina yazilir). Kategori kurali (aktif kategori) ve oda basligi senkronu aynen uygulanir.
     */
    @Transactional
    public CommunityView adminUpdate(Actor a, Long id, UpdateCommunityRequest r) {
        if (!a.systemAdmin(PermissionMatrix.CONTENT_WRITE)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Bu işlem için yetkiniz yok.");
        }
        return update(a, id, r, false);
    }

    private CommunityView update(Actor a, Long id, UpdateCommunityRequest r, boolean guarded) {
        Community c = load(id);
        permissions.require(a, id, ClubPermission.EDIT_INFO);
        if (guarded) {
            ContentGuard.changed(guard, Entity.CLUB, "name", a.id(), c.getName(), r.name());
            ContentGuard.changed(guard, Entity.CLUB, "description", a.id(), c.getDescription(), r.description());
            ContentGuard.changed(guard, Entity.CLUB, "category", a.id(), c.getCategory(), r.category());
        }
        boolean renamed = false;
        if (r.name() != null && !r.name().isBlank()) {
            if (r.name().trim().length() < 3) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Topluluk adı en az 3 karakter olmalı.");
            }
            renamed = !r.name().trim().equals(c.getName());
            c.setName(r.name().trim());
        }
        if (r.description() != null) {
            c.setDescription(Texts.blankToNull(r.description()));
        }
        if (r.category() != null) {
            c.setCategory(category(r.category(), c.getCategory()));
        }
        if (r.joinPolicy() != null) {
            c.setJoinPolicy(r.joinPolicy());
        }
        if (r.visibility() != null) {
            c.setVisibility(r.visibility());
        }
        c.setUpdatedAt(Instant.now());
        communities.save(c);
        if (renamed) {
            hooks.onRenamed(c);
        }
        return views(List.of(c), a).get(0);
    }

    /** Kapak: T1 hatti (dogrula, yeniden kodla/sikistir, EXIF temizle); eski dosya referans yoksa silinir. */
    @Transactional
    public CommunityView setCover(Actor a, Long id, MultipartFile file) {
        Community c = load(id);
        permissions.require(a, id, ClubPermission.EDIT_INFO);
        String url = media.storeImage(file, ImageKind.COVER).url();
        String old = c.getCoverUrl();
        c.setCoverUrl(url);
        c.setUpdatedAt(Instant.now());
        communities.saveAndFlush(c);
        if (old != null && !old.equals(url)) {
            media.release(old);
        }
        return views(List.of(c), a).get(0);
    }

    /** Logo: kare/kucuk gorsel icin AVATAR boyut-kalite sinirlari; baska bir hatta gerek yok (T1 hatti). */
    @Transactional
    public CommunityView setLogo(Actor a, Long id, MultipartFile file) {
        Community c = load(id);
        permissions.require(a, id, ClubPermission.EDIT_INFO);
        String url = media.storeImage(file, ImageKind.AVATAR).url();
        String old = c.getLogoUrl();
        c.setLogoUrl(url);
        c.setUpdatedAt(Instant.now());
        communities.saveAndFlush(c);
        if (old != null && !old.equals(url)) {
            media.release(old);
        }
        return views(List.of(c), a).get(0);
    }

    /** Logoyu kaldirir (idempotent). */
    @Transactional
    public CommunityView removeLogo(Actor a, Long id) {
        Community c = load(id);
        permissions.require(a, id, ClubPermission.EDIT_INFO);
        String old = c.getLogoUrl();
        if (old != null) {
            c.setLogoUrl(null);
            c.setUpdatedAt(Instant.now());
            communities.saveAndFlush(c);
            media.release(old);
        }
        return views(List.of(c), a).get(0);
    }

    // ---- uyelik ----

    /** @return ACTIVE (OPEN topluluk) veya PENDING (APPROVAL topluluk) */
    @Transactional
    public String join(Actor a, Long id) {
        Community c = load(id);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı.");
        }
        Optional<CommunityMember> existing = members.findByCommunityIdAndUserId(id, a.id());
        if (existing.isPresent()) {
            switch (existing.get().getStatus()) {
                case ACTIVE -> throw new ApiException(HttpStatus.CONFLICT, "ALREADY_MEMBER", "Zaten üyesiniz.");
                case PENDING -> throw new ApiException(HttpStatus.CONFLICT, "REQUEST_PENDING",
                        "Katılma isteğiniz zaten bekliyor.");
                case BANNED -> throw new ApiException(HttpStatus.FORBIDDEN, "BANNED",
                        "Bu topluluktan uzaklaştırıldınız.");
            }
        }
        // Kimlikler tahmin edilebilir: ozel kulube dogrudan katilim olamaz, her zaman onay gerekir.
        boolean open = isOpenJoin(c);
        CommunityMember.Status st = open ? CommunityMember.Status.ACTIVE : CommunityMember.Status.PENDING;
        try {
            members.saveAndFlush(new CommunityMember(id, a.id(), Role.MEMBER, st));
        } catch (DataIntegrityViolationException e) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_MEMBER", "Zaten üyesiniz veya isteğiniz bekliyor.");
        }
        if (!open) {
            String who = displayName(a.id());
            for (Long mod : permissions.holders(id, ClubPermission.MANAGE_MEMBERS)) {
                notifications.sendTemplated(mod, NotificationType.COMMUNITY, "notif.community.joinRequest", data(id), who, c.getName());
            }
        } else {
            hooks.onMemberActivated(id, a.id());
        }
        return st.name();
    }

    /** Dogrudan katilima acik mi: ozel (PRIVATE) kulup her zaman onay ister (kimlikler tahmin edilebilir). */
    public static boolean isOpenJoin(Community c) {
        return c.getJoinPolicy() == JoinPolicy.OPEN && c.getVisibility() != Community.Visibility.PRIVATE;
    }

    /** Sahip ayrilamaz; yasakli kullanici ayrilarak yasagi kaldiramaz; bekleyen istek iptal edilir. */
    @Transactional
    public void leave(Actor a, Long id) {
        CommunityMember m = members.findByCommunityIdAndUserId(id, a.id())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_MEMBER", "Bu topluluğun üyesi değilsiniz."));
        if (m.getRole() == Role.OWNER) {
            throw new ApiException(HttpStatus.CONFLICT, "OWNER_CANNOT_LEAVE", "Topluluk sahibi ayrılamaz.");
        }
        if (m.getStatus() == CommunityMember.Status.BANNED) {
            throw new ApiException(HttpStatus.FORBIDDEN, "BANNED", "Bu topluluktan uzaklaştırıldınız.");
        }
        members.delete(m);
        permissions.clearGrants(id, a.id());
        hooks.onMemberGone(id, a.id());
    }

    /** Uye listesi: PRIVATE toplulukta yalnizca uyeler gorur; engel iliskisi olanlar listelenmez. */
    @Transactional(readOnly = true)
    public CursorPage<MemberView> members(Actor a, Long id, Long cursor, int size) {
        Community c = loadVisible(a, id);
        requireReadable(a, c);
        return memberPage(a.id(), id, CommunityMember.Status.ACTIVE, blockedFor(a), blockedFor(a), cursor, size);
    }

    @Transactional(readOnly = true)
    public CursorPage<MemberView> requests(Actor a, Long id, Long cursor, int size) {
        load(id);
        permissions.require(a, id, ClubPermission.MANAGE_MEMBERS);
        return memberPage(a.id(), id, CommunityMember.Status.PENDING, Set.of(-1L), blockedFor(a), cursor, size);
    }

    @Transactional
    public void decide(Actor a, Long id, Long userId, boolean approve) {
        Community c = load(id);
        permissions.require(a, id, ClubPermission.MANAGE_MEMBERS);
        CommunityMember m = members.findByCommunityIdAndUserId(id, userId)
                .filter(x -> x.getStatus() == CommunityMember.Status.PENDING)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "REQUEST_NOT_FOUND", "Bekleyen istek bulunamadı."));
        if (approve) {
            m.setStatus(CommunityMember.Status.ACTIVE);
            m.setJoinedAt(Instant.now());
            members.save(m);
            hooks.onMemberActivated(id, userId);
        } else {
            members.delete(m);
            hooks.onMemberGone(id, userId);
        }
        audit.record(id, a.id(), userId, approve ? ClubAuditService.MEMBER_APPROVED : ClubAuditService.MEMBER_REJECTED, null);
        notifications.sendTemplated(userId, NotificationType.COMMUNITY,
                approve ? "notif.community.joinApproved" : "notif.community.joinRejected", data(id), c.getName());
    }

    /**
     * MANAGE_MEMBERS: uyeyi cikarir; ban=true ise BANNED olarak tutar (yeniden katilamaz). Hedef, islemi yapandan
     * kesin dusuk sirada olmali (moderator moderatoru, yonetici yoneticiyi cikaramaz; sahip hic cikarilamaz).
     */
    @Transactional
    public void remove(Actor a, Long id, Long userId, boolean ban) {
        load(id);
        ClubPermissions.Standing me = permissions.require(a, id, ClubPermission.MANAGE_MEMBERS);
        if (userId.equals(a.id())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "USE_LEAVE", "Kendinizi çıkaramazsınız; ayrılmayı kullanın.");
        }
        CommunityMember m = members.findByCommunityIdAndUserId(id, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "NOT_MEMBER", "Kullanıcı bu topluluğun üyesi değil."));
        if (m.getRole() == Role.OWNER) {
            throw new ApiException(HttpStatus.FORBIDDEN, "OWNER_PROTECTED", "Topluluk sahibi çıkarılamaz.");
        }
        if (permissions.standingOfMember(m).rank() >= me.rank()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ESCALATION_DENIED",
                    "Eşit veya üst düzey bir üyeye müdahale edemezsiniz.");
        }
        if (ban) {
            m.setStatus(CommunityMember.Status.BANNED);
            m.setRole(Role.MEMBER);
            members.save(m);
        } else {
            members.delete(m);
        }
        permissions.clearGrants(id, userId);
        hooks.onMemberGone(id, userId);
        audit.record(id, a.id(), userId, ban ? ClubAuditService.MEMBER_BANNED : ClubAuditService.MEMBER_REMOVED, null);
    }

    // ---- yonetici (ADMIN) ----

    @Transactional(readOnly = true)
    public CursorPage<CommunityView> byStatus(Community.Status status, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<Community> rows = communities.byStatus(status, Paging.descStart(cursor), PageRequest.of(0, s + 1));
        return Paging.map(rows, s, Community::getId, items -> views(items, (Actor) null));
    }

    @Transactional
    public void review(Long id, boolean approve, String reason) {
        Community c = load(id);
        if (c.getStatus() != Community.Status.PENDING_REVIEW) {
            throw new ApiException(HttpStatus.CONFLICT, "NOT_PENDING", "Topluluk onay beklemiyor.");
        }
        c.setStatus(approve ? Community.Status.ACTIVE : Community.Status.REJECTED);
        c.setReviewNote(approve ? null : Texts.blankToNull(reason));
        c.setUpdatedAt(Instant.now());
        communities.save(c);
        if (approve) {
            hooks.onCommunityActivated(c); // sohbet odasi kulup yayina girince kurulur
        }
        String note = c.getReviewNote();
        notifications.sendTemplated(c.getOwnerId(), NotificationType.COMMUNITY,
                approve ? "notif.community.approved" : note == null ? "notif.community.rejected" : "notif.community.rejectedNote",
                data(id), approve || note == null ? new String[] {c.getName()} : new String[] {c.getName(), note});
    }

    // ---- diger modullerin kullandigi yardimcilar ----

    /** Silinmis (DELETED) kulup yokmus gibi 404 verir. */
    public Community load(Long id) {
        return communities.findById(id).filter(c -> c.getStatus() != Community.Status.DELETED)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı."));
    }

    /** ACTIVE ise herkes; degilse yalnizca sahip ve ADMIN gorur (digerlerine 404). */
    public Community loadVisible(Actor a, Long id) {
        Community c = load(id);
        if (c.getStatus() != Community.Status.ACTIVE && !a.systemAdmin(PermissionMatrix.CONTENT_READ)
                && !c.getOwnerId().equals(a.id())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı.");
        }
        return c;
    }

    /** Aktif uyenin rolu; uye degilse (veya bekleyen/yasakli) bos. */
    public Optional<Role> roleOf(Long communityId, Long userId) {
        return members.findByCommunityIdAndUserId(communityId, userId).filter(CommunityMember::isActive)
                .map(CommunityMember::getRole);
    }

    /** ADMIN her toplulukta OWNER sayilir. */
    public Role effectiveRole(Actor a, Community c) {
        return a.systemAdmin(PermissionMatrix.CONTENT_WRITE) ? Role.OWNER : roleOf(c.getId(), a.id()).orElse(null);
    }

    /** Kulup yetkisi sorgusu (gonderi/etkinlik gibi diger servisler icin); sistem ADMIN'i her yetkiye sahip. */
    public boolean can(Actor a, Long communityId, ClubPermission p) {
        return permissions.has(a, communityId, p);
    }

    /** Yetki yoksa 403. */
    public void require(Actor a, Long communityId, ClubPermission p) {
        permissions.require(a, communityId, p);
    }

    /** Topluluk icerigini (uye listesi, akis) okuyabilir mi: PUBLIC ise herkes, PRIVATE ise yalnizca uye/ADMIN. */
    public void requireReadable(Actor a, Community c) {
        if (c.getVisibility() == Community.Visibility.PRIVATE && effectiveRole(a, c) == null) {
            throw new ApiException(HttpStatus.FORBIDDEN, "NOT_MEMBER", "Bu özel topluluğun içeriğini yalnızca üyeler görebilir.");
        }
    }

    /** Engel iliskisi olan kullanicilar (NOT IN bos kalmasin diye -1 eklenir). */
    public Set<Long> blockedFor(Actor a) {
        Set<Long> s = new HashSet<>(blocks.hiddenFrom(a.id()));
        s.add(-1L);
        return s;
    }

    /** Topluluk id -> kayit (etkinlik listelerinde ad + logo icin tek sorgu). */
    public Map<Long, Community> byIds(Collection<Long> ids) {
        Map<Long, Community> m = new HashMap<>();
        if (!ids.isEmpty()) {
            communities.findAllById(ids).forEach(c -> m.put(c.getId(), c));
        }
        return m;
    }

    /** Topluluk id -> ad (etkinlik listelerinde gostermek icin). */
    public Map<Long, String> namesById(Collection<Long> ids) {
        Map<Long, String> m = new HashMap<>();
        if (!ids.isEmpty()) {
            communities.findAllById(ids).forEach(c -> m.put(c.getId(), c.getName()));
        }
        return m;
    }

    public Map<Long, User> usersById(Collection<Long> ids) {
        Map<Long, User> m = new HashMap<>();
        users.findAllById(ids).forEach(u -> m.put(u.getId(), u));
        return m;
    }

    // ---- ic yardimcilar ----

    /** `hideAvatar`: goruntuleyenle engel iliskisi olanlarin avatari gosterilmez (golge engel). */
    private CursorPage<MemberView> memberPage(Long viewerId, Long cid, CommunityMember.Status status, Set<Long> excluded,
                                              Set<Long> hideAvatar, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<CommunityMember> rows = members.page(cid, status, Paging.ascStart(cursor), excluded, PageRequest.of(0, s + 1));
        return Paging.map(rows, s, CommunityMember::getId, items -> {
            Map<Long, User> u = usersById(items.stream().map(CommunityMember::getUserId).toList());
            Map<Long, ProfileExtra> extras = profileExtras(viewerId, u.values(), hideAvatar);
            Map<Long, String> avatars = avatarsFor(viewerId, u.values(), hideAvatar);
            return items.stream().map(m -> {
                User x = u.get(m.getUserId());
                ProfileExtra pe = extras.getOrDefault(m.getUserId(), ProfileExtra.NONE);
                return new MemberView(m.getUserId(), x == null ? "Kullanıcı" : x.getDisplayName(),
                        avatars.get(m.getUserId()), m.getRole(), m.getJoinedAt(),
                        pe.department(), pe.classYear());
            }).toList();
        });
    }

    /** Toplu gorunum: uye sayilari ve benim uyeligim tek sorguyla. viewerId null ise uyelik "NONE". */
    private List<CommunityView> views(List<Community> list, Actor viewer) {
        Long viewerId = viewer == null ? null : viewer.id();
        boolean viewerAdmin = viewer != null && viewer.systemAdmin(PermissionMatrix.CONTENT_READ);
        if (list.isEmpty()) {
            return List.of();
        }
        List<Long> ids = list.stream().map(Community::getId).toList();
        Map<Long, Long> counts = new HashMap<>();
        for (Object[] row : members.countByCommunity(ids, CommunityMember.Status.ACTIVE)) {
            counts.put((Long) row[0], (Long) row[1]);
        }
        Map<Long, CommunityMember> mine = new HashMap<>();
        if (viewerId != null) {
            members.findByUserIdAndCommunityIdIn(viewerId, ids).forEach(m -> mine.put(m.getCommunityId(), m));
        }
        List<CommunityView> out = new ArrayList<>();
        for (Community c : list) {
            CommunityMember m = mine.get(c.getId());
            // Ozel kulubun aciklamasi uye olmayana (sahip/yonetici haric) gosterilmez.
            boolean hideDesc = viewerId != null && c.getVisibility() == Community.Visibility.PRIVATE
                    && (m == null || !m.isActive()) && !viewerId.equals(c.getOwnerId()) && !viewerAdmin;
            out.add(new CommunityView(c.getId(), c.getName(), c.getSlug(), hideDesc ? null : c.getDescription(), c.getCategory(),
                    c.getCoverUrl(), c.getJoinPolicy(), c.getVisibility(), c.getStatus(), c.getOwnerId(),
                    counts.getOrDefault(c.getId(), 0L), m == null ? "NONE" : m.getStatus().name(),
                    m != null && m.isActive() ? m.getRole() : null, c.getCreatedAt(), c.getLogoUrl(),
                    c.getStatus() == Community.Status.PENDING_REVIEW ? c.getCreatedAt() : null));
        }
        return out;
    }

    private String displayName(Long userId) {
        return users.findById(userId).map(User::getDisplayName).orElse("Bir kullanıcı");
    }

    static Map<String, String> data(Long communityId) {
        return Map.of("communityId", communityId.toString());
    }
}
