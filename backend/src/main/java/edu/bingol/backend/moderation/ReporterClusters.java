package edu.bingol.backend.moderation;

import edu.bingol.backend.accessban.UserDeviceLog;
import edu.bingol.backend.accessban.UserDeviceLogRepository;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Esige sayilan raporlayicilari "bagimsiz" kumeye indirger (T-057, A16-08): ayni cihaz ozetini (HMAC) paylasan ya da
 * ayni (az kullanicili) IP'den gorulen hesaplar TEK sayilir. Boylece tek kisinin kontrolundeki 3 hesap otomatik
 * gizlemeyi tetikleyemez. Cok kullanicili IP'ler (kampus NAT'i; esik {@code app.moderation.cluster-ip-max-users})
 * sinyal sayilmaz, yoksa gercek ogrenci raporlari da tek sayilirdi.
 */
@Service
public class ReporterClusters {

    /** Hesaplanacak en fazla raporlayici (daha fazlasi zaten esigin cok ustundedir). */
    static final int MAX_IDS = 200;

    private final UserDeviceLogRepository logs;

    @Value("${app.moderation.reporter-clustering:true}")
    private boolean enabled = true;
    @Value("${app.moderation.cluster-ip-max-users:5}")
    private int ipMaxUsers = 5;

    public ReporterClusters(UserDeviceLogRepository logs) {
        this.logs = logs;
    }

    boolean enabled() {
        return enabled;
    }

    void configure(boolean enabled, int ipMaxUsers) {
        this.enabled = enabled;
        this.ipMaxUsers = ipMaxUsers;
    }

    /** Birbirinden bagimsiz raporlayici sayisi (kume sayisi). Kumeleme kapaliysa girdi boyutu. */
    @Transactional(readOnly = true)
    public int independentCount(Collection<Long> reporterIds) {
        List<Long> ids = new ArrayList<>(new java.util.LinkedHashSet<>(reporterIds));
        if (ids.size() > MAX_IDS) {
            ids = ids.subList(0, MAX_IDS);
        }
        if (!enabled || ids.size() < 2) {
            return ids.size();
        }
        List<UserDeviceLog> rows = logs.findByUserIdIn(ids);
        if (rows.isEmpty()) {
            return ids.size();
        }
        Map<Long, Long> parent = new HashMap<>();
        ids.forEach(i -> parent.put(i, i));

        // IP basina toplam farkli kullanici (yalniz az kullanicili IP'ler sinyal)
        Set<String> ips = rows.stream().map(UserDeviceLog::getIp).collect(Collectors.toSet());
        Map<String, Long> ipUsers = new HashMap<>();
        for (Object[] r : logs.userCountsByIp(ips)) {
            ipUsers.put((String) r[0], ((Number) r[1]).longValue());
        }

        Map<String, Long> firstByDevice = new HashMap<>();
        Map<String, Long> firstByIp = new HashMap<>();
        for (UserDeviceLog l : rows) {
            Long uid = l.getUserId();
            if (!UserDeviceLog.NO_DEVICE.equals(l.getDeviceHash())) {
                Long other = firstByDevice.putIfAbsent(l.getDeviceHash(), uid);
                if (other != null) {
                    union(parent, other, uid);
                }
            }
            if (ipUsers.getOrDefault(l.getIp(), Long.MAX_VALUE) <= ipMaxUsers) {
                Long other = firstByIp.putIfAbsent(l.getIp(), uid);
                if (other != null) {
                    union(parent, other, uid);
                }
            }
        }
        return (int) ids.stream().map(i -> find(parent, i)).distinct().count();
    }

    private static Long find(Map<Long, Long> parent, Long x) {
        Long r = x;
        while (!parent.get(r).equals(r)) {
            r = parent.get(r);
        }
        Long cur = x;
        while (!parent.get(cur).equals(r)) {
            Long next = parent.get(cur);
            parent.put(cur, r);
            cur = next;
        }
        return r;
    }

    private static void union(Map<Long, Long> parent, Long a, Long b) {
        if (!parent.containsKey(a) || !parent.containsKey(b)) {
            return;
        }
        Long ra = find(parent, a);
        Long rb = find(parent, b);
        if (!ra.equals(rb)) {
            parent.put(ra, rb);
        }
    }
}
