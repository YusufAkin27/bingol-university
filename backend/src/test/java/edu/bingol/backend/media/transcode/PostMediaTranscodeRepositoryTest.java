package edu.bingol.backend.media.transcode;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.post.media.PostMedia;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;

/** Kuyruk sorgulari H2'de (JPQL): sahiplenme atomik, hata sayaci, bayat isler, sifreleme gocu. */
@SpringBootTest
class PostMediaTranscodeRepositoryTest {

    @Autowired
    PostMediaTranscodeRepository repo;

    PostMedia video(String key, String status, boolean encrypted) {
        PostMedia m = new PostMedia();
        m.setOwnerId(1L);
        m.setKind(PostMedia.VIDEO);
        m.setStorageKey(key + "-" + System.nanoTime() + ".mp4");
        m.setContentType("video/mp4");
        m.setBytes(10);
        m.setTranscodeStatus(status);
        m.setEncrypted(encrypted);
        return repo.save(m);
    }

    PostMedia reload(PostMedia m) {
        return repo.findById(m.getId()).orElseThrow();
    }

    @Test
    void claimIsAtomicOnlyOneWinner() {
        PostMedia m = video("c", "PENDING", true);
        assertEquals(1, repo.claim(m.getId(), Instant.now()));
        assertEquals(0, repo.claim(m.getId(), Instant.now()), "ikinci sahiplenme kaybeder");
        assertEquals("PROCESSING", reload(m).getTranscodeStatus());
    }

    @Test
    void pendingIdsListsOnlyPendingVideosInOrder() {
        PostMedia a = video("p1", "PENDING", true);
        PostMedia b = video("p2", "PENDING", true);
        video("d", "DONE", true);
        video("n", null, true);
        List<Long> ids = repo.pendingIds(PageRequest.of(0, 1000));
        assertTrue(ids.contains(a.getId()) && ids.contains(b.getId()));
        assertTrue(ids.indexOf(a.getId()) < ids.indexOf(b.getId()));
        assertEquals(1, repo.pendingIds(PageRequest.of(0, 1)).size(), "sayfa boyutu `workers` sinirini uygular");
    }

    @Test
    void failRetriesThenGivesUp() {
        PostMedia m = video("f", "PROCESSING", true);
        assertEquals(1, repo.fail(m.getId(), 2, Instant.now()));
        PostMedia r1 = reload(m);
        assertEquals("PENDING", r1.getTranscodeStatus());
        assertEquals(1, r1.getTranscodeAttempts());
        repo.claim(m.getId(), Instant.now());
        repo.fail(m.getId(), 2, Instant.now());
        PostMedia r2 = reload(m);
        assertEquals("FAILED", r2.getTranscodeStatus());
        assertEquals(2, r2.getTranscodeAttempts());
        assertEquals(0, repo.fail(m.getId(), 2, Instant.now()), "PROCESSING degilken sayac artmaz");
    }

    @Test
    void completeOnlyFromProcessingAndStaleJobsReturnToQueue() {
        PostMedia m = video("x", "PENDING", true);
        assertEquals(0, repo.complete(m.getId(), "new.mp4", "k1:abc", 5L, 1000, 640, 360, "sha", null, Instant.now()),
                "PROCESSING degilse tamamlanmaz");
        repo.claim(m.getId(), Instant.now().minus(Duration.ofHours(2)));
        assertEquals(1, repo.resetStale(Instant.now().minus(Duration.ofMinutes(30))));
        assertEquals("PENDING", reload(m).getTranscodeStatus());
        repo.claim(m.getId(), Instant.now());
        assertEquals(1, repo.complete(m.getId(), "new.mp4", "k1:abc", 5L, 1000, 640, 360, "sha", "new-t.jpg", Instant.now()));
        PostMedia d = reload(m);
        assertEquals("DONE", d.getTranscodeStatus());
        assertEquals("new.mp4", d.getStorageKey());
        assertEquals("k1:abc", d.getWrappedDek());
        assertEquals(640, d.getWidth());
        assertEquals("new-t.jpg", d.getThumbKey());
        assertTrue(d.isEncrypted());
    }

    @Test
    void sealedWithKeyFindsByMasterKeyIdAndResealIsGuarded() {
        PostMedia m = video("k", null, true);
        m.setWrappedDek("zz9:abcdef");
        repo.save(m);
        assertTrue(repo.sealedWithKey("zz9:%", PageRequest.of(0, 10)).contains(m.getId()));
        assertFalse(repo.sealedWithKey("zz8:%", PageRequest.of(0, 10)).contains(m.getId()));
        assertEquals(0, repo.reseal(m.getId(), m.getStorageKey(), "baska", "n.mp4", "k2:q", null), "eski DEK uyusmuyor");
        assertEquals(1, repo.reseal(m.getId(), m.getStorageKey(), "zz9:abcdef", "n.mp4", "k2:q", null));
        assertFalse(repo.sealedWithKey("zz9:%", PageRequest.of(0, 10)).contains(m.getId()));
    }

    @Test
    void plainVideosAreFoundAndSealedOnce() {
        PostMedia plain = video("legacy", null, false);
        video("sealed", null, true);
        video("queued", "PENDING", false);
        List<Long> ids = repo.plainVideoIds(PageRequest.of(0, 1000));
        assertTrue(ids.contains(plain.getId()));
        assertFalse(ids.stream().anyMatch(id -> "PENDING".equals(reload(repo.findById(id).orElseThrow()).getTranscodeStatus())),
                "kuyruktakilere dokunulmaz");
        assertEquals(1, repo.sealExisting(plain.getId(), plain.getStorageKey(), "n.mp4", "k1:z", null));
        assertEquals(0, repo.sealExisting(plain.getId(), plain.getStorageKey(), "n2.mp4", "k1:y", null),
                "ikinci kez: zaten sifreli");
        PostMedia r = reload(plain);
        assertTrue(r.isEncrypted());
        assertEquals("n.mp4", r.getStorageKey());
    }
}
