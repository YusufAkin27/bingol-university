package edu.bingol.backend.academic;

import java.util.List;

/** Resmi ders programi (yonetici Excel yukler) icin istek/yanit kayitlari. */
public final class OfficialTimetableDtos {

    private OfficialTimetableDtos() {}

    /** Excel satiri numarasi (1 tabanli, basliga gore) + aciklama. */
    public record Issue(int row, String message) {}

    /** Bir birim + program icin ozet (yukleme onizlemesi ve yonetici listesi). */
    public record ProgramSummary(String unit, String program, String department, String faculty, boolean catalogMatched,
                                 List<String> grades, int sessions, boolean published) {}

    public record ImportResult(boolean dryRun, String term, int rows, int programs, int inserted, int replacedPrograms,
                               Long batchId, List<ProgramSummary> items, List<Issue> errors, List<Issue> warnings) {}

    public record EntryView(Long id, String term, String unit, String faculty, String department, String program,
                            String grade, String group, int day, String start, String end, String code, String name,
                            String instructor, String room, String note, String sourceUrl, boolean published) {}

    public record TermView(String term, int sessions, int programs) {}

    public record AdminProgramsView(List<TermView> terms, String term, List<ProgramSummary> items) {}

    public record PublishRequest(String term, String unit, String program, Boolean published) {}

    /** Kullanici yaniti: profilindeki bolum/sinif icin yayinda olan resmi program. */
    public record OfficialView(String term, List<EntryView> items, List<String> units, boolean profileComplete) {}

    /**
     * Resmi programin kisisel programa kopyalanma durumu. available: profilin bolum + sinifi icin yayinda program var;
     * applied: bu donem icin tohum isareti var (otomatik ya da elle kopyalandi); units: eslesen birimler (birden cok
     * ise istemci birim sectirir).
     */
    public record OfficialStatus(boolean available, boolean applied, String term, List<String> units) {}

    /** unit: birden cok birim varken zorunlu; replace: mevcut kisisel dersleri silip yeniden kopyala; force: cakismayi yok say. */
    public record ApplyRequest(String unit, Boolean replace, Boolean force) {}
}
