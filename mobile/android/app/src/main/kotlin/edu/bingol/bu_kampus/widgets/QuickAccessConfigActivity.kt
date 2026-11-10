package edu.bingol.bu_kampus.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import edu.bingol.bu_kampus.R

/**
 * Hizli Erisim widget'i yapilandirma ekrani (AppWidget configure activity). Widget eklenirken (ve Android 12+
 * "reconfigurable" ile sonradan) acilir: 8 kisayoldan hangileri gorunsun + sira (yukari/asagi).
 *
 * Gizlilik: ekranda KISISEL VERI YOKTUR; yalniz sabit kisayol adlari (kaynak metinleri) gosterilir, snapshot okunmaz.
 * Sonuc: RESULT_OK + EXTRA_APPWIDGET_ID yalnizca Kaydet'te; geri/iptal = widget eklenmez (RESULT_CANCELED).
 * Secim [QuickSelectionStore]'a yazilir (cihaza ve widget ornegine ozel; hesap baglami icin bkz. [QuickSelection]).
 */
class QuickAccessConfigActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val order = ArrayList<String>()
    private val checked = HashSet<String>()
    private lateinit var list: LinearLayout

    private fun label(id: String): String = getString(
        when (id) {
            "menu" -> R.string.bw_qa_menu
            "timetable" -> R.string.bw_qa_timetable
            "events" -> R.string.bw_qa_events
            "clubs" -> R.string.bw_qa_clubs
            "chat" -> R.string.bw_qa_chat
            "qr" -> R.string.bw_qa_qr
            "news" -> R.string.bw_qa_news
            else -> R.string.bw_qa_search
        },
    )

    private fun color(id: Int) = resources.getColor(id, theme)

    private fun dp(v: Int) = (v * resources.displayMetrics.density + 0.5f).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED) // varsayilan: iptal -> widget eklenmez
        appWidgetId = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val saved = savedInstanceState?.getStringArrayList(STATE_ORDER)
        val savedChecked = savedInstanceState?.getStringArrayList(STATE_CHECKED)
        if (saved != null && savedChecked != null) {
            order.addAll(QuickSelection.sanitize(saved))
            checked.addAll(savedChecked)
        } else {
            val current = QuickSelectionStore.load(this, appWidgetId) ?: QuickSelection.ALL_IDS
            order.addAll(current)
            checked.addAll(current)
        }
        for (id in QuickSelection.ALL_IDS) if (id !in order) order.add(id) // secilmeyenler sona

        build()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putStringArrayList(STATE_ORDER, ArrayList(order))
        outState.putStringArrayList(STATE_CHECKED, ArrayList(checked))
    }

    private fun build() {
        val bg = color(R.color.bu_widget_bg)
        val t1 = color(R.color.bu_widget_text1)
        val t2 = color(R.color.bu_widget_text2)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(bg)
            setPadding(dp(20), dp(24), dp(20), dp(16))
        }
        root.addView(TextView(this).apply {
            text = getString(R.string.bw_qa_cfg_title)
            setTextColor(t1)
            textSize = 20f
        })
        root.addView(TextView(this).apply {
            text = getString(R.string.bw_qa_cfg_hint)
            setTextColor(t2)
            textSize = 14f
            setPadding(0, dp(6), 0, dp(12))
        })
        list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(
            ScrollView(this).apply { addView(list) },
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f),
        )
        val save = Button(this).apply {
            text = getString(R.string.bw_qa_cfg_save)
            setTextColor(color(R.color.bu_widget_inverse_fg))
            background = GradientDrawable().apply {
                setColor(color(R.color.bu_widget_inverse_bg))
                cornerRadius = dp(12).toFloat()
            }
            minimumHeight = dp(48)
            setOnClickListener { save() }
        }
        root.addView(save, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)).apply { topMargin = dp(12) })
        setContentView(root)
        renderRows()
    }

    private fun renderRows() {
        list.removeAllViews()
        val t1 = color(R.color.bu_widget_text1)
        order.forEachIndexed { index, id ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                minimumHeight = dp(52)
            }
            row.addView(
                CheckBox(this).apply {
                    text = label(id)
                    setTextColor(t1)
                    textSize = 16f
                    isChecked = id in checked
                    setOnCheckedChangeListener { _, on -> if (on) checked.add(id) else checked.remove(id) }
                },
                LinearLayout.LayoutParams(0, dp(52), 1f),
            )
            row.addView(moveButton("▲", getString(R.string.bw_qa_cfg_up), index > 0) { swap(index, index - 1) })
            row.addView(moveButton("▼", getString(R.string.bw_qa_cfg_down), index < order.size - 1) { swap(index, index + 1) })
            list.addView(row)
        }
    }

    private fun moveButton(glyph: String, desc: String, enabled: Boolean, onClick: () -> Unit): View =
        TextView(this).apply {
            text = glyph
            textSize = 18f
            gravity = Gravity.CENTER
            contentDescription = desc
            setTextColor(if (enabled) color(R.color.bu_widget_text1) else color(R.color.bu_widget_border))
            isEnabled = enabled
            isClickable = enabled
            layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
            if (enabled) setOnClickListener { onClick() }
        }

    private fun swap(a: Int, b: Int) {
        val t = order[a]; order[a] = order[b]; order[b] = t
        renderRows()
    }

    private fun save() {
        val ids = order.filter { it in checked }
        if (ids.isEmpty()) {
            Toast.makeText(this, getString(R.string.bw_qa_cfg_min), Toast.LENGTH_SHORT).show()
            return
        }
        QuickSelectionStore.save(this, appWidgetId, ids)
        // Ilk cizimi yapilandirma ekrani yapar (belge: configure activity sonucu donmeden once widget'i gunceller).
        WidgetUpdater.updateSlug(this, WidgetSlug.QUICKACCESS)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
        finish()
    }

    private companion object {
        const val STATE_ORDER = "order"
        const val STATE_CHECKED = "checked"
    }
}
