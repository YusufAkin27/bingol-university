package edu.bingol.bu_kampus

import android.app.Activity
import android.app.Application
import android.os.Bundle

/** Tracks visibility before the Flutter engine is ready; foreground pushes use the in-app card only. */
class BuApplication : Application(), Application.ActivityLifecycleCallbacks {
    companion object { @Volatile var foreground = false; private set }
    private var started = 0
    override fun onCreate() { super.onCreate(); registerActivityLifecycleCallbacks(this); Channels.ensure(this) }
    override fun onActivityStarted(activity: Activity) { started++; foreground = true }
    override fun onActivityStopped(activity: Activity) { started = (started - 1).coerceAtLeast(0); foreground = started > 0 }
    override fun onActivityCreated(activity: Activity, state: Bundle?) {}
    override fun onActivityResumed(activity: Activity) {}
    override fun onActivityPaused(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) {}
    override fun onActivityDestroyed(activity: Activity) {}
}
