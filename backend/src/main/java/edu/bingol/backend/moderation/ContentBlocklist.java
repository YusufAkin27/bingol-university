package edu.bingol.backend.moderation;

import edu.bingol.backend.common.ApiException;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yasakli icerik ozeti listesi. Medya hatti (T1) yuklemede ham/yeniden kodlanmis baytin SHA-256 ozetiyle
 * {@link #isBlocked(String)} sorgular; eslesirse yukleme reddedilir. Liste yoneticiyle yonetilir.
 */
@Service
public class ContentBlocklist {

    private static final Pattern SHA256 = Pattern.compile("^[0-9a-f]{64}$");

    private final BlockedContentHashRepository repo;

    public ContentBlocklist(BlockedContentHashRepository repo) {
        this.repo = repo;
    }

    /** Ozet (buyuk/kucuk harf fark etmez) listede mi. Gecersiz bicimde false doner (cagiran dogrulamaz). */
    @Transactional(readOnly = true)
    public boolean isBlocked(String sha256Hex) {
        String h = normalize(sha256Hex);
        return h != null && repo.existsById(h);
    }

    /** Idempotent ekleme; zaten varsa mevcut kayit korunur. */
    @Transactional
    public BlockedContentHash add(String sha256Hex, String note, Long adminId) {
        String h = normalize(sha256Hex);
        if (h == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "BLOCKLIST_HASH_INVALID",
                    "Geçersiz özet: 64 karakterlik SHA-256 (hex) olmalı.");
        }
        return repo.findById(h).orElseGet(() -> repo.save(new BlockedContentHash(h,
                note == null || note.isBlank() ? null : note.trim(), adminId)));
    }

    @Transactional
    public void remove(String sha256Hex) {
        String h = normalize(sha256Hex);
        if (h == null || !repo.existsById(h)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "BLOCKLIST_ENTRY_NOT_FOUND", "Özet listede yok.");
        }
        repo.deleteById(h);
    }

    @Transactional(readOnly = true)
    public List<BlockedContentHash> page(String cursor, int size) {
        return repo.page(cursor == null || cursor.isBlank() ? null : cursor, PageRequest.of(0, size + 1));
    }

    static String normalize(String v) {
        if (v == null) {
            return null;
        }
        String h = v.trim().toLowerCase(Locale.ROOT);
        return SHA256.matcher(h).matches() ? h : null;
    }
}
