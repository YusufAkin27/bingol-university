package edu.bingol.backend.appinfo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.Lang;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Hesap silme sayfasi gibi herkese acik sayfalar isleten adini sozlesmelerle ayni ayardan okur. */
class AppInfoOperatorTest {

    private final AppSettingRepository repo = mock(AppSettingRepository.class);
    private final AppInfoService service = new AppInfoService(repo);

    private static AppSetting s(String k, String v) {
        AppSetting a = new AppSetting();
        a.setKey(k);
        a.setValue(v);
        return a;
    }

    @Test
    void operatorNameAndKvkkEmailComeFromLegalSettings() {
        when(repo.findAll()).thenReturn(List.of(
                s("legal.controller.name", "Yusuf Akın"), s("legal.controller.email", "kvkk@example.com"),
                s("legal.controller.address", "Gizli Mah. 1"), s("legal.controller.verbis", "123")));
        AppInfoService.AppInfo info = service.info(Lang.TR);
        assertEquals("Yusuf Akın", info.operatorName());
        assertEquals("kvkk@example.com", info.kvkkEmail());
        // adres ve sicil/kimlik bilgisi bu cevapta yok (address alani kurumsal iletisim ayaridir, legal.* degil)
        assertNull(info.address());
    }

    @Test
    void emptySettingsGiveNullFields() {
        when(repo.findAll()).thenReturn(List.of(s("legal.controller.name", " "), s("legal.controller.email", "")));
        AppInfoService.AppInfo info = service.info(Lang.TR);
        assertNull(info.operatorName());
        assertNull(info.kvkkEmail());
    }
}
