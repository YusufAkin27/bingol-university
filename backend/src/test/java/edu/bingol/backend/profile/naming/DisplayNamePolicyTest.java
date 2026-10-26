package edu.bingol.backend.profile.naming;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import org.junit.jupiter.api.Test;

class DisplayNamePolicyTest {

    private static String ok(String s) {
        return DisplayNamePolicy.normalize(s, false);
    }

    private static void rejects(String s, String code) {
        ApiException e = assertThrows(ApiException.class, () -> DisplayNamePolicy.normalize(s, false), s);
        assertEquals(code, e.code());
    }

    @Test
    void acceptsRealNamesInThreeScripts() {
        assertEquals("Ayşe Yılmaz", ok("Ayşe Yılmaz"));
        assertEquals("İsmail Çağlar-Öztürk", ok("İsmail Çağlar-Öztürk"));
        assertEquals("محمد أحمد", ok("محمد أحمد"));
        assertEquals("John O'Neil Jr.", ok("John O'Neil Jr."));
    }

    @Test
    void collapsesWhitespaceAndTrims() {
        assertEquals("Ali Veli", ok("  Ali    Veli  "));
    }

    @Test
    void rejectsControlBidiAndZeroWidth() {
        rejects("Ali\u0000Veli", "INVALID_DISPLAY_NAME");
        rejects("Ali\nVeli", "INVALID_DISPLAY_NAME");
        rejects("Ali\tVeli", "INVALID_DISPLAY_NAME");
        rejects("Ali‮Veli", "INVALID_DISPLAY_NAME");
        rejects("Ali​Veli", "INVALID_DISPLAY_NAME");
        rejects("Ali‍Veli", "INVALID_DISPLAY_NAME");
        rejects("Ali⁦Veli", "INVALID_DISPLAY_NAME");
        rejects("Ali﻿Veli", "INVALID_DISPLAY_NAME");
        rejects("ㅤㅤㅤ", "INVALID_DISPLAY_NAME");
        rejects("AliVeli", "INVALID_DISPLAY_NAME");
    }

    @Test
    void lengthIsByCodePointsAndRequiresLetters() {
        rejects("A", "INVALID_DISPLAY_NAME");
        rejects("12345", "INVALID_DISPLAY_NAME");
        rejects("a".repeat(81), "INVALID_DISPLAY_NAME");
        assertEquals("a".repeat(80), ok("a".repeat(80)));
    }

    @Test
    void emojiLimited() {
        assertEquals("Ali 😀", ok("Ali 😀"));
        rejects("Ali 😀😀😀", "INVALID_DISPLAY_NAME");
        rejects("😀😀", "INVALID_DISPLAY_NAME");
    }

    @Test
    void rejectsSymbolsAndMarkSpam() {
        rejects("Ali @admin", "INVALID_DISPLAY_NAME");
        rejects("<b>Ali</b>", "INVALID_DISPLAY_NAME");
        rejects("Ali http://x.y", "INVALID_DISPLAY_NAME");
        rejects("Alì́̂̃ Veli", "INVALID_DISPLAY_NAME");
    }

    @Test
    void rejectsMixedScriptWordsButAllowsMixedWords() {
        rejects("Pаul", "INVALID_DISPLAY_NAME"); // Kiril a
        rejects("Аdmin", "INVALID_DISPLAY_NAME"); // Kiril A + Latin
        assertEquals("Ali Мария", ok("Ali Мария"));
    }

    @Test
    void blocksAdminAndSupportImpersonation() {
        for (String s : new String[] {"Admin", "ADMIN", "a d m i n", "Adm1n", "Yönetici", "Yonetici", "YÖNETİCİ",
                "Destek Ekibi", "D.e.s.t.e.k", "Support Team", "BÜ Kampüs", "BU KAMPUS Destek", "Bingöl Üniversitesi",
                "Rektör", "S1stem", "Admin Ali"}) {
            rejects(s, "RESERVED_DISPLAY_NAME");
        }
    }

    @Test
    void adminsAreExempt() {
        assertEquals("Yönetici", DisplayNamePolicy.normalize("Yönetici", true));
    }

    @Test
    void normalNamesAreNotFalsePositives() {
        assertEquals("Mehmet Sistemci", ok("Mehmet Sistemci"));
        assertEquals("Adnan Menderes", ok("Adnan Menderes"));
        assertEquals("Ömer Destekli", ok("Ömer Destekli"));
    }
}
