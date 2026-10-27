package edu.bingol.backend.media.transcode;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.media.transcode.*`: sunucuda ffmpeg ile video yeniden kodlama.
 *
 * @param enabled         kapaliysa (ya da ffmpeg yoksa) video oldugu gibi saklanir; mevcut davranis
 * @param ffmpegPath      ffmpeg calistirilabilir yolu
 * @param ffprobePath     ffprobe yolu
 * @param workers         ayni anda en fazla bu kadar donusum (CPU korumasi)
 * @param threadsPerJob   ffmpeg/x264 is parcacigi sayisi (workers x threads <= CPU limiti)
 * @param timeoutSeconds  tek ffmpeg cagrisi icin sert zaman asimi (asilirsa surec oldurulur)
 * @param maxHeight       cikti yuksekligi ust siniri (yukseltme yapilmaz)
 * @param videoKbps       hedef video bit hizi
 * @param audioKbps       hedef ses bit hizi
 * @param maxDurationSeconds kabul edilen en uzun sure (ffprobe ile dogrulanir)
 * @param maxAttempts     basarisiz donusum yeniden deneme siniri; sonra FAILED ve orijinal kullanilir
 * @param pollMs          isleyici yoklama araligi
 * @param staleMinutes    PROCESSING'de bu kadar kalan is (cokmus isleyici) tekrar kuyruga alinir
 * @param tempDir         gecici dosya dizini; bos = sistem gecici dizini
 * @param posterEnabled   poster gonderilmediyse ffmpeg ile kare uret
 * @param encryptExisting acilista/yoklamada eski DUZ gonderi videolarini sifrele (gocmen isi)
 * @param legacyBatch     her yoklamada sifrelenecek eski video sayisi
 * @param resealKeyId     doluysa, DEK'i bu ana anahtarla sarili videolar yeni aktif anahtarla yeniden yazilir (sizinti/rotasyon)
 */
@ConfigurationProperties("app.media.transcode")
public record TranscodeProperties(
        @DefaultValue("true") boolean enabled,
        @DefaultValue("ffmpeg") String ffmpegPath,
        @DefaultValue("ffprobe") String ffprobePath,
        @DefaultValue("2") int workers,
        @DefaultValue("1") int threadsPerJob,
        @DefaultValue("300") int timeoutSeconds,
        @DefaultValue("720") int maxHeight,
        @DefaultValue("1500") int videoKbps,
        @DefaultValue("96") int audioKbps,
        @DefaultValue("120") int maxDurationSeconds,
        @DefaultValue("3") int maxAttempts,
        @DefaultValue("5000") long pollMs,
        @DefaultValue("30") int staleMinutes,
        @DefaultValue("") String tempDir,
        @DefaultValue("true") boolean posterEnabled,
        @DefaultValue("false") boolean encryptExisting,
        @DefaultValue("5") int legacyBatch,
        @DefaultValue("") String resealKeyId) {

    public TranscodeProperties {
        workers = Math.max(1, Math.min(workers, 8));
        threadsPerJob = Math.max(1, Math.min(threadsPerJob, 8));
        timeoutSeconds = Math.max(10, timeoutSeconds);
        maxHeight = maxHeight < 144 ? 720 : maxHeight;
        videoKbps = Math.max(200, videoKbps);
        audioKbps = Math.max(32, audioKbps);
        maxAttempts = Math.max(1, maxAttempts);
        legacyBatch = Math.max(1, legacyBatch);
    }
}
