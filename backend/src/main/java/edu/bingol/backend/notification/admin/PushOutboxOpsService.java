package edu.bingol.backend.notification.admin;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.notification.admin.PushAdminDtos.ActionResult;
import edu.bingol.backend.notification.admin.PushAdminDtos.BulkAction;
import edu.bingol.backend.notification.admin.PushAdminDtos.BulkFailure;
import edu.bingol.backend.notification.admin.PushAdminDtos.BulkResult;
import edu.bingol.backend.notification.admin.PushAdminDtos.OutboxDetail;
import edu.bingol.backend.notification.admin.PushAdminDtos.OutboxRow;
import edu.bingol.backend.notification.outbox.PushOutboxStatus;
import edu.bingol.backend.notification.outbox.PushQueued;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.TypedQuery;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici: push kuyrugu listesi/ayrintisi ve tek/toplu islemler (yeniden dene, iptal). Yuk (baslik/govde/veri) ve ham token
 * hicbir yolla okunmaz: sorgular yalniz meta sutunlari secer, hedef maskelenir. Durum degisiklikleri kosullu (atomik) UPDATE
 * ile yapilir; boylece isleyiciyle yaris durumunda yanlis kayit bozulmaz (0 satir -> 409 PUSHADMIN_STATE_CONFLICT).
 */
@Service
public class PushOutboxOpsService {

    public static final int BULK_MAX = 200;
    static final int MAX_PAGE_SIZE = 100;
    private static final ZoneId ISTANBUL = ZoneId.of("Europe/Istanbul");

    /** Yeniden denenebilir (gonderilmemis ya da basarisiz) durumlar. */
    static final Set<PushOutboxStatus> RETRYABLE =
            Set.of(PushOutboxStatus.DEAD, PushOutboxStatus.FAILED, PushOutboxStatus.CANCELLED);
    /** Iptal edilebilir: henuz isleyicinin elinde olmayan, gonderilmemis kayitlar. */
    static final Set<PushOutboxStatus> CANCELLABLE = Set.of(PushOutboxStatus.PENDING, PushOutboxStatus.FAILED);

    private static final String META = "o.id, o.userId, o.fcmTokenHash, o.status, o.msgType, o.campaignId, o.attempts, "
            + "o.errorCode, o.nextAttemptAt, o.createdAt, o.sentAt";

    @PersistenceContext
    private EntityManager em;

    private final ApplicationEventPublisher events;
    private final int maxAttempts;

    public PushOutboxOpsService(ApplicationEventPublisher events,
                                @Value("${app.push.outbox.max-attempts:6}") int maxAttempts) {
        this.events = events;
        this.maxAttempts = Math.max(1, maxAttempts);
    }

    /** Liste suzgeci; bos alanlar suzmez. to dahil gun sayilir (Istanbul gun siniri). */
    public record Filter(String status, String type, Long campaignId, LocalDate from, LocalDate to) {}

    @Transactional(readOnly = true)
    public PageResponse<OutboxRow> list(Filter f, int page, int size) {
        int s = Math.min(MAX_PAGE_SIZE, Math.max(1, size));
        int p = Math.max(0, page);
        StringBuilder where = new StringBuilder(" WHERE 1 = 1");
        PushOutboxStatus status = parseStatus(f.status());
        String type = parseType(f.type());
        if (status != null) {
            where.append(" AND o.status = :status");
        }
        if (type != null) {
            where.append(" AND o.msgType = :type");
        }
        if (f.campaignId() != null) {
            where.append(" AND o.campaignId = :cid");
        }
        if (f.from() != null) {
            where.append(" AND o.createdAt >= :from");
        }
        if (f.to() != null) {
            where.append(" AND o.createdAt < :to");
        }
        TypedQuery<Long> count = em.createQuery("SELECT COUNT(o) FROM PushOutbox o" + where, Long.class);
        TypedQuery<Object[]> rows = em.createQuery(
                "SELECT " + META + " FROM PushOutbox o" + where + " ORDER BY o.id DESC", Object[].class);
        for (jakarta.persistence.Query q : List.of(count, rows)) {
            if (status != null) {
                q.setParameter("status", status);
            }
            if (type != null) {
                q.setParameter("type", type);
            }
            if (f.campaignId() != null) {
                q.setParameter("cid", f.campaignId());
            }
            if (f.from() != null) {
                q.setParameter("from", f.from().atStartOfDay(ISTANBUL).toInstant());
            }
            if (f.to() != null) {
                q.setParameter("to", f.to().plusDays(1).atStartOfDay(ISTANBUL).toInstant());
            }
        }
        long total = count.getSingleResult();
        rows.setFirstResult(p * s);
        rows.setMaxResults(s);
        List<OutboxRow> items = new ArrayList<>();
        for (Object[] r : rows.getResultList()) {
            items.add(toRow(r));
        }
        return PageResponse.of(items, p, s, total);
    }

    @Transactional(readOnly = true)
    public OutboxDetail detail(Long id) {
        List<Object[]> res = em.createQuery("SELECT " + META + ", o.lastError, o.priority, o.leaseUntil "
                        + "FROM PushOutbox o WHERE o.id = :id", Object[].class)
                .setParameter("id", id).getResultList();
        if (res.isEmpty()) {
            throw notFound();
        }
        Object[] r = res.get(0);
        PushOutboxStatus st = (PushOutboxStatus) r[3];
        return new OutboxDetail((Long) r[0], st.name(), (String) r[4], (Long) r[5], PushMask.tokenRef((String) r[2]),
                PushMask.userRef((Long) r[1]), (Integer) r[6], maxAttempts, (String) r[7], (String) r[11],
                ((Number) r[12]).intValue(), iso(r[8]), iso(r[13]), iso(r[9]), iso(r[10]),
                RETRYABLE.contains(st), CANCELLABLE.contains(st));
    }

    /** DEAD/FAILED/CANCELLED kaydi hemen yeniden kuyruga alir (deneme sayaci sifirlanir, 24 saatlik omur yeniden baslar). */
    @Transactional
    public ActionResult retry(Long id) {
        applyRetry(id);
        events.publishEvent(new PushQueued(1));
        return new ActionResult(id, PushOutboxStatus.PENDING.name());
    }

    /** PENDING/FAILED kaydi gonderilmeden iptal eder; isleyicinin elindeki (SENDING) ve gonderilmis kayit iptal edilemez. */
    @Transactional
    public ActionResult cancel(Long id) {
        applyCancel(id);
        return new ActionResult(id, PushOutboxStatus.CANCELLED.name());
    }

    /** Kismi basari: gecersiz/uygun olmayan kimlikler failed listesine duser, digerleri islenir. */
    @Transactional
    public BulkResult bulk(BulkAction action, List<Long> ids) {
        if (ids == null || ids.isEmpty() || ids.size() > BULK_MAX) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PUSHADMIN_BULK_INVALID",
                    "Toplu işlem 1 ile " + BULK_MAX + " kayıt arasında olmalıdır.", String.valueOf(BULK_MAX));
        }
        Set<Long> distinct = new LinkedHashSet<>();
        for (Long id : ids) {
            if (id == null || id <= 0) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "PUSHADMIN_BULK_INVALID",
                        "Toplu işlem 1 ile " + BULK_MAX + " kayıt arasında olmalıdır.", String.valueOf(BULK_MAX));
            }
            distinct.add(id);
        }
        List<BulkFailure> failed = new ArrayList<>();
        int ok = 0;
        for (Long id : distinct) {
            try {
                if (action == BulkAction.RETRY) {
                    applyRetry(id);
                } else {
                    applyCancel(id);
                }
                ok++;
            } catch (ApiException e) {
                failed.add(new BulkFailure(id, e.status() == HttpStatus.NOT_FOUND ? "NOT_FOUND" : "INVALID_STATE"));
            }
        }
        if (action == BulkAction.RETRY && ok > 0) {
            events.publishEvent(new PushQueued(ok));
        }
        return new BulkResult(action, distinct.size(), ok, failed);
    }

    private void applyRetry(Long id) {
        int n = em.createQuery("UPDATE PushOutbox o SET o.status = :pending, o.attempts = 0, o.nextAttemptAt = :now, "
                        + "o.createdAt = :now, o.leaseUntil = NULL WHERE o.id = :id AND o.status IN :from")
                .setParameter("pending", PushOutboxStatus.PENDING).setParameter("now", Instant.now())
                .setParameter("id", id).setParameter("from", RETRYABLE).executeUpdate();
        if (n == 0) {
            throw missingOrConflict(id);
        }
    }

    private void applyCancel(Long id) {
        int n = em.createQuery("UPDATE PushOutbox o SET o.status = :cancelled, o.leaseUntil = NULL, "
                        + "o.errorCode = 'ADMIN_CANCELLED', o.lastError = 'yonetici tarafindan iptal edildi' "
                        + "WHERE o.id = :id AND o.status IN :from")
                .setParameter("cancelled", PushOutboxStatus.CANCELLED).setParameter("id", id)
                .setParameter("from", CANCELLABLE).executeUpdate();
        if (n == 0) {
            throw missingOrConflict(id);
        }
    }

    private ApiException missingOrConflict(Long id) {
        List<PushOutboxStatus> cur = em.createQuery("SELECT o.status FROM PushOutbox o WHERE o.id = :id",
                PushOutboxStatus.class).setParameter("id", id).getResultList();
        if (cur.isEmpty()) {
            return notFound();
        }
        return new ApiException(HttpStatus.CONFLICT, "PUSHADMIN_STATE_CONFLICT",
                "Kaydın mevcut durumunda bu işlem yapılamaz.", cur.get(0).name());
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "PUSHADMIN_OUTBOX_NOT_FOUND", "Kuyruk kaydı bulunamadı.");
    }

    private static OutboxRow toRow(Object[] r) {
        return new OutboxRow((Long) r[0], ((PushOutboxStatus) r[3]).name(), (String) r[4], (Long) r[5],
                PushMask.tokenRef((String) r[2]), PushMask.userRef((Long) r[1]), (Integer) r[6], (String) r[7],
                iso(r[8]), iso(r[9]), iso(r[10]));
    }

    private static String iso(Object o) {
        return o == null ? null : o.toString();
    }

    private static PushOutboxStatus parseStatus(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        try {
            return PushOutboxStatus.valueOf(s.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw badFilter();
        }
    }

    private static String parseType(String s) {
        if (s == null || s.isBlank()) {
            return null;
        }
        try {
            return NotificationType.valueOf(s.trim().toUpperCase(Locale.ROOT)).name();
        } catch (IllegalArgumentException e) {
            throw badFilter();
        }
    }

    private static ApiException badFilter() {
        return new ApiException(HttpStatus.BAD_REQUEST, "PUSHADMIN_FILTER_INVALID", "Süzgeç değeri geçersiz.");
    }
}
