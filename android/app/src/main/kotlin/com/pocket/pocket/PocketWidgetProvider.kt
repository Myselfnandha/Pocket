package com.pocket.pocket

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PocketWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.pocket_widget_layout).apply {
                    val totalBalance = widgetData.getString("total_balance", "₹0.00") ?: "₹0.00"
                    val todayExpense = widgetData.getString("today_expense", "₹0.00") ?: "₹0.00"
                    val currentDate = widgetData.getString("current_date", "Today") ?: "Today"
                    val accountsSummary = widgetData.getString("accounts_summary", "No active accounts") ?: "No active accounts"

                    setTextViewText(R.id.widget_total_balance, totalBalance)
                    setTextViewText(R.id.widget_today_expense, todayExpense)
                    setTextViewText(R.id.widget_date, currentDate)
                    setTextViewText(R.id.widget_accounts_summary, accountsSummary)

                    // Root tap -> open main app
                    val mainPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocket://home")
                    )
                    setOnClickPendingIntent(R.id.widget_root, mainPendingIntent)

                    // Quick Add button -> open instant transparent floating quick-add popup
                    val quickAddPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        QuickAddActivity::class.java,
                        Uri.parse("pocket://quick-add-dialog")
                    )
                    setOnClickPendingIntent(R.id.btn_quick_add, quickAddPendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }
}
