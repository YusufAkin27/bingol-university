package edu.bingol.backend.devseed;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

class DevSeedProdGuardTest {

    @Test
    void prodWithSeedProfileRefusesToStart() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod", "seed");
        assertThrows(IllegalStateException.class, () -> new DevSeedProdGuard(env));
    }

    @Test
    void prodWithoutSeedIsFine() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        assertDoesNotThrow(() -> new DevSeedProdGuard(env));
    }
}
