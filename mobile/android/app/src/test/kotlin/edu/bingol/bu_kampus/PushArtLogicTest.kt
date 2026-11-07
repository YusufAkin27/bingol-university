package edu.bingol.bu_kampus

import org.junit.Assert.assertEquals
import org.junit.Test

/** Varsayilan avatar bas harfi (saf mantik). */
class PushArtLogicTest {
    @Test fun usesTurkishUppercase() {
        assertEquals("İ", PushArt.initialOf("ilker"))
        assertEquals("A", PushArt.initialOf("  ali veli"))
    }

    @Test fun skipsLeadingSymbolsAndHandlesEmpty() {
        assertEquals("Z", PushArt.initialOf("~ zeynep"))
        assertEquals("", PushArt.initialOf("   "))
        assertEquals("", PushArt.initialOf(""))
    }
}
