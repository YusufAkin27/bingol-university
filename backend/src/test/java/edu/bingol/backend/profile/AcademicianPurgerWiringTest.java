package edu.bingol.backend.profile;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.academician.AcademicianAccountPurger;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

/** Hesap silme akisi akademisyen alani temizleyicisini cagirir (genel AccountDataPurger baglantisi). */
class AcademicianPurgerWiringTest {

    @Test
    void accountPurgeDelegatesToTheAcademicianPurger() {
        AccountDataPurger purger = new AccountDataPurger(mock(JdbcTemplate.class));
        AcademicianAccountPurger academician = mock(AcademicianAccountPurger.class);
        purger.setAcademicianPurger(academician);

        purger.purge(42L);

        verify(academician).purge(42L);
    }
}
