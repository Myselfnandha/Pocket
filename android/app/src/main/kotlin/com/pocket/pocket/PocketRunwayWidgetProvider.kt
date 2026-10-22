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
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PocketRunwayWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PEEK_RUNWAY_BALANCE = "com.pocket.pocket.ACTION_PEEK_RUNWAY_BALANCE"
        private val handler = Handler(Looper.getMainLooper())

        fun refreshAll(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val component = ComponentName(context, PocketRunwayWidgetProvider::class.java)
                val ids = appWidgetManager.getAppWidgetIds(component)
                if (ids != null && ids.isNotEmpty()) {
                    val widgetData = try {
                        es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
                    } catch (_: Exception) {
                        @Suppress("DEPRECATION")
                        android.preference.PreferenceManager.getDefaultSharedPreferences(context)
                    }
                    val provider = PocketRunwayWidgetProvider()
                    provider.onUpdate(context, appWidgetManager, ids, widgetData)
                }
            } catch (_: Exception) {}
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PEEK_RUNWAY_BALANCE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

            // Read preferences
            val prefs = try {
                es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            } catch (_: Exception) {
                @Suppress("DEPRECATION")
                android.preference.PreferenceManager.getDefaultSharedPreferences(context)
            }
            val rawBalance = prefs.getString("raw_runway_safe_daily", prefs.getString("raw_card_balance", "₹0.00")) ?: "₹0.00"
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
            val peekViews = RemoteViews(context.packageName, R.layout.pocket_runway_widget_layout).apply {
                setTextViewText(R.id.widget_safe_amount, rawBalance)
            }

            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                appWidgetManager.partiallyUpdateAppWidget(widgetId, peekViews)
            } else {
                val component = ComponentName(context, PocketRunwayWidgetProvider::class.java)
                val allIds = appWidgetManager.getAppWidgetIds(component)
                if (allIds != null && allIds.isNotEmpty()) {
                    appWidgetManager.partiallyUpdateAppWidget(allIds, peekViews)
                }
            }

            // Automatically re-mask back to dots after configured duration
            handler.removeCallbacksAndMessages(null)
            handler.postDelayed({
                val hideViews = RemoteViews(context.packageName, R.layout.pocket_runway_widget_layout).apply {
                    setTextViewText(R.id.widget_safe_amount, "••••••")
                }
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    appWidgetManager.partiallyUpdateAppWidget(widgetId, hideViews)
                } else {
                    val component = ComponentName(context, PocketRunwayWidgetProvider::class.java)
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
                val views = RemoteViews(context.packageName, R.layout.pocket_runway_widget_layout).apply {
                    val safeAmount = widgetData.getString("runway_safe_daily", "₹0.00") ?: "₹0.00"
                    val daysLeft = widgetData.getString("runway_days_left", "18d left") ?: "18d left"
                    val statusText = widgetData.getString("runway_status", "✓ ON TRACK") ?: "✓ ON TRACK"
                    val budgetLeft = widgetData.getString("runway_budget_left", "₹0.00 remaining") ?: "₹0.00 remaining"
                    val isPrivacy = widgetData.getBoolean("widget_privacy_mode", false) || safeAmount == "••••••"

                    val isCustomizationEnabled = widgetData.getBoolean("widget_customization_enabled", true)
                    val showBalance = if (isCustomizationEnabled) widgetData.getBoolean("widget_show_balance", true) else true
                    val showBudget = if (isCustomizationEnabled) widgetData.getBoolean("widget_show_budget_tag", true) else true
                    val showExpense = if (isCustomizationEnabled) widgetData.getBoolean("widget_show_today_expense", true) else true
                    val showQuickAdd = if (isCustomizationEnabled) widgetData.getBoolean("widget_show_expense_btn", true) else true
                    val widgetTheme = widgetData.getString("widget_theme", "glassFrost") ?: "glassFrost"

                    // Apply selected theme to background
                    val bgRes = when (widgetTheme) {
                        "oledBlack" -> R.drawable.widget_bg_oled_black
                        "midnightNavy" -> R.drawable.widget_bg_midnight_navy
                        else -> R.drawable.widget_bg_glass_frost
                    }
                    setInt(R.id.widget_root, "setBackgroundResource", bgRes)

                    setTextViewText(R.id.widget_safe_amount, safeAmount)
                    setTextViewText(R.id.widget_runway_days_left, daysLeft)
                    setTextViewText(R.id.widget_runway_status, statusText)
                    setTextViewText(R.id.widget_runway_budget_left, budgetLeft)

                    // Dynamic visibility for elements based on toggles
                    setViewVisibility(R.id.widget_safe_amount, if (showBalance) View.VISIBLE else View.GONE)
                    setViewVisibility(R.id.widget_runway_status, if (showBudget) View.VISIBLE else View.GONE)
                    setViewVisibility(R.id.widget_runway_budget_left, if (showExpense) View.VISIBLE else View.GONE)
                    setViewVisibility(R.id.btn_log_spend, if (showQuickAdd) View.VISIBLE else View.GONE)

                    // Root tap -> open budget screen
                    val budgetPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocket://budget")
                    )
                    setOnClickPendingIntent(R.id.widget_root, budgetPendingIntent)

                    // Safe amount tap: Peek balance if privacy is active; otherwise open budget
                    if (isPrivacy) {
                        val peekIntent = Intent(context, PocketRunwayWidgetProvider::class.java).apply {
                            action = ACTION_PEEK_RUNWAY_BALANCE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        }
                        val peekPendingIntent = PendingIntent.getBroadcast(
                            context,
                            widgetId * 10 + 3,
                            peekIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                        )
                        setOnClickPendingIntent(R.id.widget_safe_amount, peekPendingIntent)
                    } else {
                        setOnClickPendingIntent(R.id.widget_safe_amount, budgetPendingIntent)
                    }

                    // Log Spend button -> open instant floating quick-add HUD
                    val quickAddPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        QuickAddActivity::class.java,
                        Uri.parse("pocket://quick-add-dialog")
                    )
                    setOnClickPendingIntent(R.id.btn_log_spend, quickAddPendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }
}
