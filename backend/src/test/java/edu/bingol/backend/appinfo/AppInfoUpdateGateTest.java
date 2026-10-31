package edu.bingol.backend.appinfo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppInfoService.EnforceChange;
import edu.bingol.backend.appinfo.AppInfoService.EnforceMode;
import edu.bingol.backend.appinfo.AppInfoService.VersionCheck;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.cache.TestCaches;
import edu.bingol.backend.i18n.Lang;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** UPDATEGATE: surum kontrolu yeni alanlari (message, marketUrl, turetilmis storeUrl), ayar dogrulama, zorlama. */
class AppInfoUpdateGateTest {

    private final AppSettingRepository repo = mock(AppSettingRepository.class);
    private final Map<String, AppSetting> store = new LinkedHashMap<>();
    private final AppInfoService service = new AppInfoService(repo);

    private void put(String k, String v) {
        AppSetting a = new AppSetting();
        a.setKey(k);
        a.setValue(v);
        store.put(k, a);
    }

    @BeforeEach
    void wire() {
        service.setCache(TestCaches.create());
        put("min_version_android", "1.0.0");
        put("latest_version_android", "2.0.4");
        put("store_url_android", "");
        put("store_package_android", "tr.com.bukampus.app");
        put("min_version_ios", "1.0.0");
        put("latest_version_ios", "1.0.0");
        put("store_url_ios", "");
        put("apple_app_id_ios", "");
        put("update_message_tr", "Yeni sürüm hazır.");
        put("update_message_en", "A new version is ready.");
        put("update_message_ar", "");
        when(repo.findAll()).thenAnswer(i -> new ArrayList<>(store.values()));
        when(repo.findById(anyString())).thenAnswer(i -> Optional.ofNullable(store.get(i.<String>getArgument(0))));
        when(repo.save(any(AppSetting.class))).thenAnswer(i -> {
            AppSetting a = i.getArgument(0);
            store.put(a.getKey(), a);
            return a;
        });
    }

    // --- checkVersion ek alanlar ---

    @Test
    void androidStoreUrlIsDerivedFromPackageWhenAdminLeftItEmpty() {
        VersionCheck v = service.checkVersion("android", "2.0.0", Lang.TR);
        assertEquals("https://play.google.com/store/apps/details?id=tr.com.bukampus.app", v.storeUrl());
        assertEquals("market://details?id=tr.com.bukampus.app", v.marketUrl());
    }

    @Test
    void androidPackageFallsBackToDefaultAndHonoursCustomPackage() {
        put("store_package_android", "");
        assertEquals("market://details?id=tr.com.bukampus.app", service.checkVersion("android", "1.0", Lang.TR).marketUrl());
        // gecersiz paket adi de varsayilana duser (uydurma sema olusmaz)
        put("store_package_android", "x y<>");
        service.setCache(TestCaches.create());
        assertEquals("market://details?id=tr.com.bukampus.app", service.checkVersion("android", "1.0", Lang.TR).marketUrl());
        put("store_package_android", "com.ornek.uygulama");
        service.setCache(TestCaches.create());
        assertEquals("https://play.google.com/store/apps/details?id=com.ornek.uygulama",
                service.checkVersion("android", "1.0", Lang.TR).storeUrl());
    }

    @Test
    void adminEnteredStoreUrlWinsOverDerived() {
        put("store_url_android", "https://play.google.com/store/apps/details?id=ozel");
        VersionCheck v = service.checkVersion("android", "1.0", Lang.TR);
        assertEquals("https://play.google.com/store/apps/details?id=ozel", v.storeUrl());
        assertEquals("market://details?id=tr.com.bukampus.app", v.marketUrl(), "market yine pakettan");
    }

    @Test
    void iosHasNoStoreLinkWithoutAppleId() {
        VersionCheck v = service.checkVersion("ios", "1.0.0", Lang.TR);
        assertNull(v.storeUrl());
        assertNull(v.marketUrl());
    }

    @Test
    void iosLinksDerivedFromAppleIdOnlyWhenNumeric() {
        put("apple_app_id_ios", "6740123456");
        VersionCheck v = service.checkVersion("ios", "1.0.0", Lang.TR);
        assertEquals("https://apps.apple.com/app/id6740123456", v.storeUrl());
        assertEquals("itms-apps://apps.apple.com/app/id6740123456", v.marketUrl());
        put("apple_app_id_ios", "id123");
        service.setCache(TestCaches.create());
        assertNull(service.checkVersion("ios", "1.0.0", Lang.TR).storeUrl());
    }

    @Test
    void messageFollowsRequestLanguageAndFallsBackToTurkish() {
        assertEquals("Yeni sürüm hazır.", service.checkVersion("android", "1.0", Lang.TR).message());
        assertEquals("A new version is ready.", service.checkVersion("android", "1.0", Lang.EN).message());
        assertEquals("Yeni sürüm hazır.", service.checkVersion("android", "1.0", Lang.AR).message(), "ar bos -> tr");
        put("update_message_tr", "");
        service.setCache(TestCaches.create());
        assertNull(service.checkVersion("android", "1.0", Lang.TR).message(), "bos mesaj null");
    }

    @Test
    void legacyTwoArgCheckStillWorks() {
        VersionCheck v = service.checkVersion("android", "2.0.0");
        assertFalse(v.updateRequired());
        assertTrue(v.updateAvailable());
        assertEquals("2.0.4", v.latestVersion());
    }

    // --- ayar dogrulama ---

    @Test
    void updateMessageRejectsHtmlLinksControlAndOverlong() {
        for (String bad : new String[] {"<b>x</b>", "bak https://evil.example", "git www.evil.example", "a&amp;b",
                "javascript:alert(1)", "satir\nsonu", "x".repeat(281)}) {
            ApiException e = assertThrows(ApiException.class, () -> service.set("update_message_tr", bad), bad);
            assertEquals("SETTING_INVALID", e.code());
        }
        service.set("update_message_tr", "x".repeat(280));
        service.set("update_message_en", "");
        assertEquals("", store.get("update_message_en").getValue());
    }

    @Test
    void packageAndAppleIdValidation() {
        assertEquals("SETTING_INVALID", assertThrows(ApiException.class, () -> service.set("store_package_android", "tek")).code());
        assertEquals("SETTING_INVALID", assertThrows(ApiException.class, () -> service.set("store_package_android", "a.b c")).code());
        assertEquals("SETTING_INVALID", assertThrows(ApiException.class, () -> service.set("apple_app_id_ios", "12ab")).code());
        assertEquals("SETTING_INVALID", assertThrows(ApiException.class, () -> service.set("apple_app_id_ios", "1234")).code());
        service.set("store_package_android", "tr.com.bukampus.app");
        service.set("apple_app_id_ios", "6740123456");
        service.set("apple_app_id_ios", "");
    }

    // --- zorlama ---

    @Test
    void forceSetsMinAndLatestAndTakesEffectImmediately() {
        assertFalse(service.checkVersion("android", "2.0.4").updateRequired());
        EnforceChange c = service.enforce("android", "2.0.5", EnforceMode.FORCE);
        assertEquals("2.0.5", c.min());
        assertEquals("2.0.5", c.latest());
        assertEquals("1.0.0", c.previousMin());
        assertEquals("2.0.4", c.previousLatest());
        VersionCheck v = service.checkVersion("android", "2.0.4");
        assertTrue(v.updateRequired(), "onbellek gecersiz: ANINDA yeni sonuc");
        assertEquals("2.0.5", v.latestVersion());
        assertFalse(service.checkVersion("android", "2.0.5").updateRequired());
        assertEquals("FORCE", service.platformVersions("android").state());
        // ios etkilenmez
        assertEquals("1.0.0", store.get("min_version_ios").getValue());
    }

    @Test
    void forceBelowPublishedVersionRejectedAndNothingChanges() {
        ApiException e = assertThrows(ApiException.class, () -> service.enforce("android", "2.0.3", EnforceMode.FORCE));
        assertEquals("VERSION_BELOW_LATEST", e.code());
        assertEquals(400, e.status().value());
        assertEquals("1.0.0", store.get("min_version_android").getValue());
        assertEquals("2.0.4", store.get("latest_version_android").getValue());
        // esit surum serbest
        service.enforce("android", "2.0.4", EnforceMode.FORCE);
        assertEquals("2.0.4", store.get("min_version_android").getValue());
    }

    @Test
    void softChangesOnlyLatestAndLeavesMinAlone() {
        service.enforce("android", "2.0.5", EnforceMode.FORCE);
        EnforceChange c = service.enforce("android", "2.1.0", EnforceMode.SOFT);
        assertEquals("2.0.5", c.min());
        assertEquals("2.1.0", c.latest());
        VersionCheck v = service.checkVersion("android", "2.0.5");
        assertFalse(v.updateRequired());
        assertTrue(v.updateAvailable());
        assertEquals("FORCE", service.platformVersions("android").state(), "min hala varsayilanin ustunde");
        // oneri zorunlu en dusukun altina inemez
        assertEquals("VERSION_BELOW_MIN",
                assertThrows(ApiException.class, () -> service.enforce("android", "2.0.0", EnforceMode.SOFT)).code());
    }

    @Test
    void softOnFreshStateIsSuggestionOnly() {
        service.enforce("ios", "1.2.0", EnforceMode.SOFT);
        assertEquals("SOFT", service.platformVersions("ios").state());
        assertFalse(service.checkVersion("ios", "1.1.0").updateRequired());
        assertTrue(service.checkVersion("ios", "1.1.0").updateAvailable());
    }

    @Test
    void offRestoresDefaultMinAndKeepsLatest() {
        service.enforce("android", "2.0.5", EnforceMode.FORCE);
        EnforceChange c = service.enforce("android", null, EnforceMode.OFF);
        assertEquals("1.0.0", c.min());
        assertEquals("2.0.5", c.latest());
        assertFalse(service.checkVersion("android", "2.0.4").updateRequired(), "zorunluluk kalkti, aninda");
        assertEquals("SOFT", service.platformVersions("android").state());
    }

    @Test
    void invalidInputsAreRejected() {
        assertEquals("INVALID_VERSION", assertThrows(ApiException.class, () -> service.enforce("web", "2.0.5", EnforceMode.FORCE)).code());
        assertEquals("INVALID_VERSION", assertThrows(ApiException.class, () -> service.enforce("android", "x.y", EnforceMode.FORCE)).code());
        assertEquals("INVALID_VERSION", assertThrows(ApiException.class, () -> service.enforce("android", null, EnforceMode.SOFT)).code());
        assertEquals("INVALID_VERSION", assertThrows(ApiException.class, () -> service.enforce("android", "2.0.5.1.1", EnforceMode.FORCE)).code());
    }
}
