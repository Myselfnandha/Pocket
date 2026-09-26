package com.pocket.pocket

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PocketRunwayWidgetProvider : HomeWidgetProvider() {
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

                    setTextViewText(R.id.widget_safe_amount, safeAmount)
                    setTextViewText(R.id.widget_runway_days_left, daysLeft)
                    setTextViewText(R.id.widget_runway_status, statusText)
                    setTextViewText(R.id.widget_runway_budget_left, budgetLeft)

                    // Root tap -> open budget screen
                    val budgetPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocket://budget")
                    )
                    setOnClickPendingIntent(R.id.widget_root, budgetPendingIntent)

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
