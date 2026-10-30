package edu.bingol.backend.appinfo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.TestCaches;
import edu.bingol.backend.i18n.Lang;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Uygulama bilgisi/surum kontrolu ayarlari: onbellekli; yonetici ayar listesi HER ZAMAN taze. */
class AppInfoServiceCacheTest {

    private final AppSettingRepository repo = mock(AppSettingRepository.class);
    private final CacheService cache = TestCaches.create();
    private final AppInfoService service = new AppInfoService(repo);

    private static AppSetting s(String k, String v) {
        AppSetting a = new AppSetting();
        a.setKey(k);
        a.setValue(v);
        return a;
    }

    @BeforeEach
    void wire() {
        service.setCache(cache);
        when(repo.findAll()).thenReturn(List.of(s("app_name", "BU Kampus"), s("banner_text_tr", "Merhaba"),
                s("banner_text_en", "Hello"), s("min_version_ios", "1.0.0"), s("latest_version_ios", "2.0.0")));
    }

    @Test
    void infoAndVersionShareOneCachedSettingsRead() {
        service.info(Lang.TR);
        service.info(Lang.TR);
        service.checkVersion("ios", "1.5.0");
        verify(repo, times(1)).findAll();
    }

    @Test
    void languageOnlyChangesTheProjectionNotTheCachedMap() {
        assertEquals("Merhaba", service.info(Lang.TR).banner().text());
        assertEquals("Hello", service.info(Lang.EN).banner().text());
        assertEquals("Merhaba", service.info(Lang.AR).banner().text(), "ar yoksa tr");
        verify(repo, times(1)).findAll();
    }

    @Test
    void settingChangeShowsAfterInvalidation() {
        assertTrue(!service.info(Lang.TR).maintenance().enabled());
        when(repo.findAll()).thenReturn(List.of(s("maintenance_mode", "true")));
        assertTrue(!service.info(Lang.TR).maintenance().enabled(), "onbellek gecerliyken eski deger");
        cache.invalidate("appinfo");
        assertTrue(service.info(Lang.TR).maintenance().enabled());
    }

    @Test
    void adminSettingsListIsNeverCached() {
        service.all();
        service.all();
        verify(repo, times(2)).findAll();
    }

    @Test
    void setValueGoesThroughRepositoryAndStaysValidated() {
        AppSetting existing = s("maintenance_mode", "false");
        when(repo.findById("maintenance_mode")).thenReturn(Optional.of(existing));
        service.set("maintenance_mode", "true");
        verify(repo).save(existing);
        assertEquals("true", existing.getValue());
    }
}
