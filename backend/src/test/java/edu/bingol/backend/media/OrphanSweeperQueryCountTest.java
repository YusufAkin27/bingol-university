package edu.bingol.backend.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.storage.LocalFileStorage;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * FIX-P03 (A02#10, A10#8): gece yetim taramasi dosya basina 7 sorgu atiyordu (indekssiz tam tablo taramasi).
 * Artik referanslar sutun basina TEK sorguyla bellege alinir; sorgu sayisi dosya sayisindan bagimsizdir.
 */
class OrphanSweeperQueryCountTest {

    @TempDir
    Path dir;

    @Test
    void queryCountDoesNotDependOnFileCount() throws Exception {
        MediaProperties props = ImageFixtures.props();
        ImageProcessor processor = new ImageProcessor(props);
        LocalFileStorage storage = new LocalFileStorage(new StorageProperties(dir.toString()), processor, props);
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        List<String> keep = new ArrayList<>();
        Path avatars = storage.root().resolve("avatars");
        Files.createDirectories(avatars);
        for (int i = 0; i < 40; i++) {
            String name = String.format("%040d.jpg", i);
            Path f = avatars.resolve(name);
            Files.write(f, new byte[] {1, 2, 3});
            Files.setLastModifiedTime(f, FileTime.from(java.time.Instant.now().minus(Duration.ofDays(30))));
            if (i % 2 == 0) {
                keep.add("/files/avatars/" + name);
            }
        }
        when(jdbc.queryForList(anyString(), eq(String.class))).thenReturn(keep);
        ColumnMediaReferenceSource source = new ColumnMediaReferenceSource(jdbc, props);
        MediaService media = new MediaService(processor, storage, props, List.of(source));

        int deleted = new MediaOrphanSweeper(storage, media, props).sweepOnce();

        assertEquals(20, deleted, "yarisi referansli: yalniz yetimler silinir");
        // kaynak sutun sayisi kadar toplu sorgu; dosya basina COUNT yok
        verify(jdbc, times(ColumnMediaReferenceSource.DEFAULTS.size())).queryForList(anyString(), eq(String.class));
        verify(jdbc, never()).queryForObject(anyString(), eq(Integer.class), any(Object[].class));
        assertTrue(Files.exists(avatars.resolve(String.format("%040d.jpg", 0))));
        assertFalse(Files.exists(avatars.resolve(String.format("%040d.jpg", 1))));
    }

    @Test
    void failedSnapshotFallsBackToPerFileCheckAndNeverDeletesWhenUnsure() throws Exception {
        MediaProperties props = ImageFixtures.props();
        ImageProcessor processor = new ImageProcessor(props);
        LocalFileStorage storage = new LocalFileStorage(new StorageProperties(dir.toString()), processor, props);
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        when(jdbc.queryForList(anyString(), eq(String.class))).thenThrow(new IllegalStateException("db down"));
        when(jdbc.queryForObject(anyString(), eq(Integer.class), any(Object[].class)))
                .thenThrow(new IllegalStateException("db down"));
        Path avatars = storage.root().resolve("avatars");
        Files.createDirectories(avatars);
        Path f = avatars.resolve(String.format("%040d.jpg", 5));
        Files.write(f, new byte[] {1});
        Files.setLastModifiedTime(f, FileTime.from(java.time.Instant.now().minus(Duration.ofDays(30))));
        MediaService media = new MediaService(processor, storage, props,
                List.of(new ColumnMediaReferenceSource(jdbc, props)));

        assertEquals(0, new MediaOrphanSweeper(storage, media, props).sweepOnce());
        assertTrue(Files.exists(f), "emin olunamiyorsa dosya silinmez");
    }
}
