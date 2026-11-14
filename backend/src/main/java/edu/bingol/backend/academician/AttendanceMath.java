package edu.bingol.backend.academician;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * "Bu ogrenci icin hangi oturumlar sayilir, kac devamsizligi var" hesabinin TEK yeri: matris, CSV, Derslerim, otomatik
 * uyari hep bunu kullanir. Bir oturum bir ogrenci icin SAYILIR ancak: canli degilse (acik ve suresi dolmamis oturumdaki
 * "yok" gecicidir), hoca "sayilmasin" demediyse (counted), ogrenci o oturumdan once derse eklenmediyse degilse (opened_at &gt;=
 * added_at; ogrencinin o oturumda kaydi varsa yine sayilir) ve ogrenci o oturumda izinli degilse. Sayilan oturumlarda
 * devamsizlik = kaydi olmayan ya da hocanin kaldirdigi.
 */
final class AttendanceMath {

    /** Oturumun hesap icin gereken yuzu. */
    record Sess(Long id, Instant openedAt, boolean live, boolean counted) {}

    /** (oturum, ogrenci) yoklama satiri. */
    record Rec(AcAttendance.Method method, boolean revoked, boolean excused) {}

    /**
     * marks: oturum kimligi (metin) -> PRESENT_QR | PRESENT_MANUAL | REVOKED | EXCUSED | NOT_ENROLLED_YET | ABSENT.
     * sessionCount/absent/present/excused yalniz SAYILAN oturumlar uzerinden.
     */
    record Result(Map<String, String> marks, int sessionCount, int present, int absent, int excused, int level,
                  Integer allowedAbsences) {
        boolean atRisk() {
            return level == 1;
        }

        boolean overLimit() {
            return level == 2;
        }
    }

    private AttendanceMath() {}

    static Result compute(List<Sess> sessions, Instant addedAt, Map<Long, Rec> recs, AcCourse.LimitType type, Integer limitValue,
                          Integer planned, int minPercentSessions) {
        Map<String, String> marks = new LinkedHashMap<>();
        int total = 0;
        int present = 0;
        int absent = 0;
        int excused = 0;
        for (Sess s : sessions) {
            Rec r = recs.get(s.id());
            String mark;
            if (r != null) {
                mark = r.revoked() ? "REVOKED" : r.excused() ? "EXCUSED" : r.method() == AcAttendance.Method.QR ? "PRESENT_QR" : "PRESENT_MANUAL";
            } else {
                mark = addedAt != null && s.openedAt().isBefore(addedAt) ? "NOT_ENROLLED_YET" : "ABSENT";
            }
            marks.put(String.valueOf(s.id()), mark);
            if (s.live() || !s.counted() || mark.equals("NOT_ENROLLED_YET")) {
                continue;
            }
            if (mark.equals("EXCUSED")) {
                excused++;
                continue;
            }
            total++;
            if (mark.startsWith("PRESENT")) {
                present++;
            } else {
                absent++;
            }
        }
        int level = AbsencePolicy.level(type, limitValue, planned, total, absent, minPercentSessions);
        return new Result(marks, total, present, absent, excused, level, AbsencePolicy.allowedAbsences(type, limitValue, planned));
    }
}
