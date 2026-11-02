package edu.bingol.backend.analytics.usage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class UsageBucketsTest {

    @Test
    void sqlCaseCoversAllBucketsInOrder() {
        String sql = UsageBuckets.sqlCase("ms");
        assertTrue(sql.startsWith("CASE WHEN ms < 1000 THEN 0 WHEN ms < 2000 THEN 1"), sql);
        assertTrue(sql.endsWith("ELSE 10 END"), sql);
        assertEquals(11, UsageBuckets.COUNT);
    }

    @Test
    void medianInterpolatesInsideBucket() {
        long[] c = new long[UsageBuckets.COUNT];
        c[3] = 10; // 5-10 sn
        assertEquals(7_500, UsageBuckets.medianMs(c), 0.001);
    }

    @Test
    void medianSpansBuckets() {
        long[] c = new long[UsageBuckets.COUNT];
        c[0] = 5; // 0-1 sn
        c[1] = 5; // 1-2 sn: medyan iki kovanin sinirinda
        assertEquals(1_000, UsageBuckets.medianMs(c), 0.001);
    }

    @Test
    void medianWithoutDataIsNegative() {
        assertEquals(-1, UsageBuckets.medianMs(new long[UsageBuckets.COUNT]), 0);
    }
}
