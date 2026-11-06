package edu.bingol.bu_kampus.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle

/** Saat: debug derlemede `bu_widget_debug_now` (ISO) ile gecersiz kilinabilir; release'de hep sistem saati. */
fun WidgetClock.nowMillis(ctx: Context): Long {
    if (WidgetRenderer.isDebuggable(ctx)) {
        try {
            val raw = ctx.getSharedPreferences(WidgetTokens.PREFS_NAME, Context.MODE_PRIVATE).getString("bu_widget_debug_now", null)
            parseIso(raw)?.let { return it }
        } catch (_: Throwable) {
        }
    }
    return System.currentTimeMillis()
}

/**
 * Tum widget saglayicilarinin ortak tabani. Her slug icin 3 saglayici (2x2/4x2/4x4) vardir; hepsi ayni cizimi yapar,
 * yerlesim sinifi gercek widget boyutuna gore secilir (yeniden boyutlandirinca degisir).
 * APPWIDGET_UPDATE (uygulama `HomeWidget.updateWidget` ile snapshot yazdiktan sonra) gelince slug'in TUM
 * saglayicilari yenilenir: kullanici yalniz 4x4'u eklemis olsa da (adli saglayici bos olsa da) guncellenir.
 */
abstract class BuWidgetReceiver(private val slug: WidgetSlug, private val defaultSize: SizeClass) : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            WidgetUpdater.updateSlug(context, slug)
            WidgetScheduler.schedule(context)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        WidgetUpdater.updateSlug(context, slug)
        WidgetScheduler.schedule(context)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        WidgetUpdater.update(context, appWidgetManager, slug, appWidgetId, newOptions, defaultSize)
    }

    override fun onEnabled(context: Context) = WidgetScheduler.schedule(context)

    override fun onDisabled(context: Context) = WidgetScheduler.schedule(context)
}

internal object WidgetUpdater {
    fun updateAll(context: Context) {
        for (slug in WidgetSlug.values()) updateSlug(context, slug)
    }

    fun updateSlug(context: Context, slug: WidgetSlug) {
        try {
            val mgr = AppWidgetManager.getInstance(context)
            val defaults = listOf(SizeClass.SMALL, SizeClass.MEDIUM, SizeClass.LARGE)
            WidgetProviders.bySlug[slug]?.forEachIndexed { idx, cls ->
                val ids = mgr.getAppWidgetIds(ComponentName(context, cls))
                for (id in ids) update(context, mgr, slug, id, mgr.getAppWidgetOptions(id), defaults[idx])
            }
        } catch (_: Throwable) {
            // widget guncellemesi cagirana exception sizdirmaz
        }
    }

    fun update(context: Context, mgr: AppWidgetManager, slug: WidgetSlug, id: Int, opts: Bundle?, def: SizeClass) {
        val land = context.resources.configuration.orientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE
        val w = opts?.getInt(if (land) AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        val h = opts?.getInt(if (land) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
        val cls = WidgetSizing.classify(w, h, def)
        val hh = if (h > 0) h else when (cls) { SizeClass.SMALL -> 170; SizeClass.MEDIUM -> 170; SizeClass.LARGE -> 350 }
        val rv = try {
            WidgetRenderer.render(context, slug, cls, hh)
        } catch (_: Throwable) {
            WidgetRenderer.fallback(context)
        }
        try {
            mgr.updateAppWidget(id, rv)
        } catch (_: Throwable) {
        }
    }
}

/**
 * Zamanlanmis yenileme (uygulama kapaliyken): gece 00:05, menu 12:00/18:00, ders baslangic/bitisleri.
 * Tek esnek alarm (setAndAllowWhileIdle: kesin alarm izni ISTENMEZ, sistem biraz kaydirabilir). Ayrica
 * `updatePeriodMillis` 30 dk. Alarm her guncellemede yeniden kurulur; acilista/guncellemede WidgetRefreshReceiver kurar.
 */
internal object WidgetScheduler {
    private const val ACTION = "edu.bingol.bu_kampus.widgets.REFRESH"

    fun schedule(context: Context) {
        try {
            val mgr = AppWidgetManager.getInstance(context)
            var any = false
            for ((_, list) in WidgetProviders.bySlug) for (cls in list) {
                if (mgr.getAppWidgetIds(ComponentName(context, cls)).isNotEmpty()) any = true
            }
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pi = pending(context)
            if (!any) {
                am.cancel(pi)
                return
            }
            val now = WidgetClock.nowMillis(context)
            val at = nextBoundary(context, now)
            // sistem saatiyle hizala (debug saat gecersiz kilindiginde bile gelecekte)
            val delta = (at - now).coerceIn(60_000L, 24L * 3_600_000L)
            am.setAndAllowWhileIdle(AlarmManager.RTC, System.currentTimeMillis() + delta, pi)
        } catch (_: Throwable) {
        }
    }

    private fun pending(context: Context): PendingIntent {
        val i = Intent(context, WidgetRefreshReceiver::class.java).setAction(ACTION)
        return PendingIntent.getBroadcast(context, 0, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    /** Bir sonraki sinir: yerel gece 00:05, 12:00, 18:00 ya da bugunku bir dersin baslangic/bitis dakikasi. */
    private fun nextBoundary(context: Context, nowMs: Long): Long {
        val nowMin = WidgetClock.minuteOfDay(nowMs)
        val marks = ArrayList<Int>()
        marks.add(12 * 60); marks.add(18 * 60)
        try {
            val prefs = context.getSharedPreferences(WidgetTokens.PREFS_NAME, Context.MODE_PRIVATE)
            val snap = parseObject(prefs.getString(WidgetTokens.KEY_TIMETABLE, null))
            if (snap != null && snap.str("date") == WidgetClock.dateKey(nowMs)) {
                for (l in snap.arr("lessons").objs()) {
                    l.int("startMin")?.let { marks.add(it) }
                    l.int("endMin")?.let { marks.add(it) }
                }
            }
        } catch (_: Throwable) {
        }
        val next = marks.filter { it > nowMin }.minOrNull()
        val minutesUntil = if (next != null) next - nowMin else (24 * 60 - nowMin) + 5
        return nowMs + minutesUntil * 60_000L
    }
}

/** Alarm + acilis (BOOT_COMPLETED / paket guncelleme / saat degisimi): tum widget'lari yeniler ve alarmi yeniden kurar. */
class WidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            WidgetUpdater.updateAll(context)
            WidgetScheduler.schedule(context)
        } catch (_: Throwable) {
        }
    }
}
