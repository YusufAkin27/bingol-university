package edu.bingol.backend.accessban;

import edu.bingol.backend.accessban.IpRanges.Range;
import edu.bingol.backend.accessban.IpRanges.RangeSet;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Engel listesinin bellek ici goruntusu: her istekte veritabanina gidilmez. IP/CIDR icin sirali aralik yapisi
 * (O(log n)), cihaz ve kullanici icin hash haritasi. Goruntu `app.security.ban-cache-ttl-seconds` (varsayilan 20 sn)
 * sonra, bir engelin suresi dolunca ya da yerel degisiklikte ({@link #invalidate}) yenilenir. Cok ornekli
 * calismada diger ornekler en gec TTL kadar sonra gunceli gorur. Yukleme hatasinda eski goruntu korunur (acik kalir).
 */
@Component
public class AccessBanCache {

    private static final Logger log = LoggerFactory.getLogger(AccessBanCache.class);

    /** Eslesme sonucu: kind = IP | CIDR | DEVICE | USER | ANONYMIZER; banId anonimlestiricide aralik kimligidir. */
    public record Hit(String kind, Long banId) {}

    private record Snapshot(RangeSet ips, Map<Long, String> ipKinds, Map<String, Long> devices, Map<Long, Long> users,
                            RangeSet anonymizers, long loadedAt, long nextExpiry) {}

    private final AccessBanRepository bans;
    private final AnonymizerRangeRepository anonymizers;
    private final Clock clock;
    private final long ttlMillis;
    private final boolean blockAnonymizers;
    private final RangeSet exempt;
    private volatile Snapshot snap;

    public AccessBanCache(AccessBanRepository bans, AnonymizerRangeRepository anonymizers, Clock clock,
                          @Value("${app.security.ban-cache-ttl-seconds:20}") long ttlSeconds,
                          @Value("${app.security.block-anonymizers:false}") boolean blockAnonymizers,
                          @Value("${app.security.ban-allowlist:}") String allowlist) {
        this.bans = bans;
        this.anonymizers = anonymizers;
        this.clock = clock;
        this.ttlMillis = Math.max(1, ttlSeconds) * 1000L;
        this.blockAnonymizers = blockAnonymizers;
        List<String> all = new ArrayList<>(IpRanges.PRIVATE);
        for (String s : allowlist.split(",")) {
            if (!s.isBlank()) {
                all.add(s.trim()); // gecersiz allowlist acilista hata verir (yanlis yapilandirma sessiz kalmasin)
            }
        }
        this.exempt = IpRanges.setOf(all);
    }

    public boolean blockAnonymizers() {
        return blockAnonymizers;
    }

    /** Loopback, ozel ag ve yonetici izin listesi: asla engellenmez. */
    public boolean isExempt(String ip) {
        long[] k = IpRanges.keyOf(ip);
        return k != null && exempt.find(k[0], k[1]) >= 0;
    }

    /** Aralik muaf aglarin tamamen icinde mi (engellemek anlamsiz). */
    public boolean entirelyExempt(Range r) {
        return exempt.find(r.sHi(), r.sLo()) >= 0 && exempt.find(r.eHi(), r.eLo()) >= 0;
    }

    /** Istemciyi engelleyen ilk eslesme (yoksa null). Sira: IP/CIDR, cihaz, kullanici, anonimlestirici. */
    public Hit match(ClientContext ctx, Long userId) {
        Snapshot s = current();
        long[] k = ctx == null ? null : IpRanges.keyOf(ctx.ip());
        boolean exemptIp = k != null && exempt.find(k[0], k[1]) >= 0;
        if (k != null && !exemptIp) {
            long id = s.ips.find(k[0], k[1]);
            if (id >= 0) {
                return new Hit(s.ipKinds.getOrDefault(id, AccessBan.IP), id);
            }
        }
        if (ctx != null && ctx.deviceHash() != null) {
            Long id = s.devices.get(ctx.deviceHash());
            if (id != null) {
                return new Hit(AccessBan.DEVICE, id);
            }
        }
        if (userId != null) {
            Long id = s.users.get(userId);
            if (id != null) {
                return new Hit(AccessBan.USER, id);
            }
        }
        if (blockAnonymizers && k != null && !exemptIp) {
            long id = s.anonymizers.find(k[0], k[1]);
            if (id >= 0) {
                return new Hit("ANONYMIZER", null);
            }
        }
        return null;
    }

    /** Yerel degisiklikten sonra goruntuyu hemen yeniler. */
    public synchronized void invalidate() {
        reload();
    }

    private Snapshot current() {
        Snapshot s = snap;
        long now = clock.millis();
        if (s != null && now - s.loadedAt < ttlMillis && now < s.nextExpiry) {
            return s;
        }
        synchronized (this) {
            s = snap;
            if (s != null && clock.millis() - s.loadedAt < ttlMillis && clock.millis() < s.nextExpiry) {
                return s;
            }
            return reload();
        }
    }

    private Snapshot reload() {
        Instant now = clock.instant();
        try {
            List<RangeSet.Entry> ipEntries = new ArrayList<>();
            Map<Long, String> kinds = new HashMap<>();
            Map<String, Long> devices = new HashMap<>();
            Map<Long, Long> users = new HashMap<>();
            long nextExpiry = Long.MAX_VALUE;
            for (AccessBan b : bans.findLive(now)) {
                if (b.getExpiresAt() != null) {
                    nextExpiry = Math.min(nextExpiry, b.getExpiresAt().toEpochMilli());
                }
                try {
                    switch (b.getKind()) {
                        case AccessBan.IP, AccessBan.CIDR -> {
                            ipEntries.add(new RangeSet.Entry(IpRanges.parse(b.getBanValue()), b.getId()));
                            kinds.put(b.getId(), b.getKind());
                        }
                        case AccessBan.DEVICE -> devices.put(b.getBanValue(), b.getId());
                        case AccessBan.USER -> users.put(Long.valueOf(b.getBanValue()), b.getId());
                        default -> { }
                    }
                } catch (IllegalArgumentException e) {
                    log.warn("Gecersiz engel kaydi atlandi: id={}", b.getId());
                }
            }
            List<RangeSet.Entry> anon = new ArrayList<>();
            if (blockAnonymizers) {
                for (AnonymizerRange r : anonymizers.findAll()) {
                    try {
                        anon.add(new RangeSet.Entry(IpRanges.parse(r.getCidr()), r.getId()));
                    } catch (IllegalArgumentException e) {
                        log.warn("Gecersiz anonimlestirici araligi atlandi: id={}", r.getId());
                    }
                }
            }
            snap = new Snapshot(RangeSet.of(ipEntries), kinds, devices, users, RangeSet.of(anon), clock.millis(),
                    nextExpiry);
        } catch (RuntimeException e) {
            // Veritabani gecici erisilemezse eski goruntu surer; sonraki deneme TTL sonra
            log.warn("Engel onbellegi yuklenemedi, eski goruntu kullaniliyor: {}", e.toString());
            Snapshot old = snap;
            snap = old == null
                    ? new Snapshot(RangeSet.EMPTY, Map.of(), Map.of(), Map.of(), RangeSet.EMPTY, clock.millis(), Long.MAX_VALUE)
                    : new Snapshot(old.ips, old.ipKinds, old.devices, old.users, old.anonymizers, clock.millis(),
                            old.nextExpiry);
        }
        return snap;
    }
}
