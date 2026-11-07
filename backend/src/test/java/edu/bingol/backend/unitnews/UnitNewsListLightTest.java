package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.cache.TestCaches;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

/**
 * P07-B6: birim duyuru LISTESI govdeyi (body, 8000 karaktere kadar) okumaz; yalniz detay okur. Kullanici -> hedef
 * kaynak eslesmesi (bolum + fakulte + duzey uclusu) kullanicidan bagimsiz oldugundan onbellekli.
 */
class UnitNewsListLightTest {

    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final UserRepository users = mock(UserRepository.class);
    private final UnitSourceRepository sources = mock(UnitSourceRepository.class);
    private final UnitDepartmentRepository depts = mock(UnitDepartmentRepository.class);
    private final UnitNewsService service = new UnitNewsService(jdbc, users, sources, depts);

    private static User student(long id, String dept, String faculty) {
        User u = new User();
        u.setId(id);
        u.setDepartment(dept);
        u.setFaculty(faculty);
        return u;
    }

    @BeforeEach
    void wire() {
        UnitSource mmf = new UnitSource();
        mmf.setCode("mmf");
        mmf.setName("Mühendislik ve Mimarlık Fakültesi");
        mmf.setFacultyKeys("muhendislik ve mimarlik fakultesi");
        UnitDepartment cs = new UnitDepartment();
        cs.setSourceCode("mmf");
        cs.setSlug("bilgisayar-muhendisligi");
        cs.setName("Bilgisayar Mühendisliği");
        cs.setNameKey(UnitKeys.deptKey("Bilgisayar Mühendisliği"));
        cs.setFeedPath("/bolumler_/bilgisayar-muhendisligi/duyurular/");
        when(sources.findByEnabledTrueOrderByCodeAsc()).thenReturn(List.of(mmf));
        when(depts.findByNameKeyIn(any())).thenReturn(List.of(cs));
        for (long id = 1; id <= 3; id++) {
            when(users.findById(id)).thenReturn(Optional.of(student(id, "Bilgisayar Mühendisliği",
                    "Mühendislik ve Mimarlık Fakültesi")));
        }
        when(users.findById(9L)).thenReturn(Optional.of(student(9, "Bilgisayar Mühendisliği", null)));
    }

    @Test
    void listSqlDoesNotReadBodyButDetailDoes() {
        service.feed(1L, 20);
        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbc, atLeastOnce()).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        assertTrue(sql.getValue().contains("a.title"), sql.getValue());
        assertFalse(sql.getValue().contains("a.body"), "liste govde okumamali: " + sql.getValue());

        try {
            service.detail(1L, 5L);
        } catch (RuntimeException expected) {
            // bos sonuc -> 404; yalniz SQL'e bakiyoruz
        }
        verify(jdbc, times(2)).query(sql.capture(), any(RowMapper.class), any(Object[].class));
        assertTrue(sql.getValue().contains("a.body"), "detay govdeyi okur: " + sql.getValue());
    }

    @Test
    void targetResolutionIsCachedAcrossStudentsWithSameDepartmentAndFaculty() {
        service.setCache(TestCaches.create());
        var a = service.resolve(1L);
        var b = service.resolve(2L);
        var c = service.resolve(3L);
        assertEquals(a, b);
        assertEquals(a, c);
        assertEquals(2, a.size(), "genel akis + bolum akisi");
        verify(sources, times(1)).findByEnabledTrueOrderByCodeAsc();
        verify(depts, times(1)).findByNameKeyIn(any());
        // fakultesi farkli (bilinmeyen) kullanici ayri anahtar: ayri hesaplanir
        service.resolve(9L);
        verify(sources, times(2)).findByEnabledTrueOrderByCodeAsc();
    }

    @Test
    void sourceOrDepartmentChangeInvalidatesResolution() {
        var cache = TestCaches.create();
        service.setCache(cache);
        service.resolve(1L);
        cache.invalidate("unitnews");
        service.resolve(1L);
        verify(sources, times(2)).findByEnabledTrueOrderByCodeAsc();
    }
}
