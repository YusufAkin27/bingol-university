package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.jdbc.core.JdbcTemplate;

/** T-064 (A8-17): silme defteri yazimi ve geri yukleme sonrasi yeniden anonimlestirme. */
class DeletionLedgerTest {

    @TempDir
    Path dir;

    private DeletionLedger ledger(String file) {
        DeletionLedger l = new DeletionLedger(file);
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForObject(any(String.class), eq(java.sql.Timestamp.class), anyLong()))
                .thenReturn(java.sql.Timestamp.from(Instant.ofEpochSecond(1_700_000_000L)));
        l.setJdbc(jdbc);
        return l;
    }

    @Test
    void disabledWhenNoFileConfigured() {
        DeletionLedger l = new DeletionLedger("");
        l.record(5L);
        assertFalse(l.enabled());
        assertTrue(l.read().isEmpty());
    }

    @Test
    void recordsAppendOnlyIdsAndCreationSecondNoPersonalData() throws IOException {
        Path f = dir.resolve("ledger").resolve("deleted-users.log");
        DeletionLedger l = ledger(f.toString());

        l.record(5L);
        l.record(9L);
        l.record(5L); // yinelenen: okuma tarafi tekillestirir

        String text = Files.readString(f);
        assertEquals(3, text.lines().count());
        assertTrue(text.lines().allMatch(line -> line.split("\t").length == 3));
        assertFalse(text.contains("@"), "deftere e-posta/ad yazilmaz");
        var read = l.read();
        assertEquals(2, read.size());
        assertEquals(1_700_000_000L, read.get(5L).createdEpochSec());
    }

    @Test
    void writeFailureNeverThrows() throws IOException {
        Path blocker = Files.createFile(dir.resolve("file"));
        DeletionLedger l = ledger(blocker.resolve("sub").resolve("x.log").toString()); // ust yol dosya: yazilamaz
        l.record(5L); // exception sizdirmamali
        assertTrue(l.read().isEmpty());
    }

    @Test
    void reapplierAnonymizesRestoredAccountsOnly() throws IOException {
        Path f = dir.resolve("deleted-users.log");
        DeletionLedger l = ledger(f.toString());
        l.record(5L); // geri yuklenmis, canli gorunuyor, olusturma ani ayni -> yeniden anonimlestirilir
        l.record(6L); // zaten DELETED -> dokunulmaz
        l.record(7L); // ayni kimligi alan BASKA hesap (olusturma ani farkli) -> dokunulmaz
        l.record(8L); // hesap yok -> atlanir
        UserRepository users = mock(UserRepository.class);
        ProfileService profiles = mock(ProfileService.class);
        when(users.findById(5L)).thenReturn(Optional.of(user(5L, UserStatus.ACTIVE, 1_700_000_000L)));
        when(users.findById(6L)).thenReturn(Optional.of(user(6L, UserStatus.DELETED, 1_700_000_000L)));
        when(users.findById(7L)).thenReturn(Optional.of(user(7L, UserStatus.ACTIVE, 1_900_000_000L)));
        when(users.findById(8L)).thenReturn(Optional.empty());

        int n = new DeletionLedgerReapplier(l, users, profiles).reapply();

        assertEquals(1, n);
        verify(profiles).anonymizeAccount(5L);
        verify(profiles, never()).anonymizeAccount(6L);
        verify(profiles, never()).anonymizeAccount(7L);
        verify(profiles, never()).anonymizeAccount(8L);
    }

    @Test
    void reapplierDoesNothingWhenLedgerDisabled() {
        ProfileService profiles = mock(ProfileService.class);
        int n = new DeletionLedgerReapplier(new DeletionLedger(""), mock(UserRepository.class), profiles).reapply();
        assertEquals(0, n);
        verify(profiles, never()).anonymizeAccount(anyLong());
    }

    private static User user(long id, UserStatus status, long createdSec) {
        User u = new User();
        u.setId(id);
        u.setStatus(status);
        u.setCreatedAt(Instant.ofEpochSecond(createdSec));
        return u;
    }
}
