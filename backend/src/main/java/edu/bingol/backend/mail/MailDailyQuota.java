package edu.bingol.backend.mail;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.config.MailProperties;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Saglayici (or. Brevo ucretsiz ~300/gun) gunluk gonderim kotasi sayaci. Redis `mail:daily:&lt;gun&gt;` (INCR, TTL 2 gun);
 * Redis yoksa/hata verirse bellek ici yedek (tek ornek). Sayac yalniz BASARILI gercek gonderimde artar.
 * Islemsel postalar limite KADAR, duyuru/CUSTOM postalar yalniz `limit - reserve` altinda gonderilir.
 * limit &lt;= 0 = sinirsiz (koruma kapali). Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class MailDailyQuota {

    private static final Logger log = LoggerFactory.getLogger(MailDailyQuota.class);
    private static final Duration KEY_TTL = Duration.ofDays(2);
    /** Gun sifirlandiktan sonra bu kadar bekle (saat tam basinda saglayici sayaci henuz sifirlanmamis olabilir). */
    static final Duration RESET_MARGIN = Duration.ofMinutes(5);

    private final MailProperties props;
    private final StringRedisTemplate redis;
    private final ConcurrentHashMap<String, AtomicLong> local = new ConcurrentHashMap<>();

    @Autowired
    public MailDailyQuota(MailProperties props, StringRedisTemplate redis) {
        this.props = props;
        this.redis = redis;
    }

    /** Redissiz (testler/yedek) kurucu. */
    public MailDailyQuota(MailProperties props) {
        this(props, null);
    }

    public boolean enabled() {
        return props.dailyLimit() > 0;
    }

    public int limit() {
        return props.dailyLimit();
    }

    /** Duyuru icin ust sinir: limit - reserve (en az 0). */
    int announcementCap() {
        return Math.max(0, props.dailyLimit() - Math.max(0, props.dailyReserve()));
    }

    /** Bu tur bir posta daha gonderilebilir mi (duyuru: rezerv dusulmus sinir; islemsel: tam limit). */
    public boolean allow(boolean announcement) {
        if (!enabled()) {
            return true;
        }
        long used = used();
        return used < (announcement ? announcementCap() : props.dailyLimit());
    }

    /** Islemsel kod postasi icin kota tamamen doldu mu (kayit/sifre ucunda genel hata icin). */
    public boolean exhausted() {
        return enabled() && used() >= props.dailyLimit();
    }

    /** Bugunku basarili gonderim sayisi. */
    public long used() {
        String key = key(Instant.now());
        try {
            if (redis != null) {
                String v = redis.opsForValue().get(key);
                return v == null ? 0 : Long.parseLong(v);
            }
        } catch (Exception e) {
            log.debug("Mail kota sayaci Redis'ten okunamadi, bellek ici yedek: {}", e.toString());
        }
        AtomicLong n = local.get(key);
        return n == null ? 0 : n.get();
    }

    /** Basarili gonderimden sonra sayaci artirir. */
    public void recordSent() {
        if (!enabled()) {
            return;
        }
        String key = key(Instant.now());
        try {
            if (redis != null) {
                Long n = redis.opsForValue().increment(key);
                if (n != null && n == 1) {
                    redis.expire(key, KEY_TTL);
                }
                return;
            }
        } catch (Exception e) {
            log.debug("Mail kota sayaci Redis'e yazilamadi, bellek ici yedek: {}", e.toString());
        }
        local.computeIfAbsent(key, k -> new AtomicLong()).incrementAndGet();
        local.keySet().removeIf(k -> !k.equals(key) && local.size() > 3);
    }

    // ------------------------------------------------------------------ kimliksiz kod postasi korumasi (A2)

    /** Kimliksiz kod postasi turu: kayit/kod yenile, sifre sifirlama, herkese acik destek dogrulama. */
    public enum CodeKind { REGISTRATION, PASSWORD_RESET, SUPPORT }

    /** Kayit/destek kodlari icin gunluk kotanin ust payi (kalani gercek kullanici/guvenlik postalarina ayrilir). */
    @Value("${app.mail.public-code-share:0.6}")
    private double publicCodeShare = 0.6;
    /** Sifre sifirlama kodlari icin pay (kayit payindan buyuk: mevcut hesaplar icin ayrilmis ek rezerv). */
    @Value("${app.mail.reset-code-share:0.85}")
    private double resetCodeShare = 0.85;
    @Value("${app.mail.max-codes-per-email-per-day:10}")
    private int maxCodesPerEmailPerDay = 10;
    @Value("${app.mail.max-code-requests-per-ip-per-day:100}")
    private int maxCodeRequestsPerIpPerDay = 100;

    private ClientIp clientIp;

    @Autowired(required = false)
    void setClientIp(ClientIp clientIp) {
        this.clientIp = clientIp;
    }

    void configure(double publicShare, double resetShare, int perEmail, int perIp) {
        this.publicCodeShare = publicShare;
        this.resetCodeShare = resetShare;
        this.maxCodesPerEmailPerDay = perEmail;
        this.maxCodeRequestsPerIpPerDay = perIp;
    }

    /** Tur icin kimliksiz kod postasi ust siniri (limit kapaliysa sinirsiz). */
    int publicCap(CodeKind kind) {
        if (!enabled()) {
            return Integer.MAX_VALUE;
        }
        double share = kind == CodeKind.PASSWORD_RESET ? resetCodeShare : publicCodeShare;
        share = Math.max(0, Math.min(1, share));
        return (int) Math.floor(props.dailyLimit() * share + 1e-9);
    }

    /** Bugun kimliksiz akislarda (kayit + sifirlama + destek) kuyruga alinan kod postasi sayisi. */
    public long publicUsed() {
        return read(counterKey("pub", "all"));
    }

    /** Bu tur icin kimliksiz kod butcesi doldu mu (global {@link #exhausted()}'tan ayri; sifirlama daha uzun surer). */
    public boolean publicExhausted(CodeKind kind) {
        return enabled() && publicUsed() >= publicCap(kind);
    }

    /** Kuyruga alinan her kimliksiz kod postasindan sonra cagrilir. */
    public void recordPublicCode() {
        incr(counterKey("pub", "all"));
    }

    /**
     * Alici basina gunluk kod postasi sayacini artirir; sinir asildiysa false (cagiran POSTAYI GONDERMEZ, genel
     * cevap verir: hesap varligi sizmaz). Anahtar alicinin ozetidir (ham adres Redis'te tutulmaz).
     */
    public boolean allowRecipientCode(String to) {
        if (maxCodesPerEmailPerDay <= 0 || to == null) {
            return true;
        }
        long n = incr(counterKey("rcpt", Hashing.sha256(to.trim().toLowerCase(java.util.Locale.ROOT)).substring(0, 24)));
        return n <= maxCodesPerEmailPerDay;
    }

    /** IP basina gunluk kod istegi sayaci (IPv6 /64'e indirgenir); asilirsa 429. */
    public void checkRequestIp(String ip) {
        if (maxCodeRequestsPerIpPerDay <= 0 || ip == null || ip.isBlank()) {
            return;
        }
        long n = incr(counterKey("ip", Hashing.sha256(ipBucket(ip)).substring(0, 24)));
        if (n > maxCodeRequestsPerIpPerDay) {
            long secs = Math.max(60, Duration.between(Instant.now(), nextReset(Instant.now())).toSeconds());
            throw new RateLimitedException(secs);
        }
    }

    /** Gecerli istegin IP'si (yoksa null). */
    String currentRequestIp() {
        try {
            if (clientIp == null || !(org.springframework.web.context.request.RequestContextHolder
                    .getRequestAttributes() instanceof org.springframework.web.context.request.ServletRequestAttributes a)) {
                return null;
            }
            return clientIp.of(a.getRequest());
        } catch (RuntimeException e) {
            return null;
        }
    }

    /** Gecerli istegin yolundan kod turu (sifre sifirlama uclari = PASSWORD_RESET; yoksa/baska = REGISTRATION). */
    CodeKind currentRequestKind() {
        try {
            if (org.springframework.web.context.request.RequestContextHolder.getRequestAttributes()
                    instanceof org.springframework.web.context.request.ServletRequestAttributes a) {
                String uri = a.getRequest().getRequestURI();
                if (uri != null && (uri.contains("forgot-password") || uri.contains("reset-password"))) {
                    return CodeKind.PASSWORD_RESET;
                }
                if (uri != null && uri.contains("/public/support")) {
                    return CodeKind.SUPPORT;
                }
            }
        } catch (RuntimeException e) {
            // baglam yok: varsayilan
        }
        return CodeKind.REGISTRATION;
    }

    /** IPv6 adreslerini /64 onekine indirger (adres dondurerek sinir atlatmayi onler); IPv4 aynen. */
    static String ipBucket(String ip) {
        if (ip.indexOf(':') < 0) {
            return ip;
        }
        try {
            byte[] b = java.net.InetAddress.getByName(ip).getAddress();
            if (b.length == 16) {
                // IPv4-eslenik (::ffff:a.b.c.d) InetAddress tarafindan zaten Inet4Address olur
                return java.util.HexFormat.of().formatHex(b, 0, 8) + "/64";
            }
            return ip;
        } catch (Exception e) {
            return ip;
        }
    }

    private String counterKey(String name, String id) {
        String stamp = key(Instant.now()).substring("mail:daily:".length());
        return "mail:" + name + ":" + id + ":" + stamp;
    }

    private long read(String key) {
        try {
            if (redis != null) {
                String v = redis.opsForValue().get(key);
                return v == null ? 0 : Long.parseLong(v);
            }
        } catch (Exception e) {
            log.debug("Mail sayaci okunamadi, bellek ici yedek: {}", e.toString());
        }
        AtomicLong n = local.get(key);
        return n == null ? 0 : n.get();
    }

    private long incr(String key) {
        try {
            if (redis != null) {
                Long n = redis.opsForValue().increment(key);
                if (n != null) {
                    if (n == 1) {
                        redis.expire(key, KEY_TTL);
                    }
                    return n;
                }
            }
        } catch (Exception e) {
            log.debug("Mail sayaci yazilamadi, bellek ici yedek: {}", e.toString());
        }
        // Bellek ici yedek: gun degisince eski anahtarlar silinir (sinirli buyume)
        if (local.size() > 5000) {
            local.clear();
        }
        return local.computeIfAbsent(key, k -> new AtomicLong()).incrementAndGet();
    }

    /** Kullanim yuzdesi (0-100+); limit yoksa -1. */
    public double percent() {
        return enabled() ? used() * 100.0 / props.dailyLimit() : -1;
    }

    /** Bir sonraki kota gunu baslangici + marj (ertelenen kayitlarin yeni zamani). */
    public Instant nextReset(Instant now) {
        Instant start = dayStart(now);
        return start.plus(Duration.ofDays(1)).plus(RESET_MARGIN);
    }

    /** Kota gununun baslangici: UTC `dailyResetHourUtc` saatinde baslayan gun. */
    Instant dayStart(Instant now) {
        int h = Math.min(23, Math.max(0, props.dailyResetHourUtc()));
        LocalDate d = now.minus(Duration.ofHours(h)).atZone(ZoneOffset.UTC).toLocalDate();
        return d.atStartOfDay(ZoneOffset.UTC).toInstant().plus(Duration.ofHours(h));
    }

    String key(Instant now) {
        int h = Math.min(23, Math.max(0, props.dailyResetHourUtc()));
        return "mail:daily:" + now.minus(Duration.ofHours(h)).atZone(ZoneOffset.UTC).toLocalDate();
    }
}
