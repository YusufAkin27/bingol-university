package edu.bingol.bu_kampus

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import android.provider.CalendarContract.Calendars
import android.provider.CalendarContract.Events
import android.provider.CalendarContract.Reminders
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.TimeZone
import java.util.concurrent.Executors

/**
 * Cihaz takvimine yazma (kanal `bu_kampus/calendar`, Dart: lib/core/platform/device_calendar.dart).
 *
 * `CalendarContract` ile dogrudan yazar: izin (READ/WRITE_CALENDAR, calisma zamani), yazilabilir takvim listesi,
 * yerel "BU Kampus" takvimi, etkinlik ekle/guncelle (kimlikle), hatirlatici ve silme. Yalniz Dart'in verdigi
 * kimlikli etkinlige dokunulur; baska etkinlikler okunmaz/degistirilmez.
 *
 * Tum gun etkinlik: DTSTART/DTEND UTC gece yarisi, EVENT_TIMEZONE=UTC, DTEND ertesi gun (hakim kural). Hatirlatici
 * dakikasi gun basindan SONRA icin NEGATIF yazilir (-480 = o gun 08:00; Google Takvim'in "gun icinde saat X"
 * bildirimiyle ayni gosterim). Saatli etkinlikte hatirlatici dakikasi baslangictan ONCEKI pozitif sure.
 */
object BuCalendar {
    private const val CHANNEL = "bu_kampus/calendar"
    private const val REQ = 7731
    private const val PREFS = "bu_calendar"
    private const val DAY_MS = 86_400_000L

    private var pending: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()

    fun register(messenger: BinaryMessenger, activity: Activity) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "access" -> result.success(status(activity))
                "requestAccess" -> requestAccess(activity, result)
                "calendars" -> background(activity, result) { calendars(activity) }
                "createCalendar" -> background(activity, result) { createCalendar(activity, call.argument<String>("name") ?: "BU Kampus") }
                "upsertEvent" -> background(activity, result) { upsertEvent(activity, call) }
                "deleteEvent" -> background(activity, result) { deleteEvent(activity, call) }
                else -> result.notImplemented()
            }
        }
    }

    /** MainActivity.onRequestPermissionsResult'tan cagrilir. */
    fun onRequestPermissionsResult(activity: Activity, requestCode: Int) {
        if (requestCode != REQ) return
        val r = pending ?: return
        pending = null
        r.success(status(activity))
    }

    private fun background(activity: Activity, result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            val out = try {
                block()
            } catch (_: Exception) {
                null // SecurityException, IllegalArgumentException...
            }
            activity.runOnUiThread { result.success(out) }
        }
    }

    // ------------------------------------------------------------------------------------------------- izin

    private fun has(activity: Activity, p: String) =
        activity.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun granted(activity: Activity) =
        has(activity, Manifest.permission.READ_CALENDAR) && has(activity, Manifest.permission.WRITE_CALENDAR)

    /** granted | notDetermined (sorulabilir) | denied (kalici red: yalniz Ayarlar'dan). */
    private fun status(activity: Activity): String {
        if (granted(activity)) return "granted"
        val asked = activity.getSharedPreferences(PREFS, 0).getBoolean("asked", false)
        val canAsk = activity.shouldShowRequestPermissionRationale(Manifest.permission.READ_CALENDAR) ||
            activity.shouldShowRequestPermissionRationale(Manifest.permission.WRITE_CALENDAR)
        return if (asked && !canAsk) "denied" else "notDetermined"
    }

    private fun requestAccess(activity: Activity, result: MethodChannel.Result) {
        if (granted(activity) || status(activity) == "denied") {
            result.success(status(activity))
            return
        }
        if (pending != null) {
            result.success(status(activity))
            return
        }
        pending = result
        activity.getSharedPreferences(PREFS, 0).edit().putBoolean("asked", true).apply()
        activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR), REQ)
    }

    // --------------------------------------------------------------------------------------------- takvimler

    private fun calendars(activity: Activity): List<Map<String, Any>> {
        val cr = activity.contentResolver
        val out = mutableListOf<Map<String, Any>>()
        fun read(withPrimary: Boolean): Boolean {
            val proj = mutableListOf(
                Calendars._ID, Calendars.CALENDAR_DISPLAY_NAME, Calendars.ACCOUNT_NAME, Calendars.ACCOUNT_TYPE,
                Calendars.CALENDAR_ACCESS_LEVEL, Calendars.VISIBLE
            )
            if (withPrimary) proj.add("isPrimary")
            val cursor = try {
                cr.query(Calendars.CONTENT_URI, proj.toTypedArray(), null, null, null)
            } catch (_: IllegalArgumentException) {
                // "isPrimary" sutunu yoksa sutunsuz yeniden denenir.
                return false
            }
            if (cursor == null) return true
            cursor.use {
                while (it.moveToNext()) {
                    val level = it.getInt(4)
                    if (level < Calendars.CAL_ACCESS_CONTRIBUTOR || it.getInt(5) != 1) continue
                    out.add(
                        mapOf(
                            "id" to it.getLong(0).toString(),
                            "name" to (it.getString(1) ?: ""),
                            "account" to (it.getString(2) ?: ""),
                            "local" to (it.getString(3) == CalendarContract.ACCOUNT_TYPE_LOCAL),
                            "primary" to (withPrimary && it.getInt(6) == 1)
                        )
                    )
                }
            }
            return true
        }
        if (!read(true)) read(false)
        return out.sortedByDescending { it["primary"] as Boolean }
    }

    private const val LOCAL_ACCOUNT = "BU Kampus"

    /** Yerel takvim ("BU Kampus" hesabi, hesap turu LOCAL); varsa yenisini acmaz. Kimligi dondurur. */
    private fun createCalendar(activity: Activity, name: String): String? {
        val cr = activity.contentResolver
        cr.query(
            Calendars.CONTENT_URI, arrayOf(Calendars._ID),
            "${Calendars.ACCOUNT_NAME}=? AND ${Calendars.ACCOUNT_TYPE}=?",
            arrayOf(LOCAL_ACCOUNT, CalendarContract.ACCOUNT_TYPE_LOCAL), null
        )?.use { if (it.moveToFirst()) return it.getLong(0).toString() }
        val uri = Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(Calendars.ACCOUNT_NAME, LOCAL_ACCOUNT)
            .appendQueryParameter(Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            .build()
        val v = ContentValues().apply {
            put(Calendars.ACCOUNT_NAME, LOCAL_ACCOUNT)
            put(Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(Calendars.NAME, "bu_kampus")
            put(Calendars.CALENDAR_DISPLAY_NAME, name)
            put(Calendars.CALENDAR_COLOR, 0xFFDC4C46.toInt())
            put(Calendars.CALENDAR_ACCESS_LEVEL, Calendars.CAL_ACCESS_OWNER)
            put(Calendars.OWNER_ACCOUNT, LOCAL_ACCOUNT)
            put(Calendars.VISIBLE, 1)
            put(Calendars.SYNC_EVENTS, 1)
            put(Calendars.CALENDAR_TIME_ZONE, "Europe/Istanbul")
        }
        val created = cr.insert(uri, v) ?: return null
        return ContentUris.parseId(created).toString()
    }

    // ---------------------------------------------------------------------------------------------- etkinlik

    private fun utcMidnight(day: String): Long {
        val p = day.split("-")
        val c = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        c.clear()
        c.set(p[0].toInt(), p[1].toInt() - 1, p[2].toInt())
        return c.timeInMillis
    }

    /** Etkinlik bu takvimde duruyor ve silinmemis mi. */
    private fun exists(activity: Activity, eventId: Long, calId: Long): Boolean {
        activity.contentResolver.query(
            ContentUris.withAppendedId(Events.CONTENT_URI, eventId),
            arrayOf(Events._ID, Events.CALENDAR_ID, Events.DELETED), null, null, null
        )?.use { return it.moveToFirst() && it.getLong(1) == calId && it.getInt(2) != 1 }
        return false
    }

    private fun upsertEvent(activity: Activity, call: MethodCall): Map<String, Any>? {
        val cr = activity.contentResolver
        val calId = call.argument<String>("calendarId")?.toLongOrNull() ?: return null
        val title = call.argument<String>("title") ?: return null
        val allDay = call.argument<Boolean>("allDay") ?: true
        val v = ContentValues().apply {
            put(Events.TITLE, title)
            put(Events.DESCRIPTION, call.argument<String>("notes") ?: "")
            put(Events.AVAILABILITY, Events.AVAILABILITY_FREE)
            if (allDay) {
                val s = utcMidnight(call.argument<String>("startDay") ?: return null)
                val e = utcMidnight(call.argument<String>("endDay") ?: return null)
                put(Events.ALL_DAY, 1)
                put(Events.DTSTART, s)
                put(Events.DTEND, maxOf(e, s) + DAY_MS)
                put(Events.EVENT_TIMEZONE, "UTC")
            } else {
                val s = call.argument<Number>("startMs")?.toLong() ?: return null
                val e = call.argument<Number>("endMs")?.toLong() ?: (s + 3_600_000L)
                put(Events.ALL_DAY, 0)
                put(Events.DTSTART, s)
                put(Events.DTEND, e)
                put(Events.EVENT_TIMEZONE, call.argument<String>("tz") ?: "Europe/Istanbul")
            }
        }
        // Hatirlatici dakikasi: tum gunde gun basindan SONRA = negatif; saatlide baslangictan ONCE = pozitif.
        val minutes: Int? = if (allDay) {
            call.argument<Number>("alarmDayMin")?.toInt()?.let { -it }
        } else {
            val at = call.argument<Number>("alarmAtMs")?.toLong()
            val s = call.argument<Number>("startMs")?.toLong()
            if (at != null && s != null) ((s - at) / 60_000L).toInt().coerceAtLeast(0) else null
        }
        v.put(Events.HAS_ALARM, if (minutes != null) 1 else 0)

        val eventId = call.argument<String>("eventId")?.toLongOrNull()
        if (eventId != null && exists(activity, eventId, calId)) {
            cr.update(ContentUris.withAppendedId(Events.CONTENT_URI, eventId), v, null, null)
            replaceReminder(activity, eventId, minutes)
            return mapOf("id" to eventId.toString(), "created" to false)
        }
        v.put(Events.CALENDAR_ID, calId)
        val uri = cr.insert(Events.CONTENT_URI, v) ?: return null
        val id = ContentUris.parseId(uri)
        replaceReminder(activity, id, minutes)
        return mapOf("id" to id.toString(), "created" to true)
    }

    private fun replaceReminder(activity: Activity, eventId: Long, minutes: Int?) {
        val cr = activity.contentResolver
        cr.delete(Reminders.CONTENT_URI, "${Reminders.EVENT_ID}=?", arrayOf(eventId.toString()))
        if (minutes == null) return
        val r = ContentValues().apply {
            put(Reminders.EVENT_ID, eventId)
            put(Reminders.MINUTES, minutes)
            put(Reminders.METHOD, Reminders.METHOD_ALERT)
        }
        cr.insert(Reminders.CONTENT_URI, r)
    }

    /** Yalniz verilen takvimdeki etkinligi siler. Silindi ya da zaten yoksa true. */
    private fun deleteEvent(activity: Activity, call: MethodCall): Boolean {
        val calId = call.argument<String>("calendarId")?.toLongOrNull() ?: return false
        val eventId = call.argument<String>("eventId")?.toLongOrNull() ?: return false
        if (!exists(activity, eventId, calId)) return true
        return activity.contentResolver.delete(ContentUris.withAppendedId(Events.CONTENT_URI, eventId), null, null) > 0
    }
}
