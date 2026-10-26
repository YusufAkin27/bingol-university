package edu.bingol.backend.media;

import edu.bingol.backend.common.ApiException;
import java.io.IOException;
import java.io.InputStream;
import java.util.Locale;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.web.multipart.MultipartFile;

/** Yuklenen dosyanin bildirilen ozelliklerini (Content-Type, uzanti, boyut) denetler ve baytlarini sinirli okur. */
public final class MediaUploads {

    private static final Set<String> DECLARED_OK = Set.of(
            "image/jpeg", "image/png", "image/webp", "application/octet-stream");
    private static final Set<String> EXT_OK = Set.of("jpg", "jpeg", "png", "webp");

    private MediaUploads() {
    }

    /**
     * Bildirilen Content-Type ve uzanti jpeg/png/webp disindaysa (ornek: image/svg+xml, text/html, .gif) reddeder;
     * asil karar yine sihirli baytlardadir ({@link ImageProcessor}). Boyut asilirsa 413.
     */
    public static byte[] read(MultipartFile file, long maxBytes) {
        if (file == null || file.isEmpty()) {
            throw invalid();
        }
        String type = file.getContentType();
        if (type != null && !DECLARED_OK.contains(type.toLowerCase(Locale.ROOT).split(";")[0].trim())) {
            throw invalid();
        }
        String name = file.getOriginalFilename();
        if (name != null && name.lastIndexOf('.') >= 0) {
            String ext = name.substring(name.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
            if (!EXT_OK.contains(ext)) {
                throw invalid();
            }
        }
        if (file.getSize() > maxBytes) {
            throw tooLarge(maxBytes);
        }
        // getSize() istemciye guvenilir bir deger sayilmaz: okurken de sinirla
        try (InputStream in = file.getInputStream()) {
            byte[] data = in.readNBytes((int) maxBytes + 1);
            if (data.length > maxBytes) {
                throw tooLarge(maxBytes);
            }
            return data;
        } catch (IOException e) {
            throw invalid();
        }
    }

    static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_FILE", "Geçersiz dosya türü.");
    }

    static ApiException tooLarge(long maxBytes) {
        long mb = Math.max(1, maxBytes / 1024 / 1024);
        return new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "FILE_TOO_LARGE",
                "Dosya en fazla " + mb + " MB olabilir.", String.valueOf(mb));
    }
}
