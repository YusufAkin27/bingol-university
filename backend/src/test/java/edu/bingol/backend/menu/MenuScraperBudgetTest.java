package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.junit.jupiter.api.Test;

/** T-074 (A2-18): yavas damlayan kaynak site toplam sure butcesini asarsa IOException (-> markMaintenance). */
class MenuScraperBudgetTest {

    @Test
    void slowSourceIsCutAtTotalBudget() {
        CountDownLatch never = new CountDownLatch(1);
        long t0 = System.nanoTime();
        IOException e = assertThrows(IOException.class, () -> MenuScraper.getWithin(() -> {
            never.await(30, TimeUnit.SECONDS);
            return Jsoup.parse("<p/>");
        }, 200));
        assertTrue((System.nanoTime() - t0) / 1_000_000 < 5_000);
        assertTrue(e.getMessage().contains("butce"));
    }

    @Test
    void fastSourcePassesThroughAndIoErrorsAreUnwrapped() throws Exception {
        Document d = MenuScraper.getWithin(() -> Jsoup.parse("<p>x</p>"), 5_000);
        assertEquals("x", d.text());
        IOException e = assertThrows(IOException.class, () -> MenuScraper.getWithin(() -> {
            throw new IOException("down");
        }, 5_000));
        assertEquals("down", e.getMessage());
    }
}
