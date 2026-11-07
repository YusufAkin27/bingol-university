package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/**
 * Parola politikasi: yonetici hesaplari {@link PasswordPolicy#require} (guclu: uzunluk + yaygin liste + kisisel veri,
 * T-005); yonetici olmayan hesaplar {@link PasswordPolicy#requireForUser} (yalniz en az 6 karakter).
 */
class PasswordPolicyTest {

    private static final PasswordPolicy.Context CTX =
            new PasswordPolicy.Context("226051015@bingol.edu.tr", "Şükrü Çağlar");

    @ParameterizedTest
    @ValueSource(strings = {
            "12345678",        // kisa + yaygin
            "password1",       // kisa + yaygin
            "1234567890",      // uzun ama yaygin rakam dizisi
            "qwertyuiop",      // klavye yurumesi
            "aaaaaaaaaaaa",    // tek karakter tekrari
            "Password123",     // yaygin kok + rakam eki
            "Galatasaray1905", // kok kelime + yil eki
            "Sifre1234567",    // Turkce yaygin kok + rakam eki
            "Bingol2026!",     // kurum adi + yil + sembol
            "iloveyou12",
            "Abc12345!"        // 9 karakter: kisa
    })
    void commonShortOrPredictablePasswordsAreRejected(String pw) {
        ApiException e = assertThrows(ApiException.class, () -> PasswordPolicy.require(pw, 10, CTX));
        assertEquals("PASSWORD_TOO_WEAK", e.code());
        assertEquals(400, e.status().value());
        assertEquals("10", e.args()[0]);
    }

    @Test
    void passwordContainingStudentNumberOrEmailUserOrNameWordsIsRejected() {
        assertThrows(ApiException.class, () -> PasswordPolicy.require("x226051015xxxx", 10, CTX));
        // Turkce karakterler katlanir: "Caglar" == "Çağlar"
        assertThrows(ApiException.class, () -> PasswordPolicy.require("caglar-Qz9!mLw", 10, CTX));
        assertThrows(ApiException.class, () -> PasswordPolicy.require("Sukru!Qz9mLwTx", 10, CTX));
        PasswordPolicy.Context mail = new PasswordPolicy.Context("ali.veli@bingol.edu.tr", "Ali Veli");
        assertThrows(ApiException.class, () -> PasswordPolicy.require("aliveli-Qz9!mLw", 10, mail));
    }

    @Test
    void strongPasswordsAndPassphrasesPass() {
        assertDoesNotThrow(() -> PasswordPolicy.require("Kx7-mQ2vLp9z", 10, CTX));
        assertDoesNotThrow(() -> PasswordPolicy.require("mavi bulut kahve 88", 10, CTX));
        assertDoesNotThrow(() -> PasswordPolicy.require("Zürafa-Tren-Ocak-41", 10, CTX));
        // bilgi yoksa kisisel veri denetimi atlanir
        assertDoesNotThrow(() -> PasswordPolicy.require("Kx7-mQ2vLp9z", 10, null));
    }

    @Test
    void administratorsNeedTwelveCharacters() {
        String eleven = "Kx7-mQ2vLp9";
        assertDoesNotThrow(() -> PasswordPolicy.require(eleven, 10, CTX));
        assertThrows(ApiException.class, () -> PasswordPolicy.require(eleven, 12, CTX));
        assertDoesNotThrow(() -> PasswordPolicy.require(eleven + "z", 12, CTX));
    }

    @Test
    void commonListResourceIsLoadedAndLarge() {
        // yaygin liste kaynak dosyasi sinif yolunda ve bos degil: ornekler reddedilir
        assertThrows(ApiException.class, () -> PasswordPolicy.require("trabzonspor1967", 10, null));
        assertThrows(ApiException.class, () -> PasswordPolicy.require("ataturk1881", 10, null));
    }

    // --- Yonetici olmayan hesap: yalniz en az 6 karakter ---

    @ParameterizedTest
    @ValueSource(strings = {"123456", "aaaaaa", "password", "qwerty", "abcdef", "226051015", "caglar", "Ab1!x9", "şifreş", "      "})
    void userPasswordsOfSixOrMoreCharactersAreAccepted(String pw) {
        assertDoesNotThrow(() -> PasswordPolicy.requireForUser(pw, PasswordPolicy.DEFAULT_MIN));
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "a", "12345", "abcde", "şğüıö"})
    void userPasswordsShorterThanSixAreRejectedWithTooShort(String pw) {
        ApiException e = assertThrows(ApiException.class, () -> PasswordPolicy.requireForUser(pw, 6));
        assertEquals("PASSWORD_TOO_SHORT", e.code());
        assertEquals(400, e.status().value());
        assertEquals("6", e.args()[0]);
    }

    @Test
    void userRuleCountsCodePointsNotUtf16Units() {
        // 3 emoji = 6 UTF-16 birimi ama 3 kod noktasi: kisa; 6 emoji gecerli
        String three = new String(Character.toChars(0x1F600)).repeat(3);
        assertThrows(ApiException.class, () -> PasswordPolicy.requireForUser(three, 6));
        assertDoesNotThrow(() -> PasswordPolicy.requireForUser(three + three, 6));
        assertThrows(ApiException.class, () -> PasswordPolicy.requireForUser(null, 6));
    }

    @Test
    void adminRuleStaysStrict() {
        assertThrows(ApiException.class, () -> PasswordPolicy.require("123456", 12, CTX));
        assertThrows(ApiException.class, () -> PasswordPolicy.require("aaaaaaaaaaaa", 12, CTX));
        assertThrows(ApiException.class, () -> PasswordPolicy.require("x226051015xxxx", 12, CTX));
        assertDoesNotThrow(() -> PasswordPolicy.require("Kx7-mQ2vLp9z", 12, CTX));
    }
}
