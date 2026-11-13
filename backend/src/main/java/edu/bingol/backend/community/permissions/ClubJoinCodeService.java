package edu.bingol.backend.community.permissions;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.permissions.ClubDtos.JoinByCodeResult;
import edu.bingol.backend.config.JwtProperties;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kulupe QR ile dogrudan katilma. Kod durumsuz ve kisa omurludur (CheckinCodeService deseni, tablo yok):
 * {@code bingol-clubjoin:{communityId}.{pencere}.{HMAC}}. Pencere 60 sn; guncel + onceki 2 pencere kabul edilir
 * (180 sn'ye kadar). Anahtar jwt.secret'tan AYRI bir baglam etiketiyle turetilir (yoklama koduyla karismaz).
 * Kodu yalniz uye yonetme yetkisi olan gosterir; okutan kullanici onay beklemeden uye olur (kod = davet).
 */
@Service
public class ClubJoinCodeService {

    public static final String PREFIX = "bingol-clubjoin:";
    static final long STEP_SECONDS = 60;
    /** Guncel pencereden geriye kac pencere daha kabul edilir. */
    static final int ACCEPT_PREVIOUS = 2;
    private static final Pattern BODY = Pattern.compile("^([0-9]{1,18})\\.([0-9]{1,15})\\.([A-Za-z0-9_\\-]{1,64})$");

    public record JoinCodeView(String code, Instant expiresAt, int validForSeconds) {}

    public record JoinCodeRequest(@NotBlank @Size(max = 300) String code) {}

    private final byte[] key;
    private final CommunityRepository communities;
    private final CommunityMemberRepository members;
    private final ClubPermissions permissions;
    private final ClubInviteService invites;

    public ClubJoinCodeService(JwtProperties jwt, CommunityRepository communities, CommunityMemberRepository members,
                               ClubPermissions permissions, ClubInviteService invites) {
        this.key = hmac(jwt.secret().getBytes(StandardCharsets.UTF_8), "bingol-clubjoin-v1");
        this.communities = communities;
        this.members = members;
        this.permissions = permissions;
        this.invites = invites;
    }

    // ---- kod uretimi / dogrulama (saf; test icin Instant alir) ----

    public String generate(long communityId, Instant now) {
        long w = window(now);
        return PREFIX + communityId + "." + w + "." + mac(communityId, w);
    }

    /** Kodun gecerli son an'i = sunucunun kodu kabul ettigi son an (uretildigi pencereden 2 pencere sonrasinin sonu). */
    public Instant expiresAt(Instant now) {
        return Instant.ofEpochSecond((window(now) + ACCEPT_PREVIOUS + 1) * STEP_SECONDS);
    }

    /** Kod gecerliyse topluluk kimligini, degilse -1 doner. */
    public long verify(String code, Instant now) {
        if (code == null || code.length() > 300) {
            return -1;
        }
        String s = code.trim();
        if (s.startsWith(PREFIX)) {
            s = s.substring(PREFIX.length());
        }
        Matcher m = BODY.matcher(s);
        if (!m.matches()) {
            return -1;
        }
        long id;
        long w;
        try {
            id = Long.parseLong(m.group(1));
            w = Long.parseLong(m.group(2));
        } catch (NumberFormatException e) {
            return -1;
        }
        long current = window(now);
        boolean inWindow = w <= current && w >= current - ACCEPT_PREVIOUS;
        boolean sigOk = MessageDigest.isEqual(mac(id, w).getBytes(StandardCharsets.UTF_8),
                m.group(3).getBytes(StandardCharsets.UTF_8));
        return inWindow && sigOk ? id : -1;
    }

    // ---- servis ----

    /** Yonetici ekraninda gosterilecek guncel kod: MANAGE_MEMBERS ister; kulup ACTIVE olmali. */
    @Transactional(readOnly = true)
    public JoinCodeView issue(Actor a, Long communityId) {
        Community c = communities.findById(communityId).orElseThrow(ClubJoinCodeService::notFound);
        if (permissions.standing(a, communityId).isEmpty() && c.getVisibility() == Community.Visibility.PRIVATE) {
            throw notFound(); // ozel kulubun varligi yetkisize sizmaz
        }
        permissions.require(a, communityId, ClubPermission.MANAGE_MEMBERS);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw new ApiException(HttpStatus.CONFLICT, "COMMUNITY_NOT_ACTIVE", "Topluluk henüz yayında değil.");
        }
        return view(communityId, Instant.now());
    }

    JoinCodeView view(long communityId, Instant now) {
        Instant exp = expiresAt(now);
        return new JoinCodeView(generate(communityId, now), exp, (int) (exp.getEpochSecond() - now.getEpochSecond()));
    }

    /**
     * Kodu okutan kullaniciyi dogrudan aktif uye yapar. Zaten uyeyse idempotent ALREADY; yasakli 403 BANNED;
     * gecersiz/suresi dolmus kod ya da ACTIVE olmayan kulup ayni genel 422 (kulup varligi sizmaz).
     * Uyelik acma ClubInviteService.activate ile paylasilir (yeni-uye yan etkileri, yetki temizligi, denetim).
     */
    @Transactional
    public JoinByCodeResult join(Actor a, Long communityId, String code) {
        return join(a, communityId, code, Instant.now());
    }

    JoinByCodeResult join(Actor a, Long communityId, String code, Instant now) {
        long id = verify(code, now);
        if (id < 0 || id != communityId) {
            throw invalid();
        }
        Community c = communities.findById(communityId).orElseThrow(ClubJoinCodeService::invalid);
        if (c.getStatus() != Community.Status.ACTIVE) {
            throw invalid();
        }
        CommunityMember existing = members.findByCommunityIdAndUserId(communityId, a.id()).orElse(null);
        if (existing != null) {
            switch (existing.getStatus()) {
                case ACTIVE -> {
                    return new JoinByCodeResult(communityId, "ALREADY");
                }
                case BANNED -> throw new ApiException(HttpStatus.FORBIDDEN, "BANNED", "Bu topluluktan uzaklaştırıldınız.");
                case PENDING -> { }
            }
        }
        invites.activate(c, a, existing, "source=qr");
        return new JoinByCodeResult(communityId, CommunityMember.Status.ACTIVE.name());
    }

    // ---- ic ----

    private static long window(Instant t) {
        return t.getEpochSecond() / STEP_SECONDS;
    }

    private String mac(long communityId, long window) {
        byte[] full = hmac(key, "join:" + communityId + "." + window);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(Arrays.copyOf(full, 16));
    }

    private static byte[] hmac(byte[] key, String data) {
        try {
            Mac m = Mac.getInstance("HmacSHA256");
            m.init(new SecretKeySpec(key, "HmacSHA256"));
            return m.doFinal(data.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CLUB_JOIN_CODE_INVALID",
                "QR kodu geçersiz veya süresi dolmuş.");
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Topluluk bulunamadı.");
    }
}
