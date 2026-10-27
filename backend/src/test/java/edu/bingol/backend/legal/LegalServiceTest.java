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
}
