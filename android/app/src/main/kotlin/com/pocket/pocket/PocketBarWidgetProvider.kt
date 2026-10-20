package com.pocket.pocket

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PocketBarWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PEEK_BAR_BALANCE = "com.pocket.pocket.ACTION_PEEK_BAR_BALANCE"
        private val handler = Handler(Looper.getMainLooper())
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PEEK_BAR_BALANCE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

            // Read preferences
            @Suppress("DEPRECATION")
            val prefs = android.preference.PreferenceManager.getDefaultSharedPreferences(context)
            val rawBalance = prefs.getString("raw_total_balance", "₹0.00") ?: "₹0.00"
            val durationSec = prefs.getInt("widget_peek_duration_seconds", 2)
            val durationMs = durationSec * 1000L

            // Gentle haptic feedback
            try {
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator?.vibrate(VibrationEffect.createOneShot(25, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(25)
                }
            } catch (_: Exception) {}

            // Reveal real balance temporarily
            val peekViews = RemoteViews(context.packageName, R.layout.pocket_bar_widget_layout).apply {
                setTextViewText(R.id.widget_bar_balance, rawBalance)
            }

            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                appWidgetManager.partiallyUpdateAppWidget(widgetId, peekViews)
            } else {
                val component = ComponentName(context, PocketBarWidgetProvider::class.java)
                val allIds = appWidgetManager.getAppWidgetIds(component)
                if (allIds != null && allIds.isNotEmpty()) {
                    appWidgetManager.partiallyUpdateAppWidget(allIds, peekViews)
                }
            }

            // Automatically re-mask back to dots after configured duration
            handler.removeCallbacksAndMessages(null)
            handler.postDelayed({
                val hideViews = RemoteViews(context.packageName, R.layout.pocket_bar_widget_layout).apply {
                    setTextViewText(R.id.widget_bar_balance, "••••••")
                }
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    appWidgetManager.partiallyUpdateAppWidget(widgetId, hideViews)
                } else {
                    val component = ComponentName(context, PocketBarWidgetProvider::class.java)
                    val allIds = appWidgetManager.getAppWidgetIds(component)
                    if (allIds != null && allIds.isNotEmpty()) {
                        appWidgetManager.partiallyUpdateAppWidget(allIds, hideViews)
                    }
                }
            }, durationMs)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.pocket_bar_widget_layout).apply {
                    val barBalance = widgetData.getString("total_balance", "₹0.00") ?: "₹0.00"
                    val isPrivacy = widgetData.getBoolean("widget_privacy_mode", false) || barBalance == "••••••"

                    setTextViewText(R.id.widget_bar_balance, barBalance)

                    // Balance pill tap -> open main app or peek
                    val mainPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocket://home")
                    )
                    setOnClickPendingIntent(R.id.widget_root, mainPendingIntent)

                    if (isPrivacy) {
                        val peekIntent = Intent(context, PocketBarWidgetProvider::class.java).apply {
                            action = ACTION_PEEK_BAR_BALANCE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        }
                        val peekPendingIntent = PendingIntent.getBroadcast(
                            context,
                            widgetId * 10 + 4,
                            peekIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                        )
                        setOnClickPendingIntent(R.id.btn_bar_balance, peekPendingIntent)
                    } else {
                        setOnClickPendingIntent(R.id.btn_bar_balance, mainPendingIntent)
                    }

                    // 1. Add button -> open instant floating quick-add HUD
                    val quickAddPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        QuickAddActivity::class.java,
                        Uri.parse("pocket://quick-add-dialog")
                    )
                    setOnClickPendingIntent(R.id.btn_bar_add, quickAddPendingIntent)

                    // 2. Scan button -> open receipt scanner
                    val scanPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocket://scan")
                    )
                    setOnClickPendingIntent(R.id.btn_bar_scan, scanPendingIntent)

                    // 3. Voice button -> open voice/NLP input
                    val voicePendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocket://voice")
                    )
                    setOnClickPendingIntent(R.id.btn_bar_voice, voicePendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }
}
