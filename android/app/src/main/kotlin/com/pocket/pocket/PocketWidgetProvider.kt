package com.pocket.pocket

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
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
                    val mainIntent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        setData(Uri.parse("pocket://home"))
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val mainPendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        mainIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                    )
                    setOnClickPendingIntent(R.id.widget_root, mainPendingIntent)

                    // Quick Add button -> open instant quick-add popup
                    val quickAddIntent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        setData(Uri.parse("pocket://quick-add"))
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val quickAddPendingIntent = PendingIntent.getActivity(
                        context,
                        101,
                        quickAddIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                    )
                    setOnClickPendingIntent(R.id.btn_quick_add, quickAddPendingIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }
}
