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

class PocketCardWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PEEK_CARD_BALANCE = "com.pocket.pocket.ACTION_PEEK_CARD_BALANCE"
        private val handler = Handler(Looper.getMainLooper())
        private val revealedWidgets = java.util.concurrent.ConcurrentHashMap<Int, Boolean>()

        fun refreshAll(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val component = ComponentName(context, PocketCardWidgetProvider::class.java)
                val ids = appWidgetManager.getAppWidgetIds(component)
                if (ids != null && ids.isNotEmpty()) {
                    val widgetData = try {
                        es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
                    } catch (_: Exception) {
                        @Suppress("DEPRECATION")
                        android.preference.PreferenceManager.getDefaultSharedPreferences(context)
                    }
                    val provider = PocketCardWidgetProvider()
                    provider.onUpdate(context, appWidgetManager, ids, widgetData)
                }
            } catch (_: Exception) {}
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_PEEK_CARD_BALANCE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

            // Read preferences from HomeWidget data (with fallback to default preferences)
            val prefs = try {
                es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            } catch (_: Exception) {
                @Suppress("DEPRECATION")
                android.preference.PreferenceManager.getDefaultSharedPreferences(context)
            }

            // Toggle state for this widget
            val currentlyRevealed = revealedWidgets[widgetId] == true
            val nextRevealed = !currentlyRevealed
            revealedWidgets[widgetId] = nextRevealed

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

            val views = buildViews(context, prefs, widgetId, isRevealed = nextRevealed)
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                appWidgetManager.updateAppWidget(widgetId, views)
            } else {
                val component = ComponentName(context, PocketCardWidgetProvider::class.java)
                val allIds = appWidgetManager.getAppWidgetIds(component)
                if (allIds != null && allIds.isNotEmpty()) {
                    allIds.forEach { id ->
                        revealedWidgets[id] = nextRevealed
                        appWidgetManager.updateAppWidget(id, buildViews(context, prefs, id, isRevealed = nextRevealed))
                    }
                }
            }

            // Automatically re-mask back to dots after configured duration if revealed
            if (nextRevealed) {
                val durationSec = prefs.getInt("widget_peek_duration_seconds", 3)
                val durationMs = durationSec * 1000L
                handler.removeCallbacksAndMessages(null)
                handler.postDelayed({
                    revealedWidgets[widgetId] = false
                    val hiddenViews = buildViews(context, prefs, widgetId, isRevealed = false)
                    if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                        appWidgetManager.updateAppWidget(widgetId, hiddenViews)
                    } else {
                        val component = ComponentName(context, PocketCardWidgetProvider::class.java)
                        val allIds = appWidgetManager.getAppWidgetIds(component)
                        if (allIds != null && allIds.isNotEmpty()) {
                            allIds.forEach { id ->
                                revealedWidgets[id] = false
                                appWidgetManager.updateAppWidget(id, buildViews(context, prefs, id, isRevealed = false))
                            }
                        }
                    }
                }, durationMs)
            }
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
                val views = buildViews(context, widgetData, widgetId, isRevealed = false)
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }

    private fun buildViews(
        context: Context,
        widgetData: SharedPreferences,
        widgetId: Int,
        isRevealed: Boolean
    ): RemoteViews {
        return RemoteViews(context.packageName, R.layout.pocket_card_widget_layout).apply {
            val totalBalance = widgetData.getString("card_balance", widgetData.getString("total_balance", "₹0.00")) ?: "₹0.00"
            val rawBalance = widgetData.getString("raw_card_balance", widgetData.getString("raw_total_balance", totalBalance)) ?: totalBalance
            val todayExpense = widgetData.getString("today_expense", "₹0.00 Today") ?: "₹0.00 Today"
            val walletName = widgetData.getString("card_wallet_name", "Main Account") ?: "Main Account"
            val budgetTag = widgetData.getString("budget_status_tag", "On Budget") ?: "On Budget"
            val secondaryAction = widgetData.getString("secondary_action_type", "scan") ?: "scan"
            val isPrivacy = widgetData.getBoolean("widget_privacy_mode", false) || totalBalance == "••••••"
            val cardDigits = widgetData.getString("card_digits", "•••• 2026") ?: "•••• 2026"

            // Balance text & dedicated toggle button
            val displayBalance = if (isRevealed || !isPrivacy) rawBalance else "••••••"
            val toggleLabel = if (isRevealed) "👁️ Hide" else (if (isPrivacy) "👁️ View" else "👁️ Peek")

            setTextViewText(R.id.widget_total_balance, displayBalance)
            setTextViewText(R.id.txt_toggle_icon, toggleLabel)
            setTextViewText(R.id.widget_today_expense, todayExpense)
            setTextViewText(R.id.widget_card_wallet_name, walletName)
            setTextViewText(R.id.widget_budget_tag, budgetTag)
            setTextViewText(R.id.widget_card_digits, cardDigits)

            // Secondary action button text
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

            // Dedicated Space: btn_toggle_balance & widget_total_balance -> Peeks/Toggles balance without mistouch to open app
            val peekIntent = Intent(context, PocketCardWidgetProvider::class.java).apply {
                action = ACTION_PEEK_CARD_BALANCE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            val peekPendingIntent = PendingIntent.getBroadcast(
                context,
                widgetId * 10 + 1,
                peekIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            setOnClickPendingIntent(R.id.btn_toggle_balance, peekPendingIntent)
            setOnClickPendingIntent(R.id.widget_total_balance, peekPendingIntent)

            // 1-Tap Quick Add -> open lightweight transparent floating HUD
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
    }
}
