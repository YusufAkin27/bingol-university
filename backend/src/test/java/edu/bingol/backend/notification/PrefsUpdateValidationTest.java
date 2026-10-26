package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.notification.dto.NotificationDtos.PrefsUpdate;
import edu.bingol.backend.notification.dto.NotificationDtos.QuietHoursView;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.Test;

/** Ic ice quietHours alani da dogrulanmali: "25:99" gibi saatler 400 olmali (eskiden sessizce kabul ediliyordu). */
class PrefsUpdateValidationTest {

    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();

    private static PrefsUpdate withQuiet(String start, String end) {
        return new PrefsUpdate(null, null, null, null, null, new QuietHoursView(true, start, end, "UTC"), null);
    }

    @Test
    void gecersizSaatReddedilir() {
        assertTrue(!validator.validate(withQuiet("25:99", "06:30")).isEmpty());
        assertTrue(!validator.validate(withQuiet("23:00", "7:5")).isEmpty());
    }

    @Test
    void gecerliSaatKabulEdilir() {
        assertEquals(0, validator.validate(withQuiet("23:00", "06:30")).size());
    }
}
