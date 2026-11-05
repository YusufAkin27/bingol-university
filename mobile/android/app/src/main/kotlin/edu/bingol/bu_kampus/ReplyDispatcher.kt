package edu.bingol.bu_kampus

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONObject

/**
 * Satir ici yanitin DAYANIKLI gonderimi. Tasarim karari (rapor): erisim/yenileme jetonlari Dart tarafinda (flutter_secure_storage,
 * tek kullanimlik refresh rotasyonu) yonetilir; native HTTP jeton okuyamaz ve kendi basina yenileyemez. Bu yuzden yanit
 *  1) kalici yerel kuyruga yazilir (ReplyStore, sabit `clientId` = idempotency anahtari),
 *  2) canli Flutter motoru varsa ona verilir (ekran acilmaz),
 *  3) yoksa JobScheduler isi (ag kisiti, hizli baslatma) BASLIKSIZ bir Dart motoru acar (`pushReplyMain`) ve mevcut
 *     PushActions yolunu (ApiClient + oturum) kullanir; basarisizlikta ustel geri cekilmeyle (15 sn, 1 dk, 5 dk, 30 dk, 2 sa)
 *     yeniden denenir. 5 denemeden ya da kesin hatadan sonra "dokunarak gonder" bildirimine duser. 6 saatten eski yanit gonderilmez.
 * Mantik: ReplyQueueLogic (saf, testli). Bu sinif Android/Flutter'a baglidir: DERLENMEDI/CIHAZDA DENENMEDI notu raporda.
 */
object ReplyDispatcher {
    private const val TAG = "RichPush"
    private const val JOB_ID = 7301
    private val worker = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)

    private fun dataOf(json: String): Map<String, String> = try {
        val o = JSONObject(json)
        o.keys().asSequence().associateWith { o.optString(it) }
    } catch (_: Exception) {
        emptyMap()
    }

    /** Yuk (veri) icinden bildirimi yeniden cizmeye yetecek alanlari alir (metin = son mesaj). */
    private fun trimmed(data: Map<String, String>): String {
        val keep = setOf("title", "body", "style", "type", "subtype", "conversationId", "conversationType", "conversationTitle",
            "senderName", "senderId", "messageId", "tag", "collapseKey", "channelId", "locale", "recipientId", "targetType", "targetId",
            "hidePreview")
        val o = JSONObject()
        data.forEach { (k, v) -> if (k in keep && v.length <= 600) o.put(k, v) }
        return o.toString()
    }

    /**
     * RemoteInput yaniti: kuyruga yazar, bildirimi "gonderiliyor" durumuna alir, gonderimi baslatir. Alicinin zamani kisadir:
     * canli motor varsa onunla kisa sureli denenir, yoksa is zamanlanir ve alici hemen biter.
     */
    fun submit(context: Context, data: Map<String, String>, text: String, tag: String, pending: BroadcastReceiver.PendingResult?) {
        val app = context.applicationContext
        val conversation = data["conversationId"]
        if (conversation.isNullOrBlank() || text.isBlank() || text.length > ReplyQueueLogic.MAX_TEXT) {
            RichPushNotifications.refresh(app, tag)
            try { pending?.finish() } catch (_: Throwable) { }
            return
        }
        val now = System.currentTimeMillis()
        val entry = ReplyEntry(
            clientId = UUID.randomUUID().toString(), tag = tag, conversationId = conversation,
            replyToMessageId = data["messageId"]?.takeIf { it.isNotBlank() }, text = text.trim(),
            recipientId = data["recipientId"]?.takeIf { it.isNotBlank() }, dataJson = trimmed(data), createdMs = now
        )
        ReplyStore.mutate(app) { ReplyQueueLogic.enqueue(it, entry, now) }
        RichPushNotifications.showChatState(app, dataOf(entry.dataJson), tag, ChatStatus.SENDING, entry)
        val live = RichPushNotifications.actionBridge != null
        if (live) {
            // Motor yasiyor: hizli yol. Alici suresini asmamak icin is parcacigi; bitince PendingResult kapanir.
            flush(app) { ran -> if (ran) rescheduleIfNeeded(app); try { pending?.finish() } catch (_: Throwable) { } }
        } else {
            schedule(app, 0)
            try { pending?.finish() } catch (_: Throwable) { }
        }
    }

    /**
     * Zamani gelmis kuyruk kayitlarini sirayla gonderir (tek seferde tek akis). [done]: calisti mi (false = baska akis zaten
     * calisiyor; o akis bitince kuyrugu yeniden degerlendirir, bu yuzden cagiran yeniden zamanlamaz).
     */
    fun flush(app: Context, done: (Boolean) -> Unit) {
        if (!running.compareAndSet(false, true)) { done(false); return }
        worker.execute {
            try {
                val now = System.currentTimeMillis()
                // Bayat kayitlar atilir; kullaniciya bildirim zaten "gonderilemedi" duruma dusmustur.
                ReplyStore.mutate(app) { ReplyQueueLogic.prune(it, now) }
                val due = ReplyQueueLogic.due(ReplyStore.snapshot(app), now)
                if (due.isNotEmpty()) deliver(app, due)
            } catch (error: Throwable) {
                android.util.Log.w(TAG, "Reply flush failed: " + error.javaClass.simpleName)
            } finally {
                running.set(false)
                try { done(true) } catch (_: Throwable) { }
            }
        }
    }

    private fun deliver(app: Context, due: List<ReplyEntry>) {
        val results = ConcurrentHashMap<String, ReplyOutcome>()
        if (RichPushNotifications.actionBridge != null) {
            due.forEach { results[it.clientId] = liveSend(it) }
        } else if (BuApplication.foreground) {
            // Uygulama acik ama motor koprusu hazir degil: cift motor acmayiz; kisa sure sonra yeniden denenir.
            due.forEach { results[it.clientId] = ReplyOutcome.RETRY }
        } else {
            HeadlessReply.sendAll(app, due, results)
        }
        for (entry in due) {
            val outcome = results[entry.clientId] ?: ReplyOutcome.RETRY
            val updated = ReplyStore.mutate(app) { ReplyQueueLogic.apply(it, entry.clientId, outcome, System.currentTimeMillis()) }
            val current = updated.firstOrNull { it.clientId == entry.clientId }
            val data = dataOf(entry.dataJson)
            when {
                outcome == ReplyOutcome.OK -> RichPushNotifications.dismiss(app, entry.tag)
                current != null && current.state == ReplyState.FAILED -> RichPushNotifications.replyFailedFor(app, data, entry)
                else -> RichPushNotifications.showChatState(app, data, entry.tag, ChatStatus.RETRYING, entry)
            }
        }
    }

    /** Canli Flutter motoruna verir (ana is parcacigi) ve sonucu bekler; zaman asimi/hata = RETRY. */
    private fun liveSend(entry: ReplyEntry): ReplyOutcome {
        val latch = CountDownLatch(1)
        val outcome = AtomicReference(ReplyOutcome.RETRY)
        Handler(Looper.getMainLooper()).post {
            try {
                val bridge = RichPushNotifications.actionBridge
                val payload = mapOf(
                    "notificationAction" to "reply", "notificationTag" to entry.tag, "actionId" to entry.clientId,
                    "conversationId" to entry.conversationId, "replyText" to entry.text
                ) + (entry.replyToMessageId?.let { mapOf("messageId" to it) } ?: emptyMap()) +
                    (entry.recipientId?.let { mapOf("recipientId" to it) } ?: emptyMap())
                val handed = bridge != null && bridge(payload) { ok ->
                    if (ok) outcome.set(ReplyOutcome.OK)
                    latch.countDown()
                }
                if (!handed) latch.countDown()
            } catch (_: Throwable) {
                latch.countDown()
            }
        }
        try { latch.await(15, TimeUnit.SECONDS) } catch (_: InterruptedException) { }
        return outcome.get()
    }

    /** Kuyrukta zamani gelecek/gelmis kayit varsa is zamanlar (ayni kimlik: onceki zamanlama yer degistirir). */
    fun rescheduleIfNeeded(app: Context) {
        try {
            val now = System.currentTimeMillis()
            val wake = ReplyQueueLogic.nextWake(ReplyStore.snapshot(app)) ?: return
            schedule(app, (wake - now).coerceAtLeast(0))
        } catch (error: Throwable) {
            android.util.Log.w(TAG, "Reply reschedule failed: " + error.javaClass.simpleName)
        }
    }

    private fun schedule(app: Context, delayMs: Long) {
        val scheduler = app.getSystemService(JobScheduler::class.java) ?: return
        val component = ComponentName(app, ReplyRetryJobService::class.java)
        fun build(rich: Boolean): JobInfo {
            val b = JobInfo.Builder(JOB_ID, component).setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            if (rich) b.setPersisted(true)
            if (delayMs > 0) b.setMinimumLatency(delayMs)
            else if (rich && Build.VERSION.SDK_INT >= 31) b.setExpedited(true)
            return b.build()
        }
        try {
            scheduler.schedule(build(true))
        } catch (_: Throwable) {
            // Kisit/izin uyumsuzlugu (ornegin kalici is ya da hizli is kotasi): sade ise dus.
            try { scheduler.schedule(build(false)) } catch (error: Throwable) {
                android.util.Log.w(TAG, "Reply job schedule failed: " + error.javaClass.simpleName)
            }
        }
    }

    fun cancelAll(app: Context) {
        try { app.getSystemService(JobScheduler::class.java)?.cancel(JOB_ID) } catch (_: Throwable) { }
        ReplyStore.clear(app)
    }
}

/** JobScheduler isi: ag varken kuyruktaki yanitlari gonderir (basliksiz Dart motoru) ve gerekirse sonrakini zamanlar. */
class ReplyRetryJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        val app = applicationContext
        ReplyDispatcher.flush(app) { ran ->
            try { jobFinished(params, false) } catch (_: Throwable) { }
            if (ran) ReplyDispatcher.rescheduleIfNeeded(app)
        }
        return true
    }

    // Sistem isi durdurursa kalan kayitlar kuyrukta kalir; yeniden zamanlanir.
    override fun onStopJob(params: JobParameters): Boolean {
        ReplyDispatcher.rescheduleIfNeeded(applicationContext)
        return false
    }
}

/**
 * Uygulama kapaliyken Dart `pushReplyMain` giris noktasini calistiran basliksiz motor. Kanal: `bu_kampus/push_reply_bg`
 * (Dart "ready" der, native "send" ile her yaniti verir; Dart "ok" | "retry" | "fail" doner). Hatada/zaman asiminda RETRY.
 */
internal object HeadlessReply {
    private const val CHANNEL = "bu_kampus/push_reply_bg"
    private const val TIMEOUT_MS = 40_000L

    fun sendAll(app: Context, entries: List<ReplyEntry>, results: MutableMap<String, ReplyOutcome>) {
        val main = Handler(Looper.getMainLooper())
        val finished = CountDownLatch(1)
        val engineRef = AtomicReference<FlutterEngine?>(null)
        val queue = ConcurrentLinkedQueue(entries)

        fun parse(value: Any?): ReplyOutcome = when (value) {
            "ok" -> ReplyOutcome.OK
            "fail" -> ReplyOutcome.FAIL
            else -> ReplyOutcome.RETRY
        }

        main.post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(app)
                loader.ensureInitializationCompleteAsync(app, null, main) {
                    try {
                        val engine = FlutterEngine(app)
                        engineRef.set(engine)
                        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                        fun next() {
                            val e = queue.poll()
                            if (e == null) { finished.countDown(); return }
                            val args = hashMapOf<String, Any?>(
                                "clientId" to e.clientId, "conversationId" to e.conversationId,
                                "replyToMessageId" to e.replyToMessageId, "text" to e.text, "recipientId" to e.recipientId
                            )
                            channel.invokeMethod("send", args, object : MethodChannel.Result {
                                override fun success(result: Any?) { results[e.clientId] = parse(result); next() }
                                override fun error(code: String, message: String?, details: Any?) { results[e.clientId] = ReplyOutcome.RETRY; next() }
                                override fun notImplemented() { results[e.clientId] = ReplyOutcome.RETRY; next() }
                            })
                        }
                        channel.setMethodCallHandler { call, result ->
                            if (call.method == "ready") { result.success(null); next() } else result.notImplemented()
                        }
                        engine.dartExecutor.executeDartEntrypoint(
                            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "pushReplyMain")
                        )
                    } catch (error: Throwable) {
                        android.util.Log.w("RichPush", "Headless engine start failed: " + error.javaClass.simpleName)
                        finished.countDown()
                    }
                }
            } catch (error: Throwable) {
                android.util.Log.w("RichPush", "Headless engine init failed: " + error.javaClass.simpleName)
                finished.countDown()
            }
        }
        try { finished.await(TIMEOUT_MS, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { }
        // Jeton yazimi (yenileme) Dart tarafinda biter; motor ancak sonra kapatilir.
        main.post {
            try { engineRef.getAndSet(null)?.destroy() } catch (_: Throwable) { }
        }
    }
}
