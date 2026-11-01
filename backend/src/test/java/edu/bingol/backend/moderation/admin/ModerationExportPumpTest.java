package edu.bingol.backend.moderation.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.moderation.ReportRepository;
import edu.bingol.backend.moderation.ReportTargetType;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.jpa.domain.Specification;

/** FIX-P05 (A05#9): CSV dokumu kimlik imecli parcalarla akar; her satir bir kez, yeniden eskiye, ust sinirda durur. */
@SpringBootTest
class ModerationExportPumpTest {

    @Autowired
    ReportRepository reports;

    private Long save(long reporter, long target) {
        Report r = new Report();
        r.setReporterId(reporter);
        r.setTargetType(ReportTargetType.USER);
        r.setTargetId(target);
        r.setReason(ReportReason.SPAM);
        return reports.saveAndFlush(r).getId();
    }

    @Test
    void streamsInDescendingIdChunksWithoutDuplicatesAndHonoursTheCap() {
        long target = 880_000L + (System.nanoTime() % 1000);
        List<Long> mine = new ArrayList<>();
        for (int i = 0; i < 25; i++) {
            mine.add(save(70_000L + i, target));
        }
        Specification<Report> onlyMine = (root, q, cb) -> cb.equal(root.get("targetId"), target);

        List<Long> seen = new ArrayList<>();
        int n = ModerationExportController.pump(reports, onlyMine, Report::getId, r -> seen.add(r.getId()), 7, 1000);

        assertEquals(25, n);
        assertEquals(25, seen.stream().distinct().count());
        for (int i = 1; i < seen.size(); i++) {
            assertTrue(seen.get(i - 1) > seen.get(i), "yeniden eskiye sirali");
        }

        List<Long> capped = new ArrayList<>();
        assertEquals(10, ModerationExportController.pump(reports, onlyMine, Report::getId, r -> capped.add(r.getId()), 4, 10));
        assertEquals(seen.subList(0, 10), capped);
    }
}
