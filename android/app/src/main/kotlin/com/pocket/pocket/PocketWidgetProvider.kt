package com.pocket.pocket

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
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
            val views = RemoteViews(context.packageName, R.layout.pocket_widget_layout).apply {
                val totalBalance = widgetData.getString("total_balance", "₹0.00")
                val todayExpense = widgetData.getString("today_expense", "₹0.00")
                val currentDate = widgetData.getString("current_date", "Today")

                setTextViewText(R.id.widget_total_balance, totalBalance)
                setTextViewText(R.id.widget_today_expense, todayExpense)
                setTextViewText(R.id.widget_date, currentDate)

                // Root tap -> open main app
                val mainIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("pocket://home")
                )
                setOnClickPendingIntent(R.id.widget_root, mainIntent)

                // Quick Expense button -> open instant quick-add popup with expense type
                val expenseIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("pocket://quick-add?type=expense")
                )
                setOnClickPendingIntent(R.id.btn_quick_expense, expenseIntent)

                // Quick Income button -> open instant quick-add popup with income type
                val incomeIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("pocket://quick-add?type=income")
                )
                setOnClickPendingIntent(R.id.btn_quick_income, incomeIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
