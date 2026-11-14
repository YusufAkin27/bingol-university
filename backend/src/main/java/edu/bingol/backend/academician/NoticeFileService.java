package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.FileView;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.media.PrivateMediaStore;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;

/**
 * Duyuru dosyalari. Depolama MEVCUT ozel medya deposudur (PrivateMediaStore: /files/** disinda, URL ile erisilemez, diskte
 * BlobCipher ile sifreli); yeni depo katmani yoktur, bayt veritabanina yazilmaz. Akis (sohbet eki deseni): once
 * {@code POST /api/academician/courses/{id}/notice-files} ile yukle (bekleyen dosya), sonra duyuru olusturulurken
 * {@code fileIds} ile bagla. Indirme yalniz yetkililere: sahip ogretim elemani, dersin KAYITLI ogrencileri, yonetici;
 * digerlerine 404. Her indirme attachment + nosniff + no-store.
 */
@Service
public class NoticeFileService {

    private static final Logger log = LoggerFactory.getLogger(NoticeFileService.class);
    static final String BUCKET = "acnotice";
    public static final int MAX_FILES = 5;
    public static final long MAX_BYTES = 20L << 20;
    static final Duration PENDING_TTL = Duration.ofHours(24);

    private final AcademicianGuard guard;
    private final AcNoticeFileRepository files;
    private final AcNoticeRepository notices;
    private final AcEnrollmentRepository enrollments;
    private final PrivateMediaStore store;
    private final AcademicianProperties props;
    private final Clock clock;
    private final TransactionTemplate tx;

    public NoticeFileService(AcademicianGuard guard, AcNoticeFileRepository files, AcNoticeRepository notices,
                             AcEnrollmentRepository enrollments, PrivateMediaStore store, AcademicianProperties props,
                             Clock clock, PlatformTransactionManager tm) {
        this.guard = guard;
        this.files = files;
        this.notices = notices;
        this.enrollments = enrollments;
        this.store = store;
        this.props = props;
        this.clock = clock;
        this.tx = new TransactionTemplate(tm);
    }

    // ---- yukleme ----

    /** Tek dosya yukler (bekleyen). Dogrulama: uzanti + icerik imzasi, boyut, dosya sayisi, ders depolama siniri. */
    public FileView upload(Long userId, Long courseId, MultipartFile file) {
        AcCourse course = guard.ownCourse(userId, courseId);
        if (file == null || file.isEmpty()) {
            throw typeNotAllowed();
        }
        if (file.getSize() > MAX_BYTES) {
            throw tooLarge();
        }
        byte[] data;
        try (InputStream in = file.getInputStream()) {
            data = in.readNBytes((int) MAX_BYTES + 1);
        } catch (IOException e) {
            throw typeNotAllowed();
        }
        if (data.length > MAX_BYTES) {
            throw tooLarge();
        }
        String name = NoticeFileSniffer.sanitizeName(file.getOriginalFilename());
        NoticeFileSniffer.Detected det = NoticeFileSniffer.detect(name, data).orElseThrow(NoticeFileService::typeNotAllowed);
        cleanStale();
        if (files.pendingOf(course.getId(), userId, PageRequest.of(0, MAX_FILES + 1)).size() >= MAX_FILES) {
            throw limit();
        }
        long cap = props.courseStorageCapMb() * 1024L * 1024L;
        if (files.totalBytes(course.getId()) + data.length > cap) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "NOTICE_STORAGE_CAP",
                    "Bu dersin dosya depolama sınırına ulaşıldı.");
        }
        String key = store.storeBlob(BUCKET, data);
        AcNoticeFile f = new AcNoticeFile();
        f.setCourseId(course.getId());
        f.setStorageKey(key);
        f.setOriginalName(name);
        f.setContentType(det.contentType());
        f.setSizeBytes(data.length);
        f.setUploadedBy(userId);
        f.setCreatedAt(clock.instant());
        try {
            AcNoticeFile saved = tx.execute(s -> files.save(f));
            return view(saved);
        } catch (RuntimeException e) {
            store.delete(BUCKET, key); // satir yazilamadiysa yetim bayt birakma
            throw e;
        }
    }

    /** Bekleyen (henuz baglanmamis) kendi dosyasini siler. */
    public void deletePending(Long userId, Long fileId) {
        AcNoticeFile f = files.findById(fileId).orElseThrow(AcErrors::noticeNotFound);
        guard.ownCourse(userId, f.getCourseId());
        if (f.getNoticeId() != null || !userId.equals(f.getUploadedBy())) {
            throw AcErrors.noticeNotFound();
        }
        tx.executeWithoutResult(s -> files.delete(f));
        store.delete(BUCKET, f.getStorageKey());
    }

    // ---- duyuruya baglama ----

    /** Duyuru OLUSTURULMADAN once: kimlikler bu ogretim elemaninin bu dersteki bekleyen dosyalari olmali (en cok 5). */
    List<AcNoticeFile> requirePending(Long courseId, Long userId, List<Long> ids) {
        if (ids == null || ids.isEmpty()) {
            return List.of();
        }
        Set<Long> distinct = new HashSet<>(ids);
        if (distinct.size() > MAX_FILES) {
            throw limit();
        }
        List<AcNoticeFile> rows = files.byIds(distinct);
        if (rows.size() != distinct.size()) {
            throw AcErrors.invalid("fileIds");
        }
        for (AcNoticeFile f : rows) {
            if (f.getNoticeId() != null || !courseId.equals(f.getCourseId()) || !userId.equals(f.getUploadedBy())) {
                throw AcErrors.invalid("fileIds");
            }
        }
        return rows;
    }

    void attach(Collection<AcNoticeFile> rows, Long noticeId) {
        for (AcNoticeFile f : rows) {
            f.setNoticeId(noticeId);
            files.save(f);
        }
    }

    /** Duyuru silinirken: dosya satirlarini siler, depo anahtarlarini dondurur (cagiran commit sonrasi nesneleri siler). */
    List<String> removeRowsOfNotice(Long noticeId) {
        List<AcNoticeFile> rows = files.ofNotices(List.of(noticeId), PageRequest.of(0, MAX_FILES * 4));
        List<String> keys = new ArrayList<>();
        for (AcNoticeFile f : rows) {
            keys.add(f.getStorageKey());
            files.delete(f);
        }
        return keys;
    }

    void deleteObjects(Collection<String> keys) {
        for (String k : keys) {
            store.delete(BUCKET, k);
        }
    }

    /** 24 saatten eski bekleyen dosyalar (lazy temizlik; zamanlayici yok). */
    private void cleanStale() {
        try {
            for (AcNoticeFile f : files.stalePending(clock.instant().minus(PENDING_TTL), PageRequest.of(0, 50))) {
                tx.executeWithoutResult(s -> files.delete(f));
                store.delete(BUCKET, f.getStorageKey());
            }
        } catch (RuntimeException e) {
            log.warn("Bekleyen duyuru dosyasi temizligi yarim kaldi: {}", e.toString());
        }
    }

    // ---- okuma ----

    /** Duyuru kimligine gore dosya gorunumleri (liste ekranlari icin toplu). */
    Map<Long, List<FileView>> viewsByNotice(Collection<Long> noticeIds) {
        Map<Long, List<FileView>> out = new HashMap<>();
        if (noticeIds.isEmpty()) {
            return out;
        }
        for (AcNoticeFile f : files.ofNotices(noticeIds, PageRequest.of(0, noticeIds.size() * MAX_FILES))) {
            out.computeIfAbsent(f.getNoticeId(), k -> new ArrayList<>()).add(view(f));
        }
        return out;
    }

    /** Ogretim elemani indirmesi: yalniz kendi dersinin duyurusu. */
    public ResponseEntity<byte[]> downloadForOwner(Long userId, Long noticeId, Long fileId) {
        AcNotice n = notices.findById(noticeId).orElseThrow(AcErrors::noticeNotFound);
        guard.ownCourse(userId, n.getCourseId()); // baskasinin dersi: 404
        return serve(noticeId, fileId);
    }

    /** Ogrenci indirmesi: dersin KAYITLI ogrencisi; kayitli degilse ya da yol tutarsizsa 404. */
    public ResponseEntity<byte[]> downloadForStudent(Long studentId, Long courseId, Long noticeId, Long fileId) {
        AcNotice n = notices.findById(noticeId).orElseThrow(AcErrors::noticeNotFound);
        if (!n.getCourseId().equals(courseId) || !enrollments.existsByCourseIdAndStudentId(courseId, studentId)) {
            throw AcErrors.noticeNotFound();
        }
        return serve(noticeId, fileId);
    }

    /** Yonetici indirmesi (denetimli okuma controller'da). */
    public ResponseEntity<byte[]> downloadForAdmin(Long noticeId, Long fileId) {
        notices.findById(noticeId).orElseThrow(AcErrors::noticeNotFound);
        return serve(noticeId, fileId);
    }

    private ResponseEntity<byte[]> serve(Long noticeId, Long fileId) {
        AcNoticeFile f = files.findByIdAndNoticeId(fileId, noticeId).orElseThrow(AcErrors::noticeNotFound);
        byte[] data = store.read(BUCKET, f.getStorageKey());
        if (data == null) {
            throw AcErrors.noticeNotFound();
        }
        String disposition = ContentDisposition.attachment().filename(f.getOriginalName(), StandardCharsets.UTF_8).build().toString();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, f.getContentType())
                .header(HttpHeaders.CONTENT_DISPOSITION, disposition)
                .header("X-Content-Type-Options", "nosniff")
                .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
                .header("Content-Security-Policy", "default-src 'none'; sandbox")
                .contentLength(data.length)
                .body(data);
    }

    static FileView view(AcNoticeFile f) {
        return new FileView(f.getId(), f.getOriginalName(), f.getContentType(), f.getSizeBytes());
    }

    private static ApiException typeNotAllowed() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "NOTICE_FILE_TYPE_NOT_ALLOWED",
                "Bu dosya türüne izin verilmiyor.");
    }

    private static ApiException tooLarge() {
        return new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "NOTICE_FILE_TOO_LARGE",
                "Dosya en fazla " + (MAX_BYTES >> 20) + " MB olabilir.", String.valueOf(MAX_BYTES >> 20));
    }

    private static ApiException limit() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "NOTICE_FILE_LIMIT",
                "Bir duyuruya en fazla " + MAX_FILES + " dosya eklenebilir.", String.valueOf(MAX_FILES));
    }
}
