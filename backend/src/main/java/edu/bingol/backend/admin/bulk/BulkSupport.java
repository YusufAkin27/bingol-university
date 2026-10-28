package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.bulk.BulkDtos.Report;
import edu.bingol.backend.admin.bulk.BulkDtos.Result;
import edu.bingol.backend.common.ApiException;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

/** Toplu islemlerin ortak yardimcilari: girdi dogrulama, sebep, maskeleme, rapor toplama. */
final class BulkSupport {

    static final String DONE = "DONE";
    static final String SKIPPED = "SKIPPED";
    static final String FAILED = "FAILED";

    private BulkSupport() {}

    /** Bos/null -> 400 BULK_EMPTY; tekrarlar atilir; sinir asilirsa 400 BULK_LIMIT_EXCEEDED (hicbir sey islenmez). */
    static <T> List<T> distinct(List<T> raw, int max) {
        LinkedHashSet<T> set = new LinkedHashSet<>();
        if (raw != null) {
            for (T t : raw) {
                if (t != null && !(t instanceof String s && s.isBlank())) {
                    set.add(t);
                }
            }
        }
        if (set.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "BULK_EMPTY", "İşlenecek kayıt seçilmedi.");
        }
        if (set.size() > max) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "BULK_LIMIT_EXCEEDED",
                    "Tek seferde en fazla " + max + " kayıt işlenebilir.", String.valueOf(max));
        }
        return new ArrayList<>(set);
    }

    /** Govdedeki sebep, yoksa X-Admin-Reason (AdminReasonFilter'in koydugu); en az 5 karakter, aksi 400 REASON_REQUIRED. */
    static String reason(String body) {
        String r = body != null && !body.isBlank() ? body : AuditContext.currentReason();
        if (r == null || r.strip().length() < BulkDtos.MIN_REASON) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                    "Bu işlem için gerekçe zorunludur (en az " + BulkDtos.MIN_REASON + " karakter).",
                    String.valueOf(BulkDtos.MIN_REASON));
        }
        return r.strip();
    }

    /** JWT yoneticisinin kimligi; Basic auth yoneticisinde kullanici kaydi yoktur (null). */
    static Long adminId() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? id : null;
    }

    /** Yonetici anahtari (hiz siniri): kimlik ya da ortak "basic". */
    static String actor() {
        Long id = adminId();
        return id != null ? String.valueOf(id) : "basic";
    }

    /** 226051015@bingol.edu.tr -> 226***@bingol.edu.tr (alan adi korunur). */
    static String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return "";
        }
        int at = email.indexOf('@');
        String local = at < 0 ? email : email.substring(0, at);
        String domain = at < 0 ? "" : email.substring(at);
        int keep = local.length() > 4 ? 3 : 1;
        return local.substring(0, Math.min(keep, local.length())) + "***" + domain;
    }

    /** "Ali Veli" -> "A*** V***". */
    static String maskName(String name) {
        if (name == null || name.isBlank()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (String w : name.strip().split("\s+")) {
            if (sb.length() > 0) {
                sb.append(' ');
            }
            sb.append(w.substring(0, w.offsetByCodePoints(0, 1))).append("***");
        }
        return sb.toString();
    }

    static String lower(Enum<?> e) {
        return e.name().toLowerCase(Locale.ROOT);
    }

    /** Sonuc toplayici. */
    static final class Tally {
        private final List<Result> results = new ArrayList<>();
        private int done;
        private int skipped;
        private int failed;

        void done(Object id) {
            results.add(new Result(String.valueOf(id), DONE, null));
            done++;
        }

        void skipped(Object id, String code) {
            results.add(new Result(String.valueOf(id), SKIPPED, code));
            skipped++;
        }

        void failed(Object id, String code) {
            results.add(new Result(String.valueOf(id), FAILED, code));
            failed++;
        }

        Report report() {
            return new Report(results.size(), done, skipped, failed, List.copyOf(results));
        }
    }
}
