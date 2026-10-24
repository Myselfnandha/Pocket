package com.pocket.pocket

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object AutoLogNotificationHelper {
    const val CHANNEL_ID = "pocket_tx_channel_id"
    const val CHANNEL_NAME = "Transaction Updates"

    fun showAutoLogNotification(
        context: Context,
        merchant: String,
        amount: Double,
        isIncome: Boolean,
        source: String,
        last4: String? = null
    ) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Instant confirmation heads-up when transactions are recorded"
                    enableLights(true)
                    lightColor = 0xFF00E676.toInt()
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                (System.currentTimeMillis() % 100000).toInt(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val prefix = if (isIncome) "+" else "-"
            val formattedAmount = String.format(java.util.Locale.US, "%.2f", amount)
            val title = if (isIncome) "⚡ Auto-Logged: +₹$formattedAmount" else "⚡ Auto-Logged: -₹$formattedAmount"
            val acctInfo = if (!last4.isNullOrEmpty()) " (•••• $last4)" else ""
            val body = "$merchant • $prefix₹$formattedAmount via $source$acctInfo ✓"

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setColor(0xFF00E676.toInt())
                .setContentTitle(title)
                .setSubText("Pocket • Auto-Log")
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setTimeoutAfter(6000)
                .setContentIntent(pendingIntent)
                .build()

            val notifId = (System.currentTimeMillis() % 100000).toInt()
            notificationManager.notify(notifId, notification)
        } catch (_: Exception) {
            // Defensive failure isolation
        }
    }
}
