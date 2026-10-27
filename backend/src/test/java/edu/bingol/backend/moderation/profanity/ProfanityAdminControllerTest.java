package edu.bingol.backend.moderation.profanity;

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
import edu.bingol.backend.common.RateLimiter;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.Authentication;

class ProfanityAdminControllerTest {

    private final ProfanityTermRepository repo = mock(ProfanityTermRepository.class);
    private final ProfanityHitLogRepository hits = mock(ProfanityHitLogRepository.class);
    private final ProfanityProperties props = new ProfanityProperties(true, ProfanityProperties.Mode.BLOCK, 30);
    private final ProfanityFilter filter = new ProfanityFilter(repo, props);
    private final ProfanityAdminController ctl =
            new ProfanityAdminController(repo, filter, hits, props, mock(RateLimiter.class));
    private final Authentication admin = new TestingAuthenticationToken(5L, "x", "ROLE_ADMIN");

    private static ProfanityTerm term(long id, String text, ProfanityTerm.Kind kind) {
        ProfanityTerm t = new ProfanityTerm();
        t.setId(id);
        t.setTerm(text);
        t.setTermNormalized(ProfanityMatcher.canonical(text));
        t.setKind(kind);
        t.setCreatedAt(Instant.parse("2026-10-01T10:00:00Z"));
        return t;
    }

    @Test
    void addStoresNormalizedTermAndTakesEffectImmediately() {
        List<ProfanityTerm> db = new ArrayList<>();
        when(repo.findAllByOrderByIdAsc()).thenAnswer(inv -> List.copyOf(db));
        when(repo.saveAndFlush(any(ProfanityTerm.class))).thenAnswer(inv -> {
            ProfanityTerm t = inv.getArgument(0);
            t.setId(1L);
            db.add(t);
            return t;
        });
        assertFalse(filter.check("burada zzquuxy var").blocked());

        ProfanityAdminController.TermView v = ctl.add(
                new ProfanityAdminController.TermRequest("  ZzQuuxy ", ProfanityTerm.Kind.BLOCK, "tr", "not"), admin);

        assertEquals("ZzQuuxy", v.term());
        assertEquals("TR", v.lang());
        assertEquals(5L, v.createdBy());
        assertTrue(filter.check("burada zzquuxy var").blocked(), "ekleme hemen etkili");
        assertEquals("zzquuxy", db.get(0).getTermNormalized());
    }

    @Test
    void duplicateAndInvalidTermsAreRejected() {
        when(repo.existsByKindAndTermNormalized(ProfanityTerm.Kind.BLOCK, "zzquuxy")).thenReturn(true);
        assertEquals("PROFANITY_TERM_EXISTS", assertThrows(ApiException.class, () -> ctl.add(
                new ProfanityAdminController.TermRequest("zzquuxy", ProfanityTerm.Kind.BLOCK, null, null), admin)).code());
        assertEquals("PROFANITY_TERM_INVALID", assertThrows(ApiException.class, () -> ctl.add(
                new ProfanityAdminController.TermRequest("1234", ProfanityTerm.Kind.BLOCK, null, null), admin)).code());
        verify(repo, never()).saveAndFlush(any());
    }

    @Test
    void removeUnknownIs404AndKnownRefreshes() {
        when(repo.existsById(9L)).thenReturn(false);
        ApiException e = assertThrows(ApiException.class, () -> ctl.remove(9L, admin));
        assertEquals(HttpStatus.NOT_FOUND, e.status());
        when(repo.existsById(2L)).thenReturn(true);
        ctl.remove(2L, admin);
        verify(repo).deleteById(2L);
    }

    @Test
    void checkShowsMatchesOnlyInAdminResponse() {
        when(repo.findAllByOrderByIdAsc()).thenReturn(List.of(term(1, "zzquuxy", ProfanityTerm.Kind.BLOCK)));
        ProfanityAdminController.CheckResult r =
                ctl.check(new ProfanityAdminController.CheckRequest("Zz.Quuxy!!"), admin);
        assertTrue(r.blocked());
        assertEquals(List.of("zzquuxy"), r.matches());
        assertEquals("z quxy", r.normalized()); // tekrar eden harfler sikistirilir
    }

    @Test
    void allowRecordOverridesBuiltInAndBlockRecord() {
        when(repo.findAllByOrderByIdAsc()).thenReturn(List.of(
                term(1, "zzquuxy", ProfanityTerm.Kind.BLOCK), term(2, "zzquuxy", ProfanityTerm.Kind.ALLOW)));
        assertFalse(filter.check("zzquuxy").blocked());
    }

    @Test
    void csvExportEscapesFormulaCells() {
        ProfanityTerm t = term(1, "=cmd", ProfanityTerm.Kind.BLOCK);
        t.setNote("+evil, \"x\"");
        when(repo.findAllByOrderByIdAsc()).thenReturn(List.of(t));
        ResponseEntity<byte[]> r = ctl.export(null);
        String csv = new String(r.getBody(), StandardCharsets.UTF_8);
        assertTrue(csv.contains("\"'=cmd\""), csv);
        assertTrue(csv.contains("\"'+evil, \"\"x\"\"\""), csv);
    }

    @Test
    void statsAggregateByEntityAndField() {
        List<Object[]> rows = new ArrayList<>();
        rows.add(new Object[] {"CLUB", "name", 4L});
        rows.add(new Object[] {"EVENT", "title", 1L});
        when(hits.countsSince(any(Instant.class))).thenReturn(rows);
        ProfanityAdminController.Stats s = ctl.stats();
        assertEquals(5, s.last24h().total());
        assertEquals("CLUB", s.last7d().byField().get(0).entity());
    }

    @Test
    void hitLogCannotStoreAWord() {
        // Gunluk kaydi yalnizca alan/varlik/kullanici/zaman tasir: kelime icin sutun yok
        for (var f : ProfanityHitLog.class.getDeclaredFields()) {
            assertFalse(List.of("term", "word", "text", "matches").contains(f.getName()), f.getName());
        }
        ProfanityHitLogRepository repo2 = mock(ProfanityHitLogRepository.class);
        new ProfanityHitLogger(repo2).record("CLUB", "name", 3L, "BLOCK");
        verify(repo2).save(any(ProfanityHitLog.class));
        verify(repo2, never()).deleteOlderThan(any());
        assertEquals(90, ProfanityHitLogger.RETENTION_DAYS);
    }
}
