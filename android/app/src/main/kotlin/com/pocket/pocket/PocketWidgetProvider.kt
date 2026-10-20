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

class PocketWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PEEK_BALANCE = "com.pocket.pocket.ACTION_PEEK_BALANCE"
        private val handler = Handler(Looper.getMainLooper())
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PEEK_BALANCE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

            // Read preferences
            @Suppress("DEPRECATION")
            val prefs = android.preference.PreferenceManager.getDefaultSharedPreferences(context)
            val rawBalance = prefs.getString("raw_total_balance", prefs.getString("raw_card_balance", "₹0.00")) ?: "₹0.00"
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
            val peekViews = RemoteViews(context.packageName, R.layout.pocket_widget_layout).apply {
                setTextViewText(R.id.widget_total_balance, rawBalance)
            }

            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                appWidgetManager.partiallyUpdateAppWidget(widgetId, peekViews)
            } else {
                val component = ComponentName(context, PocketWidgetProvider::class.java)
                val allIds = appWidgetManager.getAppWidgetIds(component)
                if (allIds != null && allIds.isNotEmpty()) {
                    appWidgetManager.partiallyUpdateAppWidget(allIds, peekViews)
                }
            }

            // Automatically re-mask back to dots after configured duration
            handler.removeCallbacksAndMessages(null)
            handler.postDelayed({
                val hideViews = RemoteViews(context.packageName, R.layout.pocket_widget_layout).apply {
                    setTextViewText(R.id.widget_total_balance, "••••••")
                }
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    appWidgetManager.partiallyUpdateAppWidget(widgetId, hideViews)
                } else {
                    val component = ComponentName(context, PocketWidgetProvider::class.java)
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
                val views = RemoteViews(context.packageName, R.layout.pocket_widget_layout).apply {
                    val totalBalance = widgetData.getString("card_balance", widgetData.getString("total_balance", "₹0.00")) ?: "₹0.00"
                    val todayExpense = widgetData.getString("today_expense", "₹0.00 Today") ?: "₹0.00 Today"
                    val walletName = widgetData.getString("card_wallet_name", "Main Account") ?: "Main Account"
                    val budgetTag = widgetData.getString("budget_status_tag", "On Budget") ?: "On Budget"
                    val secondaryAction = widgetData.getString("secondary_action_type", "scan") ?: "scan"
                    val isPrivacy = widgetData.getBoolean("widget_privacy_mode", false) || totalBalance == "••••••"

                    setTextViewText(R.id.widget_total_balance, totalBalance)
                    setTextViewText(R.id.widget_today_expense, todayExpense)
                    setTextViewText(R.id.widget_card_wallet_name, walletName)
                    setTextViewText(R.id.widget_budget_tag, budgetTag)

                    if (secondaryAction == "voice") {
                        setTextViewText(R.id.txt_secondary_action, "🎙️ Voice")
                    } else {
                        setTextViewText(R.id.txt_secondary_action, "📸 Scan")
                    }

                    // Root tap -> open main app
                    val mainPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocket://home")
                    )
                    setOnClickPendingIntent(R.id.widget_root, mainPendingIntent)

                    // Balance tap: Peek balance if privacy is active; otherwise open app
                    if (isPrivacy) {
                        val peekIntent = Intent(context, PocketWidgetProvider::class.java).apply {
                            action = ACTION_PEEK_BALANCE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        }
                        val peekPendingIntent = PendingIntent.getBroadcast(
                            context,
                            widgetId * 10 + 2,
                            peekIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                        )
                        setOnClickPendingIntent(R.id.widget_total_balance, peekPendingIntent)
                    } else {
                        setOnClickPendingIntent(R.id.widget_total_balance, mainPendingIntent)
                    }

                    // Quick Add button -> open instant transparent floating quick-add popup
                    val quickAddPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        QuickAddActivity::class.java,
                        Uri.parse("pocket://quick-add-dialog")
                    )
                    setOnClickPendingIntent(R.id.btn_quick_add, quickAddPendingIntent)

                    // Secondary Action button (Scan / Voice)
                    val actionUri = if (secondaryAction == "voice") "pocket://voice" else "pocket://scan"
                    val secondaryPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse(actionUri)
                    )
                    setOnClickPendingIntent(R.id.btn_secondary_action, secondaryPendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }
}
