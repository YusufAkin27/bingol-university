package edu.bingol.backend.media.transcode;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * ffmpeg/ffprobe sarmalayicisi: H.264 (main) + AAC, en fazla {@code maxHeight} (720p), ~1.5 Mbps,
 * {@code -movflags +faststart}. Girdi/cikti yollari uygulamanin kendi urettigi gecici dosyalardir; komutlar
 * argüman listesidir (kabuk yok) ve {@code -protocol_whitelist file} ile agsal/dolayli kaynak okuma kapatilir.
 */
@Component
public class VideoTranscoder {

    private static final Logger log = LoggerFactory.getLogger(VideoTranscoder.class);

    /** ffprobe ozeti. */
    public record Probe(long durationMs, int width, int height, boolean hasVideo) {
    }

    /** Donusum/probe hatasi (zaman asimi, sifir olmayan cikis, ffmpeg yok). */
    public static class TranscodeException extends Exception {
        private final boolean timeout;

        public TranscodeException(String message, boolean timeout) {
            super(message);
            this.timeout = timeout;
        }

        public boolean isTimeout() {
            return timeout;
        }
    }

    private final TranscodeProperties props;
    private final ProcessRunner runner;
    private final AtomicReference<Boolean> available = new AtomicReference<>();

    @Autowired
    public VideoTranscoder(TranscodeProperties props) {
        this(props, new ProcessRunner.Default());
    }

    public VideoTranscoder(TranscodeProperties props, ProcessRunner runner) {
        this.props = props;
        this.runner = runner;
    }

    /** Ozellik acik VE ffmpeg+ffprobe calisiyor mu (ilk bakista onbelleklenir; yoksa mevcut davranisa dusulur). */
    public boolean available() {
        if (!props.enabled()) {
            return false;
        }
        Boolean a = available.get();
        if (a == null) {
            a = works(props.ffmpegPath()) && works(props.ffprobePath());
            available.set(a);
            if (a) {
                log.info("ffmpeg bulundu: video donusturme etkin");
            } else {
                log.warn("ffmpeg/ffprobe bulunamadi ({}, {}): video donusturme KAPALI, videolar oldugu gibi saklanir",
                        props.ffmpegPath(), props.ffprobePath());
            }
        }
        return a;
    }

    private boolean works(String bin) {
        try {
            return runner.run(List.of(bin, "-version"), Duration.ofSeconds(10)).exitCode() == 0;
        } catch (IOException e) {
            return false;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        }
    }

    // ------------------------------------------------------------------ komutlar (saf; birim testli)

    /** Ses akisi yoksa da calisir ({@code -map 0:a:0?}); meta veri (GPS vb.) atilir. */
    static List<String> transcodeCommand(TranscodeProperties p, Path in, Path out) {
        List<String> c = new ArrayList<>();
        c.add(p.ffmpegPath());
        c.addAll(List.of("-hide_banner", "-nostdin", "-loglevel", "error", "-y"));
        c.addAll(List.of("-protocol_whitelist", "file", "-i", in.toString()));
        c.addAll(List.of("-t", String.valueOf(p.maxDurationSeconds())));
        c.addAll(List.of("-map", "0:v:0", "-map", "0:a:0?", "-sn", "-dn", "-map_metadata", "-1"));
        // Yukseklik: en fazla maxHeight, yukseltme yok, genislik cift sayi (H.264 icin)
        c.addAll(List.of("-vf", "scale=-2:'min(" + p.maxHeight() + ",ih)'"));
        c.addAll(List.of("-c:v", "libx264", "-profile:v", "main", "-pix_fmt", "yuv420p", "-preset", "veryfast",
                "-b:v", p.videoKbps() + "k", "-maxrate", (p.videoKbps() * 6 / 5) + "k",
                "-bufsize", (p.videoKbps() * 2) + "k", "-threads", String.valueOf(p.threadsPerJob())));
        c.addAll(List.of("-c:a", "aac", "-b:a", p.audioKbps() + "k", "-ac", "2"));
        c.addAll(List.of("-movflags", "+faststart", "-f", "mp4", out.toString()));
        return c;
    }

    /** Ilk anlamli kare: ilk ~60 kare icinden en temsilcisi ({@code thumbnail}), tek JPEG. */
    static List<String> posterCommand(TranscodeProperties p, Path in, Path outJpg) {
        List<String> c = new ArrayList<>();
        c.add(p.ffmpegPath());
        c.addAll(List.of("-hide_banner", "-nostdin", "-loglevel", "error", "-y"));
        c.addAll(List.of("-protocol_whitelist", "file", "-i", in.toString()));
        c.addAll(List.of("-map", "0:v:0", "-vf", "thumbnail=60,scale=-2:'min(" + p.maxHeight() + ",ih)'",
                "-frames:v", "1", "-an", "-q:v", "3", "-f", "image2", outJpg.toString()));
        return c;
    }

    static List<String> probeCommand(TranscodeProperties p, Path in) {
        return List.of(p.ffprobePath(), "-v", "error", "-protocol_whitelist", "file", "-select_streams", "v:0",
                "-show_entries", "stream=width,height:format=duration", "-of", "default=noprint_wrappers=1",
                in.toString());
    }

    // ------------------------------------------------------------------ calistirma

    public Probe probe(Path in) throws TranscodeException {
        ProcessRunner.Output o = exec(probeCommand(props, in), Duration.ofSeconds(30));
        return parseProbe(o.text());
    }

    /** ffprobe "anahtar=deger" ciktisi; stream yoksa hasVideo=false. */
    static Probe parseProbe(String text) {
        int w = 0;
        int h = 0;
        double dur = 0;
        for (String line : text.split("\\R")) {
            int i = line.indexOf('=');
            if (i <= 0) {
                continue;
            }
            String k = line.substring(0, i).trim();
            String v = line.substring(i + 1).trim();
            try {
                switch (k) {
                    case "width" -> w = Integer.parseInt(v);
                    case "height" -> h = Integer.parseInt(v);
                    case "duration" -> dur = Math.max(dur, Double.parseDouble(v));
                    default -> { }
                }
            } catch (NumberFormatException ignored) {
                // N/A
            }
        }
        return new Probe(Math.round(dur * 1000), w, h, w > 0 && h > 0);
    }

    public void transcode(Path in, Path out) throws TranscodeException {
        exec(transcodeCommand(props, in, out), Duration.ofSeconds(props.timeoutSeconds()));
        try {
            if (!Files.isRegularFile(out) || Files.size(out) == 0) {
                throw new TranscodeException("ffmpeg cikti uretmedi", false);
            }
        } catch (IOException e) {
            throw new TranscodeException("cikti okunamadi: " + e.getMessage(), false);
        }
    }

    public void poster(Path in, Path outJpg) throws TranscodeException {
        exec(posterCommand(props, in, outJpg), Duration.ofSeconds(Math.min(props.timeoutSeconds(), 60)));
        try {
            if (!Files.isRegularFile(outJpg) || Files.size(outJpg) == 0) {
                throw new TranscodeException("poster karesi uretilemedi", false);
            }
        } catch (IOException e) {
            throw new TranscodeException("poster okunamadi: " + e.getMessage(), false);
        }
    }

    private ProcessRunner.Output exec(List<String> cmd, Duration timeout) throws TranscodeException {
        ProcessRunner.Output o;
        try {
            o = runner.run(cmd, timeout);
        } catch (IOException e) {
            throw new TranscodeException("surec baslatilamadi: " + e.getMessage(), false);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new TranscodeException("kesildi", false);
        }
        if (o.timedOut()) {
            throw new TranscodeException("zaman asimi (" + timeout.toSeconds() + " sn)", true);
        }
        if (o.exitCode() != 0) {
            String t = o.text();
            throw new TranscodeException("cikis " + o.exitCode() + ": " + (t.length() > 300 ? t.substring(t.length() - 300) : t),
                    false);
        }
        return o;
    }
}
