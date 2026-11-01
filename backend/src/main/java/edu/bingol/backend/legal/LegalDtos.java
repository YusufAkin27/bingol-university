package edu.bingol.backend.legal;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class LegalDtos {

    private LegalDtos() {}

    /** Liste gorunumu. lang = sunulan metnin dili (istenen dilde yoksa tr). */
    public record LegalSummary(LegalType type, int version, String title, String lang, String publishedAt) {
        static LegalSummary of(LegalDocument d) {
            return new LegalSummary(d.getType(), d.getVersion(), d.getTitle(), d.getLang(), d.getPublishedAt().toString());
        }

        static LegalSummary of(DocumentRepository.DocHead d) {
            return new LegalSummary(d.getType(), d.getVersion(), d.getTitle(), d.getLang(), d.getPublishedAt().toString());
        }
    }

    /** Surum listesi satiri (metinsiz) ve bekleyen onay hesabi icin onbellekli baslik. */
    public record BaseDoc(LegalType type, int version, boolean requireReaccept, String title) {
        static BaseDoc of(DocumentRepository.DocHead h) {
            return new BaseDoc(h.getType(), h.getVersion(), h.isRequireReaccept(), h.getTitle());
        }
    }

    public record LegalContent(LegalType type, int version, String title, String content, String lang,
                               String publishedAt) {
        static LegalContent of(LegalDocument d) {
            return new LegalContent(d.getType(), d.getVersion(), d.getTitle(), d.getContent(), d.getLang(),
                    d.getPublishedAt().toString());
        }
    }

    /** Kullanicinin henuz onaylamadigi guncel belge. */
    public record PendingConsent(LegalType type, int version, String title) {}

    public record ConsentItem(@NotNull LegalType type, @NotNull Integer version) {}

    public record AcceptRequest(@NotEmpty @Size(max = 10) @Valid List<ConsentItem> items) {}

    public record AcceptanceView(LegalType type, int version, String acceptedAt) {}

    public record Translation(@NotBlank @Size(max = 200) String title, @NotBlank @Size(max = 100000) String content) {}

    /** tr zorunlu; en/ar verilmezse o dilde tr metin sunulur. requireReaccept varsayilan true. */
    public record PublishRequest(@NotNull @Valid Translation tr, @Valid Translation en, @Valid Translation ar,
                                 Boolean requireReaccept) {}
}
