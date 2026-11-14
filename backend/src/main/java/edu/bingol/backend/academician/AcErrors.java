package edu.bingol.backend.academician;

import edu.bingol.backend.common.ApiException;
import org.springframework.http.HttpStatus;

/** Akademisyen alani hata kodlari tek yerde (metinler i18n/academician*.properties). */
final class AcErrors {

    private AcErrors() {}

    static ApiException notApproved() {
        return new ApiException(HttpStatus.FORBIDDEN, "ACADEMICIAN_NOT_APPROVED", "Akademisyen hesabınız onaylı değil.");
    }

    static ApiException courseNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "AC_COURSE_NOT_FOUND", "Ders bulunamadı.");
    }

    static ApiException sessionNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "AC_SESSION_NOT_FOUND", "Yoklama oturumu bulunamadı.");
    }

    static ApiException noticeNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "AC_NOTICE_NOT_FOUND", "Duyuru bulunamadı.");
    }

    static ApiException invalid(String field) {
        return new ApiException(HttpStatus.BAD_REQUEST, "AC_FIELD_INVALID", field + " geçersiz veya eksik.", field);
    }

    static ApiException codeInvalid() {
        return new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ATTENDANCE_CODE_INVALID",
                "QR kodu geçersiz veya süresi dolmuş.");
    }

    static ApiException scanRequestNotFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "AC_SCAN_REQUEST_NOT_FOUND", "Bekleyen yoklama isteği bulunamadı.");
    }

    static ApiException revoked() {
        return new ApiException(HttpStatus.FORBIDDEN, "ATTENDANCE_REVOKED",
                "Bu ders için yoklamanız öğretim elemanı tarafından kaldırıldı.");
    }

    static ApiException notEnrolled() {
        return new ApiException(HttpStatus.FORBIDDEN, "ATTENDANCE_NOT_ENROLLED", "Bu derse kayıtlı değilsiniz.");
    }
}
