package edu.bingol.backend.mail;

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
