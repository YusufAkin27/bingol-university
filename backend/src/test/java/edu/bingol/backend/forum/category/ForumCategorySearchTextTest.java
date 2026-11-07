package edu.bingol.backend.forum.category;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

/** Kategori arama katlamasi: Turkce karakter, I/i/noktali-i, Arapca hareke/alef, sozcuk bolme. */
class ForumCategorySearchTextTest {

    @Test
    void foldIgnoresTurkishDiacriticsAndDottedI() {
        assertEquals("gundem", ForumCategorySearchText.fold("GÜNDEM"));
        assertEquals("kampus yasami", ForumCategorySearchText.fold("Kampüs Yaşamı"));
        assertEquals("ilahiyat", ForumCategorySearchText.fold("İLAHİYAT"));
        assertEquals("isik", ForumCategorySearchText.fold("Işık"));
        assertEquals("ogrenci isleri", ForumCategorySearchText.fold("Öğrenci İşleri"));
        assertEquals("", ForumCategorySearchText.fold(null));
    }

    @Test
    void foldNormalizesArabicMarksAndAlefVariants() {
        assertEquals(ForumCategorySearchText.fold("الإعلانات"), ForumCategorySearchText.fold("الاعلانات"));
        assertEquals(ForumCategorySearchText.fold("مَكتبة"), ForumCategorySearchText.fold("مكتبه"));
    }

    @Test
    void tokensSplitOnSpacesAndAmpersandsAndCapAtSix() {
        assertEquals(List.of("soru", "cevap"), ForumCategorySearchText.tokens("  Soru & CEVAP "));
        assertEquals(List.of("yeme", "icme"), ForumCategorySearchText.tokens("Yeme-İçme"));
        assertTrue(ForumCategorySearchText.tokens("   ").isEmpty());
        assertTrue(ForumCategorySearchText.tokens(null).isEmpty());
        assertEquals(6, ForumCategorySearchText.tokens("a b c d e f g h").size());
    }

    @Test
    void matchesRequiresEveryToken() {
        String hay = ForumCategorySearchText.fold("Hocalar & Ders Seçimi Instructors akademik");
        assertTrue(ForumCategorySearchText.matches(ForumCategorySearchText.tokens("ders secimi"), hay));
        assertTrue(ForumCategorySearchText.matches(ForumCategorySearchText.tokens("HOCA"), hay));
        assertFalse(ForumCategorySearchText.matches(ForumCategorySearchText.tokens("hoca yemek"), hay));
        assertTrue(ForumCategorySearchText.matches(List.of(), hay));
    }
}
