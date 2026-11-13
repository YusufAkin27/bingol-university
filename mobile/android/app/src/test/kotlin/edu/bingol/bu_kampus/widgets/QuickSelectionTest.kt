package edu.bingol.bu_kampus.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Hizli Erisim kisayol secimi: kodlama, hesap baglami, modele uygulama. Android bagimsiz. */
class QuickSelectionTest {
    private fun model(): QuickModel {
        val items = QuickSelection.ALL_IDS.map { QuickItem(it, "search", it.uppercase(), null, "bukampus://$it") }
        return QuickModel(items, items.take(4), Strs(null), "bukampus://home")
    }

    @Test fun sanitizeDropsUnknownAndDuplicates() {
        assertEquals(listOf("qr", "menu"), QuickSelection.sanitize(listOf("qr", "x", "menu", "qr")))
    }

    @Test fun encodeDecodeRoundTrip() {
        val raw = QuickSelection.encode("42", listOf("chat", "menu"))
        val sel = QuickSelection.decode(raw)!!
        assertEquals("42", sel.owner)
        assertEquals(listOf("chat", "menu"), sel.ids)
        val unbound = QuickSelection.decode(QuickSelection.encode("", listOf("news")))!!
        assertEquals("", unbound.owner)
    }

    @Test fun decodeRejectsBrokenOrEmpty() {
        assertNull(QuickSelection.decode(null))
        assertNull(QuickSelection.decode(""))
        assertNull(QuickSelection.decode("nopipe"))
        assertNull(QuickSelection.decode("1|"))
        assertNull(QuickSelection.decode("1|bogus,other"))
    }

    @Test fun ownerFromMeta() {
        assertEquals("7", QuickSelection.ownerOf("""{"signedIn":true,"ownerUserId":7}"""))
        assertEquals("", QuickSelection.ownerOf("""{"signedIn":false,"ownerUserId":7}"""))
        assertEquals("", QuickSelection.ownerOf(null))
        assertEquals("", QuickSelection.ownerOf("{bozuk"))
    }

    @Test fun explicitSignOutOnly() {
        assertTrue(QuickSelection.explicitlySignedOut("""{"signedIn":false}"""))
        assertFalse(QuickSelection.explicitlySignedOut("""{"signedIn":true}"""))
        assertFalse(QuickSelection.explicitlySignedOut("""{"schema":1}"""))
        assertFalse(QuickSelection.explicitlySignedOut(null))
        assertFalse(QuickSelection.explicitlySignedOut("{bozuk"))
    }

    @Test fun accountContext() {
        val own = QuickSelection.encode("7", listOf("menu", "qr"))
        assertEquals(QuickSelection.Action.USE, QuickSelection.resolve(own, "7").action)
        // baska hesap: yok say + sil
        val other = QuickSelection.resolve(own, "8")
        assertEquals(QuickSelection.Action.DROP, other.action)
        assertNull(other.ids)
        // oturumsuzken yapilan secim ilk oturumlu hesaba baglanir
        val unbound = QuickSelection.encode("", listOf("chat"))
        val bind = QuickSelection.resolve(unbound, "9")
        assertEquals(QuickSelection.Action.BIND, bind.action)
        assertEquals(listOf("chat"), bind.ids)
        // sahip bilinmiyorsa dokunma
        assertEquals(QuickSelection.Action.USE, QuickSelection.resolve(own, "").action)
        assertEquals(QuickSelection.Action.NONE, QuickSelection.resolve(null, "7").action)
    }

    @Test fun applyKeepsSelectionOrderAndSmallIsFirstFour() {
        val m = QuickSelection.apply(model(), listOf("search", "menu", "qr", "chat", "news"))
        assertEquals(listOf("search", "menu", "qr", "chat", "news"), m.items.map { it.id })
        assertEquals(listOf("search", "menu", "qr", "chat"), m.small.map { it.id })
    }

    @Test fun applyWithFewerThanFourShowsOnlyThose() {
        val m = QuickSelection.apply(model(), listOf("qr", "menu"))
        assertEquals(listOf("qr", "menu"), m.items.map { it.id })
        assertEquals(listOf("qr", "menu"), m.small.map { it.id })
    }

    @Test fun applyIgnoresIdsMissingFromSnapshotAndFallsBack() {
        val base = model()
        assertEquals(base.items.size, QuickSelection.apply(base, listOf("zzz")).items.size)
        val partial = QuickModel(base.items.take(2), base.items.take(2), Strs(null), null)
        assertEquals(listOf("menu"), QuickSelection.apply(partial, listOf("qr", "menu")).items.map { it.id })
    }
}
