package edu.bingol.bu_kampus.widgets

import android.content.Context

/** [QuickSelection] icin SharedPreferences (HomeWidgetPreferences) yazma/okuma; hata disari sizmaz. */
internal object QuickSelectionStore {
    private fun prefs(ctx: Context) = ctx.getSharedPreferences(WidgetTokens.PREFS_NAME, Context.MODE_PRIVATE)

    fun save(ctx: Context, appWidgetId: Int, ids: List<String>) {
        try {
            val p = prefs(ctx)
            val owner = QuickSelection.ownerOf(p.getString(WidgetTokens.KEY_META, null))
            p.edit().putString(QuickSelection.key(appWidgetId), QuickSelection.encode(owner, ids)).apply()
        } catch (_: Throwable) {
        }
    }

    fun load(ctx: Context, appWidgetId: Int): List<String>? = try {
        QuickSelection.decode(prefs(ctx).getString(QuickSelection.key(appWidgetId), null))?.ids
    } catch (_: Throwable) {
        null
    }

    fun remove(ctx: Context, appWidgetIds: IntArray) {
        try {
            val e = prefs(ctx).edit()
            for (id in appWidgetIds) e.remove(QuickSelection.key(id))
            e.apply()
        } catch (_: Throwable) {
        }
    }

    /** Cizimde cagrilir: hesap baglamini uygular (cikis/hesap degisimi/ilk baglama) ve gecerli secimi doner. */
    fun effective(ctx: Context, appWidgetId: Int, metaRaw: String?): List<String>? {
        try {
            val p = prefs(ctx)
            if (QuickSelection.explicitlySignedOut(metaRaw)) {
                val e = p.edit()
                for (k in p.all.keys) if (k.startsWith(QuickSelection.PREFIX)) e.remove(k)
                e.apply()
                return null
            }
            val key = QuickSelection.key(appWidgetId)
            val owner = QuickSelection.ownerOf(metaRaw)
            val r = QuickSelection.resolve(p.getString(key, null), owner)
            when (r.action) {
                QuickSelection.Action.DROP -> p.edit().remove(key).apply()
                QuickSelection.Action.BIND -> p.edit().putString(key, QuickSelection.encode(owner, r.ids!!)).apply()
                else -> {}
            }
            return r.ids
        } catch (_: Throwable) {
            return null
        }
    }
}
