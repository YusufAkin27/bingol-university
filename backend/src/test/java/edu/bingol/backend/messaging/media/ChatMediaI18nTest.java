package edu.bingol.backend.messaging.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

/** T8 hata kodlari uc dilde de cevrili olmali ve hicbir anahtar yinelenmemeli. */
class ChatMediaI18nTest {

    private static final List<String> CODES = List.of("ATTACHMENT_NOT_FOUND", "ATTACHMENT_INVALID",
            "ATTACHMENT_LIMIT", "ATTACHMENT_IN_USE", "CHAT_MEDIA_PENDING_LIMIT", "MEDIA_BLOCKED");

    @Test
    void everyCodeIsTranslatedAndNoKeyIsDuplicated() throws Exception {
        for (String file : List.of("messages.properties", "messages_en.properties", "messages_ar.properties")) {
            String text;
            try (InputStream in = getClass().getResourceAsStream("/i18n/" + file)) {
                text = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            }
            Set<String> seen = new HashSet<>();
            for (String line : text.split("\\R")) {
                if (line.isBlank() || line.startsWith("#") || !line.contains("=")) {
                    continue;
                }
                String key = line.substring(0, line.indexOf('='));
                assertTrue(seen.add(key), "yinelenen anahtar " + key + " (" + file + ")");
            }
            for (String c : CODES) {
                assertTrue(seen.contains("error." + c), file + " eksik: " + c);
            }
            assertFalse(text.contains("﻿"), "BOM olmamali");
        }
        assertEquals(6, CODES.size());
    }
}
