package edu.bingol.backend.unitnews;

import java.util.List;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/** Ekler kolonunun (TEXT) JSON okuma/yazmasi; bozuk veri bos liste olur. */
final class UnitAttachmentsJson {

    private static final TypeReference<List<UnitNewsDtos.Attachment>> LIST = new TypeReference<>() { };
    private final JsonMapper mapper = JsonMapper.builder().build();

    String write(List<UnitSiteScraper.Attachment> files) {
        return mapper.writeValueAsString(files.stream()
                .map(f -> new UnitNewsDtos.Attachment(f.name(), f.url(), f.type())).toList());
    }

    List<UnitNewsDtos.Attachment> read(String raw) {
        if (raw == null || raw.isBlank()) {
            return List.of();
        }
        try {
            return mapper.readValue(raw, LIST);
        } catch (RuntimeException e) {
            return List.of();
        }
    }
}
