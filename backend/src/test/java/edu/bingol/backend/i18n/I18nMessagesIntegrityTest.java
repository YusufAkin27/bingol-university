package edu.bingol.backend.i18n;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.mail.MailRenderer;
import edu.bingol.backend.mail.MailTemplate;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.MessageFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

import edu.bingol.backend.i18n.Lang;

/** i18n kaynaklarinin butunlugu: tr/en/ar anahtar + yer tutucu esitligi ve MessageFormat ayristirmasi. */
class I18nMessagesIntegrityTest {

    private static final Path DIR = Paths.get("src/main/resources/i18n");
    private static final Pattern PH = Pattern.compile("\\{(\\d+)[^}]*}");

    private static Properties load(Path p) throws IOException {
        Properties props = new Properties();
        try (Reader r = new InputStreamReader(Files.newInputStream(p), StandardCharsets.UTF_8)) {
            props.load(r);
        }
        return props;
    }

    /** {{ad}} sablon yer tutuculu mail metinleri MessageFormat degildir. */
    private static boolean isMessageFormatKey(String key) {
        return !key.startsWith("mail.tpl.") && !key.startsWith("mail.unsub.");
    }

    private static TreeSet<String> placeholders(String v) {
        TreeSet<String> s = new TreeSet<>();
        Matcher m = PH.matcher(v);
        while (m.find()) s.add(m.group(1));
        return s;
    }

    private static List<Path> baseFiles() throws IOException {
        try (Stream<Path> s = Files.list(DIR)) {
            return s.filter(p -> p.getFileName().toString().endsWith(".properties"))
                    .filter(p -> !p.getFileName().toString().matches(".*_(en|ar)\\.properties"))
                    .sorted().toList();
        }
    }

    @Test
    void allLanguagesHaveSameKeysAndPlaceholders() throws IOException {
        List<String> problems = new ArrayList<>();
        for (Path tr : baseFiles()) {
            String base = tr.getFileName().toString().replace(".properties", "");
            Properties t = load(tr);
            for (String lg : new String[] {"en", "ar"}) {
                Path p = DIR.resolve(base + "_" + lg + ".properties");
                if (!Files.exists(p)) { problems.add("missing file " + p.getFileName()); continue; }
                Properties l = load(p);
                for (String k : t.stringPropertyNames()) {
                    String v = l.getProperty(k);
                    if (v == null) problems.add(lg + " missing " + k);
                    else if (v.isBlank()) problems.add(lg + " empty " + k);
                    else if (isMessageFormatKey(k) && !placeholders(t.getProperty(k)).equals(placeholders(v)))
                        problems.add(lg + " placeholder mismatch " + k);
                }
                for (String k : l.stringPropertyNames())
                    if (!t.containsKey(k)) problems.add(lg + " extra " + k);
            }
        }
        assertThat(problems).isEmpty();
    }

    /**
     * Dosyalar arasi cift anahtar yok: spring.messages.basename sirasi ilk dosyayi kazandirir; ikinci
     * tanim sessizce golgelenir (ornek: POST_NOT_FOUND hem messages hem post'ta, metinler ayri).
     */
    @Test
    void noDuplicateKeysAcrossFiles() throws IOException {
        List<String> problems = new ArrayList<>();
        for (String suffix : new String[] {"", "_en", "_ar"}) {
            Map<String, String> owner = new java.util.HashMap<>();
            for (Path tr : baseFiles()) {
                String base = tr.getFileName().toString().replace(".properties", "");
                Path p = DIR.resolve(base + suffix + ".properties");
                if (!Files.exists(p)) continue;
                for (String k : load(p).stringPropertyNames()) {
                    String prev = owner.putIfAbsent(k, p.getFileName().toString());
                    if (prev != null) problems.add(k + " -> " + prev + " ve " + p.getFileName());
                }
            }
        }
        assertThat(problems).as("cift anahtar (basename golgelemesi)").isEmpty();
    }

    @Test
    void everyMessageParsesAsMessageFormat() throws IOException {
        List<String> problems = new ArrayList<>();
        try (Stream<Path> s = Files.list(DIR)) {
            for (Path p : s.filter(x -> x.toString().endsWith(".properties")).sorted().toList()) {
                Properties props = load(p);
                for (String k : props.stringPropertyNames()) {
                    if (!isMessageFormatKey(k)) continue;
                    String v = props.getProperty(k);
                    try {
                        new MessageFormat(v);
                    } catch (IllegalArgumentException e) {
                        problems.add(p.getFileName() + ":" + k + " -> " + e.getMessage());
                    }
                    // Tek tirnak, arguemanli metinde sonraki yer tutucuyu yutar.
                    if (v.indexOf('\'') >= 0 && !placeholders(v).isEmpty())
                        problems.add(p.getFileName() + ":" + k + " apostrof + yer tutucu");
                }
            }
        }
        assertThat(problems).isEmpty();
    }

    @Test
    void filesHaveNoBom() throws IOException {
        try (Stream<Path> s = Files.list(DIR)) {
            for (Path p : s.filter(x -> x.toString().endsWith(".properties")).toList()) {
                byte[] b = Files.readAllBytes(p);
                boolean bom = b.length >= 3 && (b[0] & 0xFF) == 0xEF && (b[1] & 0xFF) == 0xBB && (b[2] & 0xFF) == 0xBF;
                assertThat(bom).as("BOM: " + p.getFileName()).isFalse();
            }
        }
    }

    @Test
    void arabicMailIsRightToLeftOnBodyAndContent() {
        MailRenderer.Rendered r = new MailRenderer().render(MailTemplate.VERIFICATION_CODE, Lang.AR,
                Map.of("code", "123456", "minutes", "10"));
        assertThat(r.html()).contains("<html lang=\"ar\" dir=\"rtl\">").contains("<body class=\"bg\" dir=\"rtl\"");
        assertThat(r.html()).contains("class=\"txt\" dir=\"rtl\"").contains("dir=\"ltr\"");
    }
}
