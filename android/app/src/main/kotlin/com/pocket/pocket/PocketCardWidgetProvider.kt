package com.pocket.pocket

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PocketCardWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.pocket_card_widget_layout).apply {
                    val totalBalance = widgetData.getString("card_balance", widgetData.getString("total_balance", "₹0.00")) ?: "₹0.00"
                    val todayExpense = widgetData.getString("today_expense", "₹0.00 Today") ?: "₹0.00 Today"
                    val walletName = widgetData.getString("card_wallet_name", "Main Account") ?: "Main Account"
                    val budgetTag = widgetData.getString("budget_status_tag", "On Budget") ?: "On Budget"
                    val secondaryAction = widgetData.getString("secondary_action_type", "scan") ?: "scan"

                    setTextViewText(R.id.widget_total_balance, totalBalance)
                    setTextViewText(R.id.widget_today_expense, todayExpense)
                    setTextViewText(R.id.widget_card_wallet_name, walletName)
                    setTextViewText(R.id.widget_budget_tag, budgetTag)

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
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
            }
        }
    }
}
