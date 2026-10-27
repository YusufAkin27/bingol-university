package edu.bingol.backend.accessban;

import edu.bingol.backend.accessban.AccessBanDtos.*;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Erisim engeli yonetimi: ekleme (IP/CIDR/cihaz/kullanici), toplu yukleme, guncelleme, kaldirma, kullanici icin tek
 * tikla engel, anonimlestirici listesi, kullanici cihaz listesi ve istatistik. Her yeni engelde eslesen
 * kullanicilarin mevcut oturumlari kapatilir (WS dahil, kod ACCESS_BLOCKED). Cihaz kimligi YALNIZCA HMAC ozeti olarak
 * saklanir; yonetici ham kimlik girerse sunucu ozetler ve ham degeri atar.
 */
@Service
public class AccessBanService {

    static final int BULK_MAX = 5000;
    static final int CLOSE_MAX_USERS = 5000;
    static final Set<String> REASONS = Set.of("ABUSE", "SPAM", "FRAUD", "OTHER");
    private static final Pattern HASH = Pattern.compile("[0-9a-f]{64}");
    private static final Duration DEVICE_WINDOW = Duration.ofDays(90);
    private static final Duration IP_WINDOW = Duration.ofDays(30);
    private static final Duration SESSION_IP_WINDOW = Duration.ofDays(7);

    private final AccessBanRepository bans;
    private final AnonymizerRangeRepository anonymizers;
    private final UserDeviceLogRepository deviceLogs;
    private final BlockedAttemptLogRepository attempts;
    private final UserRepository users;
    private final AccessBanCache cache;
    private final AccessBanHits hits;
    private final ClientContexts contexts;
    private final SessionService sessions;
    private final ApplicationEventPublisher events;
    private final JdbcTemplate jdbc;
    private final Clock clock;

    public AccessBanService(AccessBanRepository bans, AnonymizerRangeRepository anonymizers,
                            UserDeviceLogRepository deviceLogs, BlockedAttemptLogRepository attempts,
                            UserRepository users, AccessBanCache cache, AccessBanHits hits, ClientContexts contexts,
                            SessionService sessions, ApplicationEventPublisher events, JdbcTemplate jdbc, Clock clock) {
        this.bans = bans;
        this.anonymizers = anonymizers;
        this.deviceLogs = deviceLogs;
        this.attempts = attempts;
        this.users = users;
        this.cache = cache;
        this.hits = hits;
        this.contexts = contexts;
        this.sessions = sessions;
        this.events = events;
        this.jdbc = jdbc;
        this.clock = clock;
    }

    // ---------------------------------------------------------------- ekleme

    @Transactional
    public BlockAccessResult create(Long adminId, CreateBanRequest r, ClientContext admin) {
        String reason = reason(r.reasonCode());
        String note = note(r.note());
        Instant expires = expiry(r.expiresAt());
        boolean force = Boolean.TRUE.equals(r.force());
        String kind = r.kind() == null ? "" : r.kind().trim().toUpperCase(Locale.ROOT);
        List<String> warnings = new ArrayList<>();
        List<AccessBan> created = new ArrayList<>();
        Set<Long> toClose = new LinkedHashSet<>();
        switch (kind) {
            case AccessBan.IP, AccessBan.CIDR -> {
                IpRanges.Range range = parseRange(r.value());
                checkRange(range, admin, force);
                ensure(range.single() ? AccessBan.IP : AccessBan.CIDR, range.canonical(), reason, note, expires,
                        adminId, created);
                toClose.addAll(usersInRange(List.of(range)));
            }
            case AccessBan.DEVICE -> {
                String hash = deviceHash(r.value());
                if (!force && admin != null && hash.equals(admin.deviceHash())) {
                    throw selfLockout();
                }
                ensure(AccessBan.DEVICE, hash, reason, note, expires, adminId, created);
                toClose.addAll(deviceLogs.usersOfDevices(List.of(hash)));
            }
            case AccessBan.USER -> {
                Long uid = userId(r.value());
                BlockAccessRequest br = new BlockAccessRequest(Boolean.TRUE.equals(r.alsoBlockUserDevices()),
                        Boolean.TRUE.equals(r.alsoBlockUserIps()), true, reason, note, expires, force);
                return blockUserInternal(adminId, uid, br, admin);
            }
            default -> throw invalid();
        }
        if (created.isEmpty()) {
            warnings.add("ALREADY_BANNED");
        }
        int closed = closeSessions(toClose, adminId);
        cache.invalidate();
        return new BlockAccessResult(views(created), (int) created.stream().filter(b -> AccessBan.DEVICE.equals(b.getKind())).count(),
                (int) created.stream().filter(b -> !AccessBan.DEVICE.equals(b.getKind()) && !AccessBan.USER.equals(b.getKind())).count(),
                closed, warnings);
    }

    /** Kullanici + (istege bagli) cihazlari + (istege bagli) IP'leri tek islemde engeller. */
    @Transactional
    public BlockAccessResult blockUser(Long adminId, Long userId, BlockAccessRequest r, ClientContext admin) {
        return blockUserInternal(adminId, userId, r, admin);
    }

    private BlockAccessResult blockUserInternal(Long adminId, Long userId, BlockAccessRequest r, ClientContext admin) {
        User target = users.findById(userId).filter(u -> u.getStatus() != UserStatus.DELETED)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
        if (target.getRole() == Role.ADMIN || userId.equals(adminId)) {
            throw selfLockout();
        }
        String reason = reason(r.reasonCode());
        String note = note(r.note());
        Instant expires = expiry(r.expiresAt());
        boolean force = Boolean.TRUE.equals(r.force());
        List<String> warnings = new ArrayList<>();
        List<AccessBan> created = new ArrayList<>();
        Instant now = clock.instant();
        Set<Long> toClose = new LinkedHashSet<>();
        toClose.add(userId);
        if (!Boolean.FALSE.equals(r.userBan())) {
            ensure(AccessBan.USER, String.valueOf(userId), reason, note, expires, adminId, created);
        }
        int devicesBlocked = 0;
        if (Boolean.TRUE.equals(r.devices())) {
            Set<String> hashes = new LinkedHashSet<>();
            for (UserDeviceLog l : deviceLogs.findSince(userId, now.minus(DEVICE_WINDOW))) {
                if (!UserDeviceLog.NO_DEVICE.equals(l.getDeviceHash())) {
                    hashes.add(l.getDeviceHash());
                }
            }
            for (String h : hashes) {
                if (!force && admin != null && h.equals(admin.deviceHash())) {
                    warnings.add("OWN_DEVICE_SKIPPED");
                    continue;
                }
                if (ensure(AccessBan.DEVICE, h, reason, note, expires, adminId, created) != null) {
                    devicesBlocked++;
                }
            }
            if (hashes.isEmpty()) {
                warnings.add("NO_DEVICE_ON_RECORD");
            }
            toClose.addAll(deviceLogs.usersOfDevices(hashes.isEmpty() ? List.of("-none-") : hashes));
        }
        int ipsBlocked = 0;
        if (Boolean.TRUE.equals(r.ips())) {
            Set<String> ipSet = new LinkedHashSet<>();
            for (UserDeviceLog l : deviceLogs.findSince(userId, now.minus(IP_WINDOW))) {
                ipSet.add(l.getIp());
            }
            for (String ip : ipSet) {
                IpRanges.Range range = IpRanges.parse(ip);
                if (cache.entirelyExempt(range)) {
                    continue; // ozel ag/izin listesi engellenmez
                }
                if (!force && ownIpIn(range, admin)) {
                    warnings.add("OWN_IP_SKIPPED");
                    continue;
                }
                if (ensure(AccessBan.IP, range.canonical(), reason, note, expires, adminId, created) != null) {
                    ipsBlocked++;
                    toClose.addAll(usersInRange(List.of(range)));
                }
            }
            if (ipsBlocked > 0) {
                warnings.add("SHARED_IP_RISK"); // paylasimli/CGNAT adres baska kullanicilari da etkileyebilir
            }
        }
        // Yonetici hesaplarinin oturumlari IP/cihaz kapsami nedeniyle kapatilmaz (kilitlenme onlemi)
        int closed = closeSessions(toClose, adminId);
        cache.invalidate();
        return new BlockAccessResult(views(created), devicesBlocked, ipsBlocked, closed, warnings);
    }

    // ---------------------------------------------------------------- toplu

    @Transactional
    public BulkResult bulk(Long adminId, BulkRequest r, ClientContext admin) {
        String reason = reason(r.reasonCode());
        String defaultNote = note(r.note());
        Instant expires = expiry(r.expiresAt());
        boolean force = Boolean.TRUE.equals(r.force());
        List<String[]> lines = splitLines(r.text());
        List<RejectedLine> rejected = new ArrayList<>();
        Instant now = clock.instant();
        Set<String> existing = new HashSet<>();
        for (AccessBan b : bans.findLive(now)) {
            if (AccessBan.IP.equals(b.getKind()) || AccessBan.CIDR.equals(b.getKind())) {
                existing.add(b.getBanValue());
            }
        }
        List<AccessBan> fresh = new ArrayList<>();
        List<IpRanges.Range> ranges = new ArrayList<>();
        int already = 0;
        for (String[] ln : lines) {
            int no = Integer.parseInt(ln[0]);
            String value = ln[1];
            IpRanges.Range range;
            try {
                range = IpRanges.parse(value);
            } catch (IllegalArgumentException e) {
                rejected.add(new RejectedLine(no, cut(value), "BAN_INVALID_VALUE"));
                continue;
            }
            if (cache.entirelyExempt(range)) {
                rejected.add(new RejectedLine(no, cut(value), "BAN_SELF_LOCKOUT"));
                continue;
            }
            if (!force && ownIpIn(range, admin)) {
                rejected.add(new RejectedLine(no, cut(value), "BAN_SELF_LOCKOUT"));
                continue;
            }
            if (!existing.add(range.canonical())) {
                already++;
                continue;
            }
            AccessBan b = newBan(range.single() ? AccessBan.IP : AccessBan.CIDR, range.canonical(), reason,
                    ln[2] != null ? note(ln[2]) : defaultNote, expires, adminId);
            fresh.add(b);
            ranges.add(range);
        }
        bans.saveAll(fresh);
        int closed = ranges.isEmpty() ? 0 : closeSessions(new LinkedHashSet<>(usersInRange(ranges)), adminId);
        cache.invalidate();
        return new BulkResult(fresh.size(), already, closed, rejected);
    }

    // ---------------------------------------------------------------- guncelle / kaldir / liste

    @Transactional
    public BanView patch(Long id, PatchBanRequest r) {
        AccessBan b = find(id);
        if (r.note() != null) {
            b.setNote(note(r.note()));
        }
        if (Boolean.TRUE.equals(r.noExpiry())) {
            b.setExpiresAt(null);
        } else if (r.expiresAt() != null) {
            b.setExpiresAt(expiry(r.expiresAt()));
        }
        if (r.active() != null) {
            b.setActive(r.active());
        }
        bans.save(b);
        cache.invalidate();
        return views(List.of(b)).get(0);
    }

    /** Engeli kaldirir (etkinsiz yapar; vurus gecmisi korunur). */
    @Transactional
    public void remove(Long id) {
        AccessBan b = find(id);
        b.setActive(false);
        bans.save(b);
        cache.invalidate();
    }

    public CursorPage<BanView> list(String kind, Boolean active, String q, Long cursor, int size) {
        int n = Math.min(Math.max(size, 1), 100);
        StringBuilder sql = new StringBuilder("SELECT id FROM access_ban WHERE 1 = 1");
        List<Object> args = new ArrayList<>();
        if (kind != null && !kind.isBlank()) {
            sql.append(" AND kind = ?");
            args.add(kind.trim().toUpperCase(Locale.ROOT));
        }
        Timestamp now = Timestamp.from(clock.instant());
        if (Boolean.TRUE.equals(active)) {
            sql.append(" AND active = TRUE AND (expires_at IS NULL OR expires_at > ?)");
            args.add(now);
        } else if (Boolean.FALSE.equals(active)) {
            sql.append(" AND (active = FALSE OR (expires_at IS NOT NULL AND expires_at <= ?))");
            args.add(now);
        }
        if (q != null && !q.isBlank()) {
            String like = "%" + q.trim().toLowerCase(Locale.ROOT).replace("\\", "\\\\").replace("%", "\\%")
                    .replace("_", "\\_") + "%";
            sql.append(" AND (LOWER(ban_value) LIKE ? ESCAPE '\\' OR LOWER(COALESCE(note, '')) LIKE ? ESCAPE '\\')");
            args.add(like);
            args.add(like);
        }
        if (cursor != null) {
            sql.append(" AND id < ?");
            args.add(cursor);
        }
        sql.append(" ORDER BY id DESC LIMIT ?");
        args.add(n + 1);
        List<Long> ids = jdbc.queryForList(sql.toString(), Long.class, args.toArray());
        boolean more = ids.size() > n;
        List<Long> page = more ? ids.subList(0, n) : ids;
        Map<Long, AccessBan> byId = new HashMap<>();
        bans.findAllById(page).forEach(b -> byId.put(b.getId(), b));
        List<AccessBan> ordered = page.stream().map(byId::get).filter(java.util.Objects::nonNull).toList();
        return new CursorPage<>(views(ordered), more ? page.get(page.size() - 1) : null);
    }

    public CursorPage<AttemptView> attempts(Long banId, Long cursor, int size) {
        find(banId);
        int n = Math.min(Math.max(size, 1), 100);
        hits.flush();
        List<BlockedAttemptLog> rows = cursor == null
                ? attempts.findByBanIdOrderByIdDesc(banId, PageRequest.of(0, n + 1))
                : attempts.findByBanIdAndIdLessThanOrderByIdDesc(banId, cursor, PageRequest.of(0, n + 1));
        return CursorPage.of(rows, n, BlockedAttemptLog::getId, a -> new AttemptView(a.getId(), a.getKind(), a.getIp(),
                ClientContexts.shortHash(a.getDeviceHash()), a.getUserId(), a.getPath(), a.getAttemptedAt().toString()));
    }

    public Stats stats() {
        hits.flush();
        Map<String, Long> active = new LinkedHashMap<>();
        for (String k : List.of(AccessBan.IP, AccessBan.CIDR, AccessBan.DEVICE, AccessBan.USER)) {
            active.put(k, 0L);
        }
        jdbc.query("SELECT kind, COUNT(*) FROM access_ban WHERE active = TRUE AND (expires_at IS NULL OR expires_at > ?) "
                + "GROUP BY kind", rs -> {
                    active.put(rs.getString(1), rs.getLong(2));
                }, Timestamp.from(clock.instant()));
        List<TopBan> top = jdbc.query("SELECT id, kind, ban_value, note, hit_count, last_hit_at FROM access_ban "
                + "WHERE hit_count > 0 ORDER BY hit_count DESC, id DESC LIMIT 5", (rs, i) -> new TopBan(rs.getLong(1),
                rs.getString(2), shown(rs.getString(2), rs.getString(3)), rs.getString(4), rs.getLong(5),
                rs.getTimestamp(6) == null ? null : rs.getTimestamp(6).toInstant().toString()));
        Long anon = jdbc.queryForObject("SELECT COUNT(*) FROM ban280_anonymizer_range", Long.class);
        return new Stats(active, anon == null ? 0 : anon, cache.blockAnonymizers(),
                attempts.countByAttemptedAtAfter(clock.instant().minus(Duration.ofHours(24))), top);
    }

    // ---------------------------------------------------------------- kullanici cihazlari

    public UserDevices userDevices(Long userId) {
        users.findById(userId).filter(u -> u.getStatus() != UserStatus.DELETED)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
        List<UserDeviceLog> logs = deviceLogs.findByUserIdOrderByLastSeenAtDesc(userId);
        Map<String, List<UserDeviceLog>> byDevice = new LinkedHashMap<>();
        List<UserDeviceLog> none = new ArrayList<>();
        for (UserDeviceLog l : logs) {
            if (UserDeviceLog.NO_DEVICE.equals(l.getDeviceHash())) {
                none.add(l);
            } else {
                byDevice.computeIfAbsent(l.getDeviceHash(), k -> new ArrayList<>()).add(l);
            }
        }
        Instant now = clock.instant();
        Map<String, Long> banned = new HashMap<>();
        if (!byDevice.isEmpty()) {
            for (AccessBan b : bans.findLive(now)) {
                if (AccessBan.DEVICE.equals(b.getKind()) && byDevice.containsKey(b.getBanValue())) {
                    banned.put(b.getBanValue(), b.getId());
                }
            }
        }
        List<DeviceView> out = new ArrayList<>();
        for (Map.Entry<String, List<UserDeviceLog>> e : byDevice.entrySet()) {
            List<UserDeviceLog> rows = e.getValue(); // son gorulene gore azalan
            UserDeviceLog latest = rows.get(0);
            UserDeviceLog earliest = rows.stream().min(java.util.Comparator.comparing(UserDeviceLog::getFirstSeenAt)).get();
            List<Long> others = deviceLogs.otherUsersOfDevice(e.getKey(), userId, PageRequest.of(0, 10));
            List<SharedUser> shared = users.findAllById(others).stream()
                    .map(u -> new SharedUser(u.getId(), u.getDisplayName())).toList();
            out.add(new DeviceView(e.getKey(), ClientContexts.shortHash(e.getKey()), latest.getPlatform(),
                    latest.getAppVersion(), earliest.getFirstSeenAt().toString(), latest.getLastSeenAt().toString(),
                    latest.getLastEvent(), rows.stream().mapToInt(UserDeviceLog::getSeenCount).sum(),
                    earliest.getIp(), latest.getIp(), rows.stream().map(this::ipSeen).toList(),
                    banned.containsKey(e.getKey()), banned.get(e.getKey()), shared));
        }
        return new UserDevices(userId, out, none.stream().map(this::ipSeen).toList());
    }

    private IpSeen ipSeen(UserDeviceLog l) {
        boolean blocked = cache.match(new ClientContext(l.getIp(), null, null, null), null) != null;
        return new IpSeen(l.getIp(), l.getIpFamily(), l.getFirstSeenAt().toString(), l.getLastSeenAt().toString(),
                l.getSeenCount(), blocked);
    }

    // ---------------------------------------------------------------- anonimlestirici listesi

    @Transactional
    public AnonymizerUploadResult uploadAnonymizers(AnonymizerUpload r) {
        String defaultSource = r.source() == null || r.source().isBlank() ? null : cut(r.source().trim(), 60);
        List<String[]> lines = splitLines(r.text());
        Set<String> have = new HashSet<>();
        anonymizers.findAll().forEach(a -> have.add(a.getCidr()));
        List<AnonymizerRange> fresh = new ArrayList<>();
        List<RejectedLine> rejected = new ArrayList<>();
        int dup = 0;
        for (String[] ln : lines) {
            int no = Integer.parseInt(ln[0]);
            IpRanges.Range range;
            try {
                range = IpRanges.parse(ln[1]);
            } catch (IllegalArgumentException e) {
                rejected.add(new RejectedLine(no, cut(ln[1]), "BAN_INVALID_VALUE"));
                continue;
            }
            if (cache.entirelyExempt(range)) {
                rejected.add(new RejectedLine(no, cut(ln[1]), "BAN_SELF_LOCKOUT"));
                continue;
            }
            if (!have.add(range.canonical())) {
                dup++;
                continue;
            }
            AnonymizerRange a = new AnonymizerRange();
            a.setCidr(range.canonical());
            a.setSource(ln[2] != null ? cut(ln[2], 60) : defaultSource);
            a.setAddedAt(clock.instant());
            fresh.add(a);
        }
        anonymizers.saveAll(fresh);
        cache.invalidate();
        return new AnonymizerUploadResult(fresh.size(), dup, rejected);
    }

    public AnonymizerList listAnonymizers(Long cursor, int size) {
        int n = Math.min(Math.max(size, 1), 200);
        List<AnonymizerRange> rows = cursor == null
                ? jdbc.query("SELECT id, cidr, source, added_at FROM ban280_anonymizer_range ORDER BY id DESC LIMIT ?",
                        this::anonRow, n + 1)
                : jdbc.query("SELECT id, cidr, source, added_at FROM ban280_anonymizer_range WHERE id < ? ORDER BY id DESC LIMIT ?",
                        this::anonRow, cursor, n + 1);
        boolean more = rows.size() > n;
        List<AnonymizerRange> page = more ? rows.subList(0, n) : rows;
        Map<String, Long> by = new LinkedHashMap<>();
        jdbc.query("SELECT COALESCE(source, '') s, COUNT(*) FROM ban280_anonymizer_range GROUP BY COALESCE(source, '')",
                rs -> {
                    by.put(rs.getString(1), rs.getLong(2));
                });
        long total = by.values().stream().mapToLong(Long::longValue).sum();
        return new AnonymizerList(cache.blockAnonymizers(), total, by,
                page.stream().map(a -> new AnonymizerView(a.getId(), a.getCidr(), a.getSource(), a.getAddedAt().toString())).toList(),
                more ? page.get(page.size() - 1).getId() : null);
    }

    private AnonymizerRange anonRow(java.sql.ResultSet rs, int i) throws java.sql.SQLException {
        AnonymizerRange a = new AnonymizerRange();
        a.setId(rs.getLong(1));
        a.setCidr(rs.getString(2));
        a.setSource(rs.getString(3));
        a.setAddedAt(rs.getTimestamp(4).toInstant());
        return a;
    }

    @Transactional
    public void deleteAnonymizer(Long id) {
        if (!anonymizers.existsById(id)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "BAN_NOT_FOUND", "Engel kaydı bulunamadı.");
        }
        anonymizers.deleteById(id);
        cache.invalidate();
    }

    /** Etikete (kaynak) gore toplu siler; bos etiket = etiketsiz kayitlar. Silinen sayiyi doner. */
    @Transactional
    public int deleteAnonymizersBySource(String source) {
        int n = source == null || source.isBlank()
                ? jdbc.update("DELETE FROM ban280_anonymizer_range WHERE source IS NULL")
                : jdbc.update("DELETE FROM ban280_anonymizer_range WHERE source = ?", source.trim());
        cache.invalidate();
        return n;
    }

    // ---------------------------------------------------------------- ic yardimcilar

    /** Canli esdeger engel varsa null doner (zaten engelli); yoksa olusturur ve olusturulanlar listesine ekler. */
    private AccessBan ensure(String kind, String value, String reason, String note, Instant expires, Long adminId,
                             List<AccessBan> created) {
        if (bans.findLiveByValue(kind, value, clock.instant()).isPresent()) {
            return null;
        }
        AccessBan b = bans.save(newBan(kind, value, reason, note, expires, adminId));
        created.add(b);
        return b;
    }

    private AccessBan newBan(String kind, String value, String reason, String note, Instant expires, Long adminId) {
        AccessBan b = new AccessBan();
        b.setKind(kind);
        b.setBanValue(value);
        b.setReasonCode(reason);
        b.setNote(note);
        b.setCreatedBy(adminId);
        b.setCreatedAt(clock.instant());
        b.setExpiresAt(expires);
        return b;
    }

    private AccessBan find(Long id) {
        return bans.findById(id).orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "BAN_NOT_FOUND", "Engel kaydı bulunamadı."));
    }

    private List<BanView> views(List<AccessBan> list) {
        Set<Long> uids = new HashSet<>();
        for (AccessBan b : list) {
            if (AccessBan.USER.equals(b.getKind())) {
                uids.add(Long.valueOf(b.getBanValue()));
            }
        }
        Map<Long, String> names = new HashMap<>();
        if (!uids.isEmpty()) {
            users.findAllById(uids).forEach(u -> names.put(u.getId(), u.getDisplayName()));
        }
        Instant now = clock.instant();
        List<BanView> out = new ArrayList<>();
        for (AccessBan b : list) {
            Long uid = AccessBan.USER.equals(b.getKind()) ? Long.valueOf(b.getBanValue()) : null;
            out.add(new BanView(b.getId(), b.getKind(), b.getBanValue(), AccessBan.DEVICE.equals(b.getKind())
                    ? ClientContexts.shortHash(b.getBanValue()) : b.getBanValue(), b.getNote(), b.getReasonCode(),
                    b.getCreatedBy(), b.getCreatedAt().toString(),
                    b.getExpiresAt() == null ? null : b.getExpiresAt().toString(), b.isActive(), b.liveAt(now),
                    b.getHitCount(), b.getLastHitAt() == null ? null : b.getLastHitAt().toString(), uid,
                    uid == null ? null : names.get(uid)));
        }
        return out;
    }

    /** Aralik(lar)a son 7 gunde denk gelen kullanicilar (oturum kapatmak icin). */
    private Set<Long> usersInRange(List<IpRanges.Range> ranges) {
        Set<Long> out = new LinkedHashSet<>();
        IpRanges.RangeSet set = IpRanges.RangeSet.of(ranges.stream().map(x -> new IpRanges.RangeSet.Entry(x, 1)).toList());
        Instant since = clock.instant().minus(SESSION_IP_WINDOW);
        if (ranges.size() == 1 && ranges.get(0).single()) {
            out.addAll(deviceLogs.usersOfIp(ranges.get(0).canonical(), since));
            return out;
        }
        for (Object[] row : deviceLogs.recentUserIps(since, PageRequest.of(0, 200_000))) {
            long[] k = IpRanges.keyOf((String) row[1]);
            if (k != null && set.find(k[0], k[1]) >= 0) {
                out.add((Long) row[0]);
            }
        }
        return out;
    }

    /** Kullanicilarin tum oturumlarini kapatir (yonetici hesaplari ve islemi yapan haric); kapatilan sayiyi doner. */
    private int closeSessions(Set<Long> uids, Long actorId) {
        if (uids.isEmpty()) {
            return 0;
        }
        List<Long> ids = uids.stream().filter(u -> !u.equals(actorId)).limit(CLOSE_MAX_USERS).toList();
        int n = 0;
        for (User u : users.findAllById(ids)) {
            if (u.getRole() == Role.ADMIN) {
                continue;
            }
            // WS once ACCESS_BLOCKED koduyla kapanir; sonra token'lar iptal edilir
            events.publishEvent(new AccessBlockedEvent(u.getId()));
            sessions.revokeAll(u.getId());
            n++;
        }
        return n;
    }

    private static boolean ownIpIn(IpRanges.Range range, ClientContext admin) {
        if (admin == null || admin.ip() == null) {
            return false;
        }
        long[] k = IpRanges.keyOf(admin.ip());
        return k != null && range.contains(k[0], k[1]);
    }

    private void checkRange(IpRanges.Range range, ClientContext admin, boolean force) {
        if (cache.entirelyExempt(range)) {
            throw selfLockout(); // ozel ag / izin listesi zaten engellenemez
        }
        if (!force && ownIpIn(range, admin)) {
            throw selfLockout();
        }
    }

    private IpRanges.Range parseRange(String value) {
        try {
            return IpRanges.parse(value);
        } catch (IllegalArgumentException e) {
            throw invalid();
        }
    }

    /** 64 haneli ozet oldugu gibi, aksi halde ham kimlik HMAC'lenir (ham deger saklanmaz). */
    private String deviceHash(String value) {
        if (value == null) {
            throw invalid();
        }
        String v = value.trim();
        if (HASH.matcher(v.toLowerCase(Locale.ROOT)).matches()) {
            return v.toLowerCase(Locale.ROOT);
        }
        if (!ClientContexts.validRaw(v)) {
            throw invalid();
        }
        return contexts.hash(v);
    }

    private static Long userId(String value) {
        try {
            long id = Long.parseLong(value == null ? "" : value.trim());
            if (id <= 0) {
                throw invalid();
            }
            return id;
        } catch (NumberFormatException e) {
            throw invalid();
        }
    }

    private static String reason(String code) {
        if (code == null || code.isBlank()) {
            return "OTHER";
        }
        String c = code.trim().toUpperCase(Locale.ROOT);
        if (!REASONS.contains(c)) {
            throw invalid();
        }
        return c;
    }

    private static String note(String note) {
        if (note == null || note.isBlank()) {
            return null;
        }
        return cut(note.trim(), 300);
    }

    private Instant expiry(Instant at) {
        if (at != null && !at.isAfter(clock.instant())) {
            throw invalid();
        }
        return at;
    }

    /** Satirlari {no, deger, etiket|null} olarak ayirir; bos ve # satirlari atlanir; 5000 satiri asarsa 400. */
    static List<String[]> splitLines(String text) {
        if (text == null || text.isBlank()) {
            throw invalid();
        }
        List<String[]> out = new ArrayList<>();
        int no = 0;
        for (String raw : text.split("\\R")) {
            no++;
            String s = raw.trim();
            if (s.isEmpty() || s.startsWith("#")) {
                continue;
            }
            if (out.size() >= BULK_MAX) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "BAN_BULK_TOO_LARGE",
                        "Toplu yüklemede en çok " + BULK_MAX + " satır olabilir.", String.valueOf(BULK_MAX));
            }
            String[] parts = s.split("[\\s,;]+", 2);
            out.add(new String[] {String.valueOf(no), parts[0], parts.length > 1 && !parts[1].isBlank() ? parts[1].trim() : null});
        }
        if (out.isEmpty()) {
            throw invalid();
        }
        return out;
    }

    private static String cut(String s) {
        return cut(s, 60);
    }

    private static String cut(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max);
    }

    private static String shown(String kind, String value) {
        return AccessBan.DEVICE.equals(kind) ? ClientContexts.shortHash(value) : value;
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "BAN_INVALID_VALUE", "Engel değeri geçersiz.");
    }

    private static ApiException selfLockout() {
        return new ApiException(HttpStatus.BAD_REQUEST, "BAN_SELF_LOCKOUT",
                "Bu engel sizi veya yönetim ağını kilitleyebilir; işlem reddedildi.");
    }
}
