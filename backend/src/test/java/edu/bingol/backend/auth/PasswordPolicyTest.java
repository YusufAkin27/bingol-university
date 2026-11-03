package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/**
 * T-005: parola politikasi (K-09 varsayilani: 10 karakter + yaygin liste + kisisel veri; yonetici 12).
 * PIN6: yonetici olmayan hesaplar icin tam 6 rakam + zayif PIN kurallari ({@code validateNew}).
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

    // ---- PIN6: yonetici olmayan hesaplar ----

    @ParameterizedTest
    @ValueSource(strings = {"481952", "739204", "000001", "135792", "246813", "100200", "123123", "123457", "908172"})
    void goodPinsPassForNormalAccounts(String pin) {
        assertDoesNotThrow(() -> PasswordPolicy.validateNew(pin, false));
    }

    @ParameterizedTest
    @ValueSource(strings = {"48195", "4819523", "48195a", "abcdef", "48 952", "", " 481952", "481952 ", "٤٨١٩٥٢", "48-952",
            "Kx7-mQ2vLp9z"})
    void nonSixDigitPasswordsAreRejectedAsInvalidPin(String pw) {
        ApiException e = assertThrows(ApiException.class, () -> PasswordPolicy.validateNew(pw, false));
        assertEquals("PASSWORD_INVALID_PIN", e.code());
        assertEquals(400, e.status().value());
    }

    @Test
    void nullPasswordIsInvalidPin() {
        ApiException e = assertThrows(ApiException.class, () -> PasswordPolicy.validateNew(null, false));
        assertEquals("PASSWORD_INVALID_PIN", e.code());
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "000000", "111111", "999999",                  // hepsi ayni
            "123456", "234567", "345678", "456789",       // duz artan
            "012345", "567890", "789012", "890123",       // 9->0 doner
            "654321", "987654", "876543", "321098",       // duz azalan (9<-0 doner dahil)
            "543210", "109876",
            "121212", "909090", "474747", "010101"})      // ababab
    void weakPinsAreRejected(String pin) {
        ApiException e = assertThrows(ApiException.class, () -> PasswordPolicy.validateNew(pin, false));
        assertEquals("PASSWORD_PIN_TOO_WEAK", e.code());
        assertEquals(400, e.status().value());
    }

    @Test
    void adminAccountsKeepTheStrongPolicyAndAreNotLimitedToPins() {
        // PIN yonetici icin cok kisa/zayif: PASSWORD_TOO_WEAK (eski kural)
        ApiException e = assertThrows(ApiException.class, () -> PasswordPolicy.validateNew("481952", true));
        assertEquals("PASSWORD_TOO_WEAK", e.code());
        assertEquals("12", e.args()[0]);
        // guclu parola gecer
        assertDoesNotThrow(() -> PasswordPolicy.validateNew("Kx7-mQ2vLp9z", true));
        // 72 bayt ustu
        ApiException tooLong = assertThrows(ApiException.class,
                () -> PasswordPolicy.validateNew("ğ".repeat(40), true));
        assertEquals("PASSWORD_TOO_LONG", tooLong.code());
        // yapilandirilabilir yonetici alt siniri
        assertThrows(ApiException.class, () -> PasswordPolicy.validateNew("Kx7-mQ2vLp9", true, 12, CTX));
        assertDoesNotThrow(() -> PasswordPolicy.validateNew("Kx7-mQ2vLp9", true, 10, CTX));
    }

    @Test
    void pinRuleIsAppliedOnlyToNonAdminAccounts() {
        // ayni guclu parola: yonetici icin gecerli, normal hesap icin PIN degil
        assertDoesNotThrow(() -> PasswordPolicy.validateNew("Kx7-mQ2vLp9z", true));
        ApiException e = assertThrows(ApiException.class, () -> PasswordPolicy.validateNew("Kx7-mQ2vLp9z", false));
        assertEquals("PASSWORD_INVALID_PIN", e.code());
    }
}
