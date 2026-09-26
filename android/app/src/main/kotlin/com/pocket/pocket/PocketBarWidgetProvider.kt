package com.pocket.pocket

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PocketBarWidgetProvider : HomeWidgetProvider() {
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
                    setTextViewText(R.id.widget_bar_balance, barBalance)

                    // Balance pill tap -> open main app
                    val mainPendingIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocket://home")
                    )
                    setOnClickPendingIntent(R.id.btn_bar_balance, mainPendingIntent)
                    setOnClickPendingIntent(R.id.widget_root, mainPendingIntent)

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
