package edu.bingol.backend.appinfo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppInfoService.VersionCheck;
import edu.bingol.backend.common.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;

class AppInfoVersionCheckTest {

    private final AppSettingRepository repo = mock(AppSettingRepository.class);
    private final AppInfoService service = new AppInfoService(repo);

    private static AppSetting s(String k, String v) {
        AppSetting a = new AppSetting();
        a.setKey(k);
        a.setValue(v);
        return a;
    }

    @Test
    void iosVersionRulesUseIosSettingsOnly() {
        when(repo.findAll()).thenReturn(List.of(s("min_version_ios", "1.2.0"), s("latest_version_ios", "1.10.0"),
                s("store_url_ios", "https://apps.apple.com/app/id1"), s("min_version_android", "9.0.0")));
        VersionCheck v = service.checkVersion("IOS", "1.9.3");
        assertFalse(v.updateRequired());
        assertTrue(v.updateAvailable());
        assertEquals("1.10.0", v.latestVersion());
        assertEquals("https://apps.apple.com/app/id1", v.storeUrl());
        assertTrue(service.checkVersion("ios", "1.1.9").updateRequired());
        assertFalse(service.checkVersion("ios", "1.10.0").updateAvailable());
    }

    @Test
    void buildNumberAndPreReleaseSuffixIgnored() {
        // QA5: istemci "2.2.0+22006" / "2.1.3-beta" gonderse 400 olup zorunlu guncelleme kapisi sessizce kapanmasin
        when(repo.findAll()).thenReturn(List.of(s("min_version_android", "2.1.3"), s("latest_version_android", "2.2.0")));
        assertFalse(service.checkVersion("android", "2.2.0+22006").updateRequired());
        assertFalse(service.checkVersion("android", "2.2.0+22006").updateAvailable());
        assertTrue(service.checkVersion("android", "2.1.2+99999").updateRequired());
        assertFalse(service.checkVersion("android", "2.1.3-beta").updateRequired());
        assertTrue(service.checkVersion("android", "2.1.3-beta").updateAvailable());
    }

    @Test
    void corruptStoredSettingDoesNotThrow() {
        // QA5: bozuk min/latest ayari (elle DB duzenlemesi) 500 degil; bozuk parca 0 sayilir
        when(repo.findAll()).thenReturn(List.of(s("min_version_android", "x.y"), s("latest_version_android", "")));
        VersionCheck v = service.checkVersion("android", "2.0.0");
        assertFalse(v.updateRequired());
    }

    @Test
    void invalidPlatformOrVersionRejected() {
        assertEquals("INVALID_VERSION", assertThrows(ApiException.class, () -> service.checkVersion("web", "1.0")).code());
        assertEquals("INVALID_VERSION", assertThrows(ApiException.class, () -> service.checkVersion("ios", "x.y")).code());
        // QA: tasan sayi (Long.parseLong) 500 degil 400 olmali
        assertEquals("INVALID_VERSION", assertThrows(ApiException.class, () -> service.checkVersion("android", "9".repeat(40))).code());
        assertEquals("INVALID_VERSION", assertThrows(ApiException.class, () -> service.checkVersion("android", "1.0." + "9".repeat(10))).code());
    }
}
