package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.TreeSet;
import org.junit.jupiter.api.Test;

/** Bildirim sablonlarinin ve hata mesajlarinin 3 dilde (tr/en/ar) eksiksiz oldugunu denetler. */
class NotificationTemplatesTest {

    private static Properties load(String name) throws IOException {
        Properties p = new Properties();
        try (InputStream in = NotificationTemplatesTest.class.getResourceAsStream("/i18n/" + name);
             InputStreamReader r = new InputStreamReader(in, StandardCharsets.UTF_8)) {
            p.load(r);
        }
        return p;
    }

    private static final String[] FILES = {"messages.properties", "messages_en.properties", "messages_ar.properties"};

    @Test
    void everyRegisteredTemplateHasTitleAndBodyInAllLanguages() throws IOException {
        List<String> missing = new ArrayList<>();
        for (String f : FILES) {
            Properties p = load(f);
            for (NotificationTemplates.Template t : NotificationTemplates.all()) {
                for (String suffix : List.of(".title", ".body")) {
                    String v = p.getProperty(t.key() + suffix);
                    if (v == null || v.isBlank()) {
                        missing.add(f + ": " + t.key() + suffix);
                    }
                }
            }
        }
        assertTrue(missing.isEmpty(), "Eksik sablon anahtarlari: " + missing);
    }

    @Test
    void notifAndErrorKeysAreIdenticalAcrossLanguages() throws IOException {
        Properties tr = load(FILES[0]);
        List<String> problems = new ArrayList<>();
        for (int i = 1; i < FILES.length; i++) {
            Properties other = load(FILES[i]);
            for (String k : new TreeSet<>(tr.stringPropertyNames())) {
                if ((k.startsWith("notif.") || k.startsWith("error.")) && other.getProperty(k) == null) {
                    problems.add(FILES[i] + " eksik: " + k);
                }
            }
            for (String k : new TreeSet<>(other.stringPropertyNames())) {
                if ((k.startsWith("notif.") || k.startsWith("error.")) && tr.getProperty(k) == null) {
                    problems.add(FILES[i] + " fazla (tr'de yok): " + k);
                }
            }
        }
        assertTrue(problems.isEmpty(), problems.toString());
    }

    @Test
    void everyTitleKeyHasBodyOrIsIntentionallyTitleOnly() throws IOException {
        // sendLocalized(titleKey, null, bodyText) kullanan bilinen yalniz-baslik anahtarlari
        List<String> titleOnly = List.of("notif.account.reactivated", "notif.feedback.updated", "notif.ticket.answered",
                "notif.ticket.closed", "notif.report.warn");
        Properties tr = load(FILES[0]);
        List<String> problems = new ArrayList<>();
        for (String k : tr.stringPropertyNames()) {
            if (k.startsWith("notif.") && k.endsWith(".title")) {
                String base = k.substring(0, k.length() - ".title".length());
                if (tr.getProperty(base + ".body") == null && !titleOnly.contains(base)) {
                    problems.add(base);
                }
            }
        }
        assertTrue(problems.isEmpty(), "Govdesi olmayan sablonlar: " + problems);
    }

    @Test
    void newSubtypesAreReachableAndConsistent() {
        for (NotificationSubtype s : NotificationSubtype.values()) {
            assertFalse(s.parent() == NotificationType.SYSTEM, "SYSTEM alt tur alamaz: " + s);
        }
        assertThrows(IllegalArgumentException.class,
                () -> NotificationTemplates.register("x.bad", NotificationType.NEWS, NotificationSubtype.EVENT_UPDATE));
    }
}
