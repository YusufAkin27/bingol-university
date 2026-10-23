package edu.bingol.backend.common.storage;

import java.util.Set;
import org.springframework.web.multipart.MultipartFile;

/** Yuklenen dosyalar icin soyutlama; simdilik yerel disk, ileride S3/MinIO ile degistirilebilir. */
public interface FileStorage {

    /**
     * Dosyayi dogrular (boyut, icerik turu) ve kaydeder.
     * @return herkese acik goreli URL, ornek: /files/avatars/ab12.jpg
     */
    String save(String folder, MultipartFile file, Set<String> allowedContentTypes, long maxBytes);

    void delete(String url);
}
