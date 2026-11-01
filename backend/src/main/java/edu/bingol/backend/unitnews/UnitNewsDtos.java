package edu.bingol.backend.unitnews;

import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;

/** Birim haberleri API kayitlari (sozlesme: docs/UNIT_NEWS_API.md). */
public final class UnitNewsDtos {

    private UnitNewsDtos() {}

    public record Attachment(String name, String url, String type) {}

    /** Kullanici listesi ogesi. unitName: bolum akisindan geldiyse bolum adi, genel akistan geldiyse null. */
    public record Item(long id, String title, String summary, String publishedDate, String sourceName, String unitName,
                       String url, List<Attachment> attachments) {}

    /** Kullanici detayi: Item alanlari + duz metin govde. */
    public record Detail(long id, String title, String summary, String publishedDate, String sourceName, String unitName,
                         String url, List<Attachment> attachments, String body) {}

    public record SourceView(String code, String name, String kind, String baseUrl, boolean enabled, boolean graduate,
                             List<String> facultyKeys, long departmentCount, long announcementCount,
                             Instant lastSuccessAt, Instant lastAttemptAt, String lastMessage, boolean maintenance) {}

    public record SourceUpdate(@NotNull Boolean enabled, List<String> facultyKeys) {}

    public record DepartmentView(String slug, String name, String nameKey, boolean hasOwnFeed) {}

    public record AdminItem(long id, String sourceCode, String sourceName, String unitName, String title, String url,
                            String publishedDate, int attachmentCount, boolean hidden) {}

    public record AdminPage(List<AdminItem> content, long totalElements, int totalPages, int number, int size) {}

    public record HiddenRequest(@NotNull Boolean hidden) {}

    public record SyncResult(int added, boolean started) {}
}
