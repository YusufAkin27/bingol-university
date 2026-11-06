package edu.bingol.bu_kampus.widgets

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.graphics.Color
import android.os.Bundle
import android.util.TypedValue
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONObject
import java.io.File

/**
 * YALNIZ DEBUG: widget'lari launcher'a ihtiyac duymadan gercek AppWidgetHostView ile 2x2 / 4x2 / 4x4 boyutlarinda cizer
 * (emulator ekran goruntusu dogrulamasi). Girdi: `adb shell am start -n .../.widgets.WidgetHostActivity --es slug menu`.
 * Fixture: <externalFilesDir>/widgets_fixture.json = {"bu_widget_meta": {...}, "bu_widget_menu": {...}, "debug_now": "ISO"}
 * degerleri HomeWidgetPreferences'a yazilir (hesap/sunucu gerekmez). Once: `adb shell cmd appwidget grantbind --package <id>`.
 * Release derlemesinde bu sinif YOKTUR (src/debug).
 */
class WidgetHostActivity : Activity() {
    private lateinit var host: AppWidgetHost
    private val ids = ArrayList<Int>()
    private var askedBind = false

    @Deprecated("debug")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 77) recreate()
    }

    private fun dp(v: Int): Int = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val slugName = intent.getStringExtra("slug") ?: "menu"
        val slug = WidgetSlug.values().firstOrNull { it.slug == slugName } ?: WidgetSlug.MENU
        val only = intent.getStringExtra("sizes") // "2x2,4x2,4x4"
        applyFixture()
        host = AppWidgetHost(this, 4242)
        val mgr = AppWidgetManager.getInstance(this)
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor(intent.getStringExtra("bg") ?: "#8C8C94"))
            setPadding(dp(12), dp(48), dp(12), dp(12))
        }
        val dims = listOf(Triple("2x2", 170, 170), Triple("4x2", 350, 170), Triple("4x4", 350, 350))
        val classes = WidgetProviders.bySlug[slug]!!
        dims.forEachIndexed { idx, (name, w, h) ->
            if (only != null && !only.split(",").contains(name)) return@forEachIndexed
            val id = host.allocateAppWidgetId()
            ids.add(id)
            val ok = mgr.bindAppWidgetIdIfAllowed(id, ComponentName(this, classes[idx]))
            val holder = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            if (!ok) {
                if (!askedBind) {
                    askedBind = true
                    // Sistem izin penceresi (bir kez "Her zaman izin ver"): sonraki acilislarda bind sessiz basarili olur.
                    startActivityForResult(
                        android.content.Intent(AppWidgetManager.ACTION_APPWIDGET_BIND)
                            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, ComponentName(this, classes[idx])), 77,
                    )
                }
                holder.addView(TextView(this).apply { text = "bind izni bekleniyor" })
            } else {
                val info = mgr.getAppWidgetInfo(id)
                val hv: AppWidgetHostView = host.createView(this, id, info)
                val lp = LinearLayout.LayoutParams(dp(w), dp(h))
                lp.topMargin = dp(8)
                holder.addView(hv, lp)
                val opts = Bundle().apply {
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, w)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, w)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, h)
                    putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, h)
                }
                mgr.updateAppWidgetOptions(id, opts)
                WidgetUpdater.update(this, mgr, slug, id, opts, SizeClass.SMALL)
            }
            col.addView(holder, ViewGroup.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        setContentView(ScrollView(this).apply { addView(col) })
    }

    private fun applyFixture() {
        try {
            val f = File(getExternalFilesDir(null), "widgets_fixture.json")
            if (!f.exists()) return
            val o = JSONObject(f.readText(Charsets.UTF_8))
            val ed = getSharedPreferences(WidgetTokens.PREFS_NAME, MODE_PRIVATE).edit()
            val keys = o.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val v = o.get(k)
                if (v == JSONObject.NULL) ed.remove(k) else ed.putString(k, if (v is JSONObject) v.toString() else v.toString())
            }
            ed.commit()
        } catch (_: Throwable) {
        }
    }

    override fun onStart() {
        super.onStart()
        host.startListening()
    }

    override fun onStop() {
        super.onStop()
        host.stopListening()
    }

    override fun onDestroy() {
        super.onDestroy()
        for (id in ids) host.deleteAppWidgetId(id)
    }
}
