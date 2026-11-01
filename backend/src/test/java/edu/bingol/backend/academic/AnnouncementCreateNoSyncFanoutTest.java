package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.academic.AcademicDtos.AdminAnnouncementView;
import edu.bingol.backend.academic.AcademicDtos.AnnouncementRequest;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * FIX-P08 / A07#4: duyuru olusturma istegi toplu bildirimi BEKLEMEZ ve yazan islem geri alinirsa bildirim gitmez.
 * Gonderim COMMIT sonrasi (ve uretimde ayri is parcaciginda) yapilir; audienceCount COUNT sorgusudur.
 */
@SpringBootTest
class AnnouncementCreateNoSyncFanoutTest {

    static final Instant NOW = Instant.parse("2026-11-02T07:00:00Z");

    @Autowired JdbcTemplate jdbc;
    @Autowired PlatformTransactionManager txManager;

    NotificationService notifications;
    long adminId;

    @BeforeEach
    void setUp() {
        cleanup();
        for (int i = 0; i < 3; i++) {
            jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, department, faculty, "
                    + "grade, language, show_email, created_at) VALUES (?, 'x', 'T', TRUE, 'USER', 'ACTIVE', 'Hukuk', 'Hukuk Fakültesi', "
                    + "'1', 'tr', FALSE, CURRENT_TIMESTAMP)", "ans-" + i + "@bingol.edu.tr");
        }
        adminId = jdbc.queryForObject("SELECT id FROM app_user WHERE email = 'ans-0@bingol.edu.tr'", Long.class);
        notifications = mock(NotificationService.class);
        when(notifications.sendTemplatedBulk(anyCollection(), any(), anyMap(), any(), any(String[].class))).thenReturn(3);
    }

    @AfterEach
    void cleanup() {
        jdbc.update("DELETE FROM announcement_read");
        jdbc.update("DELETE FROM department_announcement");
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'ans-%'");
    }

    /** Ayri is parcaciginda calisir ama bitmesini bekler (uretimdeki tek iscilik yurutucunun deterministik karsiligi). */
    static final Executor OTHER_THREAD = r -> {
        Thread t = new Thread(r, "test-notify");
        t.start();
        try {
            t.join();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    };

    DepartmentAnnouncementService service(AnnouncementNotifier notifier) {
        return new DepartmentAnnouncementService(jdbc, new AcademicAudience(jdbc), notifier, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    static AnnouncementRequest request() {
        return new AnnouncementRequest("Final takvimi", "Sinavlar basliyor", "Hukuk", null, null, null, null, null, null, true, true);
    }

    @Test
    void createInsideTransactionDispatchesOnlyAfterCommit() {
        AnnouncementNotifier notifier = new AnnouncementNotifier(jdbc, notifications, Clock.fixed(NOW, ZoneOffset.UTC), OTHER_THREAD);
        DepartmentAnnouncementService svc = service(notifier);

        Long id = new TransactionTemplate(txManager).execute(status -> {
            AdminAnnouncementView v = svc.create(adminId, request());
            assertNotNull(v.id());
            // islem henuz commit olmadi: toplu bildirim YOK
            verify(notifications, never()).sendTemplatedBulk(anyCollection(), any(), anyMap(), any(), any(String[].class));
            return v.id();
        });

        assertNotNull(id);
        verify(notifications, times(1)).sendTemplatedBulk(anyCollection(), eq(AnnouncementNotifier.TEMPLATE), anyMap(), any(),
                eq("Final takvimi"), anyString());
    }

    @Test
    void rolledBackCreateNeverNotifies() {
        AnnouncementNotifier notifier = new AnnouncementNotifier(jdbc, notifications, Clock.fixed(NOW, ZoneOffset.UTC), OTHER_THREAD);
        DepartmentAnnouncementService svc = service(notifier);

        new TransactionTemplate(txManager).executeWithoutResult(status -> {
            svc.create(adminId, request());
            status.setRollbackOnly(); // geri alindi: afterCommit hic cagrilmaz
        });

        verify(notifications, never()).sendTemplatedBulk(anyCollection(), any(), anyMap(), any(), any(String[].class));
    }

    @Test
    void productionPathHandsDispatchToExecutorNotRequestThread() {
        AtomicInteger handed = new AtomicInteger();
        Executor deferred = r -> handed.incrementAndGet(); // calistirmaz: istek is parcacigi bildirimi beklemedigini gosterir
        AnnouncementNotifier notifier = new AnnouncementNotifier(jdbc, notifications, Clock.fixed(NOW, ZoneOffset.UTC), deferred);

        service(notifier).create(adminId, request()); // islem yok: AfterCommit hemen calisir, is yurutucuya devredilir

        assertEquals(1, handed.get());
        verify(notifications, never()).sendTemplatedBulk(anyCollection(), any(), anyMap(), any(), any(String[].class));
    }

    @Test
    void audienceCountIsCountQueryAndMatchesIds() {
        AnnouncementNotifier notifier = new AnnouncementNotifier(jdbc, notifications, Clock.fixed(NOW, ZoneOffset.UTC));
        DepartmentAnnouncementService svc = service(notifier);
        assertEquals(3, svc.audienceCount("hukuk", null, "1"));
        assertEquals(0, svc.audienceCount("hukuk", null, "2"));
        assertEquals(DepartmentAnnouncementService.audienceIds(jdbc, "Hukuk", null, "1").size(), svc.audienceCount("Hukuk", null, "1"));
    }
}
