package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppSetting;
import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.i18n.Lang;
import java.util.List;
import org.junit.jupiter.api.Test;

class LegalServiceTest {

    private final DocumentRepository docs = mock(DocumentRepository.class);
    private final AcceptanceRepository acc = mock(AcceptanceRepository.class);
    private final AppSettingRepository settings = mock(AppSettingRepository.class);
    private final LegalService service = new LegalService(docs, acc, settings);

    private static AppSetting s(String k, String v) {
        AppSetting a = new AppSetting();
        a.setKey(k);
        a.setValue(v);
        return a;
    }

    private static LegalDocument doc(LegalType t) {
        LegalDocument d = new LegalDocument();
        d.setType(t);
        d.setLang("tr");
        d.setVersion(3);
        d.setTitle("t");
        d.setContent("c");
        d.setActive(true);
        d.setRequireReaccept(true);
        return d;
    }

    @Test
    void renderAyarlardanDoldurur_bosKimlikSatiriDuser() {
        when(settings.findAll()).thenReturn(List.of(s("legal.controller.name", "Bingöl Üniversitesi"),
                s("legal.controller.kep", ""), s("support_email", "destek@bingol.edu.tr")));
        String out = service.render("{{controller.name}}\n{{?controller.kep}}KEP {{controller.kep}}{{/controller.kep}}\n"
                + "{{support.email|Destek}}");
        assertThat(out).isEqualTo("Bingöl Üniversitesi\ndestek@bingol.edu.tr");
        assertThat(service.render("{{hosting.location}} {{controller.verbis}}")).doesNotContain("{{");
    }

    @Test
    void kayitOnayiYalnizZorunluDortTur() {
        when(docs.findByActiveTrue()).thenReturn(List.of(doc(LegalType.TERMS), doc(LegalType.PRIVACY),
                doc(LegalType.KVKK), doc(LegalType.COMMUNITY_RULES), doc(LegalType.EXPLICIT_CONSENT),
                doc(LegalType.COOKIES), doc(LegalType.CONTENT_REMOVAL), doc(LegalType.RETENTION)));
        when(acc.existsByUserIdAndDocTypeAndVersion(any(), any(), eq(3))).thenReturn(false);
        service.recordSignupConsent(7L);
        verify(acc, never()).save(argThat((LegalAcceptance a) -> !a.getDocType().isSignupRequired()));
        verify(acc, times(4)).save(any(LegalAcceptance.class));
    }

    @Test
    void bekleyenOnayBilgilendirmeTurleriniIcermez() {
        when(docs.findByActiveTrue()).thenReturn(List.of(doc(LegalType.TERMS), doc(LegalType.COOKIES)));
        assertThat(service.pending(1L, Lang.TR)).extracting("type").containsExactly(LegalType.TERMS);
    }

    private static LegalDocument docLang(LegalType t, String lang, int version, boolean active) {
        LegalDocument d = doc(t);
        d.setLang(lang);
        d.setVersion(version);
        d.setActive(active);
        return d;
    }

    @Test
    void guncelCozumuIstenenDildeYoksaTurkce() {
        when(docs.findByTypeAndLangAndActiveTrue(LegalType.TERMS, "ar")).thenReturn(java.util.Optional.of(docLang(LegalType.TERMS, "ar", 5, true)));
        when(docs.findByTypeAndLangAndActiveTrue(LegalType.PRIVACY, "ar")).thenReturn(java.util.Optional.empty());
        when(docs.findByTypeAndLangAndActiveTrue(LegalType.PRIVACY, "tr")).thenReturn(java.util.Optional.of(docLang(LegalType.PRIVACY, "tr", 5, true)));
        assertThat(service.current(LegalType.TERMS, Lang.AR).getLang()).isEqualTo("ar");
        assertThat(service.current(LegalType.PRIVACY, Lang.AR).getLang()).isEqualTo("tr");
    }

    @Test
    void yeniSurumYayinlaninca_eskiOnayliKullaniciYenidenOnayBekler_arapcaSurumuTetiklemez() {
        // Aktif tr belge surum 5; kullanici yalniz 4'u onaylamis
        when(docs.findByActiveTrue()).thenReturn(List.of(docLang(LegalType.TERMS, "tr", 5, true),
                docLang(LegalType.TERMS, "ar", 5, true)));
        when(docs.findByTypeAndLangAndActiveTrue(LegalType.TERMS, "ar"))
                .thenReturn(java.util.Optional.of(docLang(LegalType.TERMS, "ar", 5, true)));
        when(acc.existsByUserIdAndDocTypeAndVersion(1L, LegalType.TERMS, 4)).thenReturn(true);
        when(acc.existsByUserIdAndDocTypeAndVersion(1L, LegalType.TERMS, 5)).thenReturn(false);
        assertThat(service.pending(1L, Lang.AR)).extracting("version").containsExactly(5);
        // Surum 5 onaylaninca bekleyen kalmaz
        when(acc.existsByUserIdAndDocTypeAndVersion(1L, LegalType.TERMS, 5)).thenReturn(true);
        assertThat(service.pending(1L, Lang.AR)).isEmpty();
    }

    @Test
    void eskiSurumOnayiReddedilir() {
        when(docs.findByTypeAndLangAndActiveTrue(LegalType.TERMS, "tr"))
                .thenReturn(java.util.Optional.of(docLang(LegalType.TERMS, "tr", 5, true)));
        org.junit.jupiter.api.Assertions.assertThrows(edu.bingol.backend.common.ApiException.class,
                () -> service.accept(1L, List.of(new edu.bingol.backend.legal.LegalDtos.ConsentItem(LegalType.TERMS, 4))));
    }

    @Test
    void relationVeJurisdictionYerTutucusuYedekMetinleriKullanir() {
        when(settings.findAll()).thenReturn(List.of());
        assertThat(service.render("{{controller.jurisdiction|Bingöl}} mahkemeleri")).isEqualTo("Bingöl mahkemeleri");
    }
}
