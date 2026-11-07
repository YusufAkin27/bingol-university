package edu.bingol.backend.search;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

/** Turkce katlama: buyuk/kucuk harf + Turkce karakter duyarsiz arama anahtari (KS-BE2). */
class TrFoldTest {

    @Test
    void foldsTurkishLettersAndCase() {
        assertEquals("sirin yildiz", TrFold.fold("ŞİRİN Yıldız"));
        assertEquals("isik gokce ozturk cagla", TrFold.fold("IŞIK Gökçe ÖZTÜRK Çağla"));
        assertEquals("ismail", TrFold.fold("İSMAİL"));
        assertEquals("ismail", TrFold.fold("ısmaıl"));
    }

    @Test
    void sameKeyForDifferentSpellings() {
        assertEquals(TrFold.fold("Gül"), TrFold.fold("GUL"));
        assertEquals(TrFold.fold("ığdır"), TrFold.fold("IGDIR"));
        assertEquals(TrFold.fold("Çiğdem"), TrFold.fold("cigdem"));
    }

    @Test
    void decomposedDottedCapitalIFoldsToI() {
        // "I" + birlestirici nokta (NFD) -> NFC "İ" -> i
        assertEquals("ismail", TrFold.fold("İSMAİL"));
    }

    @Test
    void collapsesAndTrimsWhitespace() {
        assertEquals("ali veli", TrFold.fold("  Ali \t  VELİ\n"));
        assertEquals("", TrFold.fold("   "));
        assertEquals("", TrFold.fold(null));
    }

    @Test
    void sqlMappingTablesAreAligned() {
        assertEquals(TrFold.SQL_FROM.length(), TrFold.SQL_TO.length());
        for (int i = 0; i < TrFold.SQL_FROM.length(); i++) {
            // Java katlamasi SQL translate() ile ayni sonucu vermeli (V1230 indeksi + UserRepository sorgusu)
            String ch = String.valueOf(TrFold.SQL_FROM.charAt(i));
            assertEquals(String.valueOf(TrFold.SQL_TO.charAt(i)), TrFold.fold(ch));
        }
    }

    @Test
    void escapesLikeWildcards() {
        assertEquals("50\\%\\_a\\\\", TrFold.escapeLike("50%_a\\"));
    }
}
