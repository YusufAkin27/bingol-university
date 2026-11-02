package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;

import edu.bingol.backend.unitnews.UnitNewsService.Target;
import java.util.List;
import org.junit.jupiter.api.Test;

/** "Bolumunuzde yeni duyuru": bir duyuru hangi hedef grubuna uyar (genel akis kaynaga, bolum akisi yalniz o bolume). */
class UnitNewsNotifierTest {

    private static UnitAnnouncement ann(String source, String slug) {
        UnitAnnouncement a = new UnitAnnouncement();
        a.setSourceCode(source);
        a.setDeptSlug(slug);
        return a;
    }

    @Test
    void deptFeedMatchesOnlyThatDepartmentAndCarriesItsName() {
        Target general = new Target("muh", null, null);
        Target dept = new Target("muh", "bilgisayar", "Bilgisayar Mühendisliği");
        UnitNewsNotifier.Group g = new UnitNewsNotifier.Group(List.of(general, dept));

        assertSame(dept, g.match(ann("muh", "bilgisayar")));
        assertNull(g.match(ann("muh", "elektrik")), "baska bolumun akisi bu kullaniciya gitmez");
        assertNull(g.match(ann("fen", "bilgisayar")), "baska kaynak");
    }

    @Test
    void generalFeedMatchesAnyTargetOfThatSourceAndHasNoDeptLabel() {
        Target dept = new Target("muh", "bilgisayar", "Bilgisayar Mühendisliği");
        UnitNewsNotifier.Group g = new UnitNewsNotifier.Group(List.of(new Target("muh", null, null), dept));
        Target hit = g.match(ann("muh", null));
        assertEquals("muh", hit.sourceCode());
        assertNull(hit.unitName());
    }

    @Test
    void groupWithoutTargetsMatchesNothing() {
        assertNull(new UnitNewsNotifier.Group(List.of()).match(ann("muh", null)));
    }

    @Test
    void perUserCapIsThree() {
        assertEquals(3, UnitNewsNotifier.MAX_PER_USER);
    }
}
