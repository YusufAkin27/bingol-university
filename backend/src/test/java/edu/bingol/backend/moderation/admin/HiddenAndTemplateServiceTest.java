package edu.bingol.backend.moderation.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.ModerationNotifier;
import edu.bingol.backend.moderation.ModerationTargetState;
import edu.bingol.backend.moderation.ModerationTargetStateRepository;
import edu.bingol.backend.moderation.ReportTargetHandler;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.StrikeService;
import edu.bingol.backend.moderation.admin.ModAdminDtos.RestoreResult;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** Gizlenen icerik geri alma (reversible/degil) ve sebep sablonu servisi mantigi (Mockito). */
class HiddenAndTemplateServiceTest {

    private final ModerationTargetStateRepository states = mock(ModerationTargetStateRepository.class);
    private final StrikeService strikes = mock(StrikeService.class);
    private final ModerationNotifier notifier = mock(ModerationNotifier.class);
    private final UserRepository users = mock(UserRepository.class);

    private static ReportTargetHandler handler(ReportTargetType type, boolean reversible, boolean exists, Long owner) {
        ReportTargetHandler h = mock(ReportTargetHandler.class);
        when(h.type()).thenReturn(type);
        when(h.reversible()).thenReturn(reversible);
        when(h.exists(7L)).thenReturn(exists);
        when(h.ownerId(7L)).thenReturn(Optional.ofNullable(owner));
        return h;
    }

    private ModerationTargetState hiddenState(ReportTargetType type) {
        ModerationTargetState st = new ModerationTargetState();
        st.setTargetType(type);
        st.setTargetId(7L);
        st.setHiddenBy(ModerationTargetState.HiddenBy.AUTO);
        when(states.findByTargetTypeAndTargetId(type, 7L)).thenReturn(Optional.of(st));
        return st;
    }

    private HiddenContentAdminService service(ReportTargetHandler... hs) {
        return new HiddenContentAdminService(states, List.of(hs), strikes, notifier, users);
    }

    @Test
    void restoreUnhidesClearsStateRevokesStrikesAndNotifiesOwner() {
        ReportTargetHandler h = handler(ReportTargetType.POST, true, true, 55L);
        hiddenState(ReportTargetType.POST);

        RestoreResult r = service(h).restore(ReportTargetType.POST, 7L, "yanlis karar");

        assertTrue(r.unhidden());
        verify(h).unhide(7L);
        verify(states).clear(ReportTargetType.POST, 7L);
        verify(strikes).revokeForTarget(ReportTargetType.POST, 7L);
        verify(notifier).restored(55L, ReportTargetType.POST, 7L);
    }

    @Test
    void restoreOfDeletedContentOnlyClearsMarker() {
        ReportTargetHandler h = handler(ReportTargetType.POST, true, false, null);
        hiddenState(ReportTargetType.POST);

        RestoreResult r = service(h).restore(ReportTargetType.POST, 7L, "silinmis icerik");

        assertFalse(r.unhidden());
        verify(h, never()).unhide(any());
        verify(states).clear(ReportTargetType.POST, 7L);
    }

    @Test
    void nonReversibleTargetIsRejectedWithoutSideEffects() {
        ReportTargetHandler h = handler(ReportTargetType.USER, false, true, 3L);
        hiddenState(ReportTargetType.USER);

        ApiException e = assertThrows(ApiException.class, () -> service(h).restore(ReportTargetType.USER, 7L, "deneme"));

        assertEquals("TARGET_NOT_REVERSIBLE", e.code());
        assertEquals(409, e.status().value());
        verify(h, never()).unhide(any());
        verify(states, never()).clear(any(), any());
        verify(strikes, never()).revokeForTarget(any(), any());
        verify(notifier, never()).restored(any(), any(), any());
    }

    @Test
    void notHiddenIs404AndUnsupportedTypeIs400() {
        ReportTargetHandler h = handler(ReportTargetType.POST, true, true, 1L);
        when(states.findByTargetTypeAndTargetId(ReportTargetType.POST, 7L)).thenReturn(Optional.empty());
        ApiException e = assertThrows(ApiException.class, () -> service(h).restore(ReportTargetType.POST, 7L, "yok"));
        assertEquals("HIDDEN_CONTENT_NOT_FOUND", e.code());

        // isaret var ama handler yok (bu tur bu surumde desteklenmiyor)
        hiddenState(ReportTargetType.EVENT);
        ApiException e2 = assertThrows(ApiException.class, () -> service(h).restore(ReportTargetType.EVENT, 7L, "yok"));
        assertEquals("TARGET_TYPE_UNSUPPORTED", e2.code());
    }

    // ---- sebep sablonu ----

    private final ModerationReasonTemplateRepository repo = mock(ModerationReasonTemplateRepository.class);
    private final I18n i18n = mock(I18n.class);
    private final ReasonTemplateService templates = new ReasonTemplateService(repo, i18n);

    private static ModerationReasonTemplate tpl(String code, boolean active) {
        ModerationReasonTemplate t = new ModerationReasonTemplate();
        t.setKind("DECISION");
        t.setCode(code);
        t.setTextTr("tr " + code);
        t.setActive(active);
        return t;
    }

    @Test
    void emptyTableFallsBackToFixedEnumList() {
        when(repo.countByKind("DECISION")).thenReturn(0L);
        assertEquals(Optional.of("SPAM"), templates.validCode(" spam "));
        assertEquals(Optional.empty(), templates.validCode("NOPE"));
        assertEquals(Optional.empty(), templates.validCode(null));
        when(repo.findByKindAndCode("DECISION", "SPAM")).thenReturn(Optional.empty());
        when(i18n.msg("mod.reason.SPAM", Lang.EN)).thenReturn("Spam or unwanted content");
        assertEquals("Spam or unwanted content", templates.text("SPAM", Lang.EN));
    }

    @Test
    void tableDrivenValidationHonoursActiveFlag() {
        when(repo.countByKind("DECISION")).thenReturn(2L);
        when(repo.findByKindAndCode("DECISION", "CUSTOM")).thenReturn(Optional.of(tpl("CUSTOM", true)));
        when(repo.findByKindAndCode("DECISION", "OFF")).thenReturn(Optional.of(tpl("OFF", false)));
        when(repo.findByKindAndCode("DECISION", "SPAM")).thenReturn(Optional.empty());

        assertEquals(Optional.of("CUSTOM"), templates.validCode("custom"));
        assertEquals(Optional.empty(), templates.validCode("OFF"), "pasif sablon karar nedeni olamaz");
        assertEquals(Optional.empty(), templates.validCode("SPAM"), "tabloda yoksa sabit listeden gecerli sayilmaz");
        // eski kayitlardaki kod, sablon silinmis olsa da metne cozulur (sabit listeden)
        when(i18n.msg("mod.reason.SPAM", Lang.TR)).thenReturn("Spam");
        assertEquals("Spam", templates.text("SPAM", Lang.TR));
        assertEquals("tr CUSTOM", templates.text("CUSTOM", Lang.AR), "bos ar metni Turkceye duser");
    }

    @Test
    void createRejectsAtLimit() {
        when(repo.countByKind("DECISION")).thenReturn((long) ReasonTemplateService.MAX);
        ApiException e = assertThrows(ApiException.class, () -> templates.create(
                new ModAdminDtos.TemplateRequest("YENI", "metin", null, null, null, null)));
        assertEquals("REASON_TEMPLATE_LIMIT", e.code());
    }
}
