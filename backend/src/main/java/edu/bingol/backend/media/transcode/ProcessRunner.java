package edu.bingol.backend.media.transcode;

import java.io.IOException;
import java.io.InputStream;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * Dis surec calistirma soyutlamasi (testte sahtesi verilir). Komut her zaman ARGUMAN LISTESIdir; kabuk
 * kullanilmaz, bu yuzden kabuk enjeksiyonu mumkun degildir.
 */
public interface ProcessRunner {

    /** @param text birlesik stdout+stderr (en fazla ~64 KB, sonu kirpilir) */
    record Output(int exitCode, String text, boolean timedOut) {
    }

    Output run(List<String> command, Duration timeout) throws IOException, InterruptedException;

    /** Varsayilan: {@link ProcessBuilder}; zaman asiminda surec (ve alt surecleri) zorla sonlandirilir. */
    class Default implements ProcessRunner {

        private static final int MAX_TEXT = 64 * 1024;

        @Override
        public Output run(List<String> command, Duration timeout) throws IOException, InterruptedException {
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.redirectErrorStream(true);
            pb.redirectInput(ProcessBuilder.Redirect.from(nullFile()));
            Process p = pb.start();
            StringBuilder sb = new StringBuilder();
            Thread reader = new Thread(() -> drain(p.getInputStream(), sb), "proc-out");
            reader.setDaemon(true);
            reader.start();
            boolean done = p.waitFor(timeout.toMillis(), TimeUnit.MILLISECONDS);
            if (!done) {
                p.descendants().forEach(ProcessHandle::destroyForcibly);
                p.destroyForcibly();
                p.waitFor(5, TimeUnit.SECONDS);
                reader.join(2000);
                return new Output(-1, tail(sb), true);
            }
            reader.join(2000);
            return new Output(p.exitValue(), tail(sb), false);
        }

        private static java.io.File nullFile() {
            return new java.io.File(System.getProperty("os.name", "").toLowerCase().contains("win") ? "NUL" : "/dev/null");
        }

        private static void drain(InputStream in, StringBuilder sb) {
            byte[] buf = new byte[4096];
            try {
                int n;
                while ((n = in.read(buf)) > 0) {
                    synchronized (sb) {
                        if (sb.length() < MAX_TEXT * 2) {
                            sb.append(new String(buf, 0, n, java.nio.charset.StandardCharsets.UTF_8));
                        }
                    }
                }
            } catch (IOException ignored) {
                // surec kapandi
            }
        }

        private static String tail(StringBuilder sb) {
            synchronized (sb) {
                return sb.length() <= MAX_TEXT ? sb.toString() : sb.substring(sb.length() - MAX_TEXT);
            }
        }
    }
}
