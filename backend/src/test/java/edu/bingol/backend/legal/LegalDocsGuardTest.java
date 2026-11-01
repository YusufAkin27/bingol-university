package edu.bingol.backend.legal;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.opentest4j.AssertionFailedError;
import org.opentest4j.TestAbortedException;

class LegalDocsGuardTest {

    @Test
    void presentDocsAlwaysPass() {
        assertThatCode(() -> LegalDocsGuard.require(true, "x", true)).doesNotThrowAnyException();
        assertThatCode(() -> LegalDocsGuard.require(true, "x", false)).doesNotThrowAnyException();
    }

    @Test
    void missingDocsFailInStrictMode() {
        assertThatThrownBy(() -> LegalDocsGuard.require(false, "docs/legal yok", true))
                .isInstanceOf(AssertionFailedError.class)
                .hasMessageContaining("docs/legal yok");
    }

    @Test
    void missingDocsSkipInLocalMode() {
        assertThatThrownBy(() -> LegalDocsGuard.require(false, "docs/legal yok", false))
                .isInstanceOf(TestAbortedException.class);
    }
}
