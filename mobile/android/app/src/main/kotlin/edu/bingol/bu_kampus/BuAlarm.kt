package edu.bingol.bu_kampus

import android.app.Activity
import android.content.Intent
import android.provider.AlarmClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Sistem Saat uygulamasina alarm yazar (kanal `bu_kampus/alarm`, Dart: lib/core/platform/device_alarm.dart).
 *
 * `AlarmClock.ACTION_SET_ALARM`: saat + dakika + etiket + (istege bagli) tekrar gunleri. Saat uygulamasi TARIH
 * bilmez; tekrarsiz alarm "bir sonraki o saat"te calar. Bu yuzden Dart tarafi tek seferlik alarmi yalniz 24 saat
 * icindeki bir ana kurar (bkz. alarm_planner.dart). `EXTRA_SKIP_UI` ile Saat arayuzu acilmadan sessiz kurulur.
 * Kurulan alarmi silme API'si yoktur; kullanici Saat uygulamasindan siler. Ek izin: `SET_ALARM` (normal izin).
 */
object BuAlarm {
    private const val CHANNEL = "bu_kampus/alarm"

    fun register(messenger: BinaryMessenger, activity: Activity) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(available(activity))
                "setAlarm" -> result.success(setAlarm(activity, call))
                // Android'de bildirim yedegi yoktur (alarmlar Saat uygulamasindadir).
                "cancelFallback" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }

    private fun available(activity: Activity): Boolean = try {
        Intent(AlarmClock.ACTION_SET_ALARM).resolveActivity(activity.packageManager) != null
    } catch (_: Exception) {
        false
    }

    private fun setAlarm(activity: Activity, call: MethodCall): Boolean {
        return try {
            val hour = call.argument<Int>("hour") ?: return false
            val minute = call.argument<Int>("minute") ?: return false
            if (hour !in 0..23 || minute !in 0..59) return false
            val label = (call.argument<String>("label") ?: "").take(60)
            val intent = Intent(AlarmClock.ACTION_SET_ALARM)
                .putExtra(AlarmClock.EXTRA_HOUR, hour)
                .putExtra(AlarmClock.EXTRA_MINUTES, minute)
                .putExtra(AlarmClock.EXTRA_MESSAGE, label)
                .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                .putExtra(AlarmClock.EXTRA_VIBRATE, true)
            // Calendar.DAY_OF_WEEK degerleri (1=Pazar..7=Cumartesi). Bos = tek seferlik.
            val days = call.argument<List<*>>("days")?.mapNotNull { (it as? Number)?.toInt() }?.filter { it in 1..7 }?.distinct()
            if (!days.isNullOrEmpty()) {
                intent.putIntegerArrayListExtra(AlarmClock.EXTRA_DAYS, ArrayList(days))
            }
            if (intent.resolveActivity(activity.packageManager) == null) return false
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            // ActivityNotFoundException, SecurityException...
            false
        }
    }
}
