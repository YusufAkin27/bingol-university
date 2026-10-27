package edu.bingol.backend.media.transcode;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** ffmpeg komutlari (saf), ffprobe ayristirma, zaman asimi ve "ffmpeg yok" davranisi (surec calistirilmaz). */
class VideoTranscoderTest {

    static TranscodeProperties props(boolean enabled) {
        return new TranscodeProperties(enabled, "ffmpeg", "ffprobe", 2, 1, 120, 720, 1500, 96, 90, 3, 5000, 30, "",
                true, false, 5, "");
    }

    @TempDir
    Path dir;

    @Test
    void transcodeCommandIsSafeArgumentListWithExpectedEncodingSettings() {
        Path in = dir.resolve("in put; rm -rf x.mp4"); // bosluk/noktalivirgul: tek arguman kalir, kabuk yok
        Path out = dir.resolve("out.mp4");
        List<String> c = VideoTranscoder.transcodeCommand(props(true), in, out);
        assertEquals("ffmpeg", c.get(0));
        assertTrue(c.contains(in.toString()), "girdi tek arguman");
        assertEquals(out.toString(), c.get(c.size() - 1));
        assertTrue(c.indexOf("-protocol_whitelist") < c.indexOf("-i"), "whitelist -i'den once");
        assertEquals("file", c.get(c.indexOf("-protocol_whitelist") + 1));
        assertEquals("libx264", c.get(c.indexOf("-c:v") + 1));
        assertEquals("main", c.get(c.indexOf("-profile:v") + 1));
        assertEquals("aac", c.get(c.indexOf("-c:a") + 1));
        assertEquals("1500k", c.get(c.indexOf("-b:v") + 1));
        assertEquals("1800k", c.get(c.indexOf("-maxrate") + 1));
        assertEquals("+faststart", c.get(c.indexOf("-movflags") + 1));
        assertEquals("90", c.get(c.indexOf("-t") + 1), "sure siniri");
        assertEquals("-1", c.get(c.indexOf("-map_metadata") + 1), "meta veri (GPS vb.) atilir");
        String vf = c.get(c.indexOf("-vf") + 1);
        assertTrue(vf.contains("min(720,ih)") && vf.startsWith("scale=-2:"), vf);
        assertTrue(c.contains("0:a:0?"), "ses akisi yoksa da calisir");
        assertFalse(c.contains("sh") || c.contains("-c") && c.get(0).equals("sh"));
        assertTrue(c.stream().noneMatch(a -> a.startsWith("http") || a.startsWith("concat")));
    }

    @Test
    void posterAndProbeCommands() {
        List<String> p = VideoTranscoder.posterCommand(props(true), dir.resolve("a.mp4"), dir.resolve("p.jpg"));
        assertTrue(p.contains("-frames:v") && p.contains("-an"));
        assertTrue(p.get(p.indexOf("-vf") + 1).startsWith("thumbnail="));
        List<String> pr = VideoTranscoder.probeCommand(props(true), dir.resolve("a.mp4"));
        assertEquals("ffprobe", pr.get(0));
        assertTrue(pr.contains("-protocol_whitelist"));
    }

    @Test
    void parseProbeReadsKeyValueLines() {
        var p = VideoTranscoder.parseProbe("width=1280\nheight=720\nduration=12.5\n");
        assertTrue(p.hasVideo());
        assertEquals(1280, p.width());
        assertEquals(720, p.height());
        assertEquals(12500, p.durationMs());
        assertFalse(VideoTranscoder.parseProbe("duration=3.0\n").hasVideo(), "video akisi yoksa");
        assertFalse(VideoTranscoder.parseProbe("garbage\nwidth=N/A\n").hasVideo());
    }

    @Test
    void unavailableWhenDisabledOrBinaryMissing() {
        List<List<String>> calls = new ArrayList<>();
        ProcessRunner throwing = (cmd, t) -> {
            calls.add(cmd);
            throw new IOException("ffmpeg: not found");
        };
        assertFalse(new VideoTranscoder(props(false), throwing).available());
        assertTrue(calls.isEmpty(), "kapaliysa surec bile baslatilmaz");
        VideoTranscoder missing = new VideoTranscoder(props(true), throwing);
        assertFalse(missing.available());
        assertFalse(missing.available());
        assertEquals(1, calls.size(), "sonuc onbellekte");
        ProcessRunner ok = (cmd, t) -> new ProcessRunner.Output(0, "ffmpeg version", false);
        assertTrue(new VideoTranscoder(props(true), ok).available());
        ProcessRunner bad = (cmd, t) -> new ProcessRunner.Output(127, "", false);
        assertFalse(new VideoTranscoder(props(true), bad).available());
    }

    @Test
    void timeoutAndNonZeroExitSurfaceAsTranscodeException() {
        ProcessRunner slow = (cmd, t) -> new ProcessRunner.Output(-1, "kirpildi", true);
        var ex = assertThrows(VideoTranscoder.TranscodeException.class,
                () -> new VideoTranscoder(props(true), slow).transcode(dir.resolve("a"), dir.resolve("b")));
        assertTrue(ex.isTimeout());

        ProcessRunner fail = (cmd, t) -> new ProcessRunner.Output(1, "Invalid data found", false);
        var ex2 = assertThrows(VideoTranscoder.TranscodeException.class,
                () -> new VideoTranscoder(props(true), fail).probe(dir.resolve("a")));
        assertFalse(ex2.isTimeout());
        assertTrue(ex2.getMessage().contains("Invalid data"));
    }

    @Test
    void emptyOutputIsAFailure() throws Exception {
        ProcessRunner noop = (cmd, t) -> new ProcessRunner.Output(0, "", false);
        assertThrows(VideoTranscoder.TranscodeException.class,
                () -> new VideoTranscoder(props(true), noop).transcode(dir.resolve("a"), dir.resolve("never.mp4")));
        Path empty = dir.resolve("empty.mp4");
        Files.write(empty, new byte[0]);
        assertThrows(VideoTranscoder.TranscodeException.class,
                () -> new VideoTranscoder(props(true), noop).transcode(dir.resolve("a"), empty));
    }

    @Test
    void realProcessRunnerKillsOnTimeoutAndCapturesOutput() throws Exception {
        // Java'nin kendisi: her ortamda vardir
        String java = Path.of(System.getProperty("java.home"), "bin", "java").toString();
        ProcessRunner.Output o = new ProcessRunner.Default().run(List.of(java, "-version"), Duration.ofSeconds(30));
        assertEquals(0, o.exitCode());
        assertFalse(o.timedOut());
        assertTrue(o.text().toLowerCase().contains("version"));

        Path src = dir.resolve("Sleep.java");
        Files.writeString(src, "public class Sleep { public static void main(String[] a) throws Exception { Thread.sleep(60000); } }");
        long t0 = System.currentTimeMillis();
        ProcessRunner.Output slow = new ProcessRunner.Default().run(List.of(java, src.toString()), Duration.ofSeconds(3));
        assertTrue(slow.timedOut(), "zaman asimi");
        assertTrue(System.currentTimeMillis() - t0 < 30_000, "surec oldurulup donuldu");
    }

    @Test
    void propertiesAreClamped() {
        var p = new TranscodeProperties(true, "ffmpeg", "ffprobe", 99, 0, 1, 1, 1, 1, 1, 0, 1, 1, "", true, false, 0, "");
        assertEquals(8, p.workers());
        assertEquals(1, p.threadsPerJob());
        assertEquals(10, p.timeoutSeconds());
        assertEquals(720, p.maxHeight());
        assertEquals(1, p.maxAttempts());
    }
}
