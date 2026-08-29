package com.pocket.pocket

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.regex.Pattern

class PocketNotificationListenerService : NotificationListenerService() {

    companion object {
        const val PREFS_NAME = "pocket_detected_transactions"
        const val KEY_PENDING_LIST = "pending_list"
        const val CHANNEL_ID = "pocket_detected_payments"
        const val CHANNEL_NAME = "Detected UPI Payments"
        const val ACTION_QUICK_SAVE = "com.pocket.pocket.ACTION_QUICK_SAVE"

        val MONITORED_PACKAGES = mapOf(
            "com.google.android.apps.nbu.paisa.user" to "Google Pay",
            "com.phonepe.app" to "PhonePe",
            "net.one97.paytm" to "Paytm",
            "com.dreamplug.androidapp" to "CRED",
            "in.org.npci.upiapp" to "BHIM",
            "in.amazon.mShop.android.shopping" to "Amazon Pay",
            "com.snapwork.hdfc" to "HDFC Bank",
            "com.sbi.lotusintouch" to "SBI Yono",
            "com.sbi.SBIFreedomPlus" to "SBI Yono Lite",
            "com.csam.icici.bank.imobile" to "ICICI Bank",
            "com.axis.mobile" to "Axis Bank",
            "com.msf.kbank.mobile" to "Kotak Bank",
            "com.fss.pnb" to "PNB ONE",
            "com.canarabank.mobility" to "Canara Bank",
            "com.bankofbaroda.mconnect" to "Bank of Baroda"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val appName = MONITORED_PACKAGES[packageName] ?: return

        val extras: Bundle = sbn.notification.extras ?: return
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""

        val fullContent = "$title $text $bigText".trim()
        if (fullContent.isEmpty()) return

        parseAndProcessTransaction(appName, title, fullContent)
    }

    private fun parseAndProcessTransaction(appName: String, rawTitle: String, content: String) {
        // 1. Amount Extraction
        val amount = extractAmount(content) ?: return
        if (amount <= 0.0) return

        // 2. Type Extraction (Default: Expense)
        val type = extractType(content)

        // 3. Merchant / Recipient Extraction
        val merchant = extractMerchant(content, rawTitle)

        // 4. Save to Pending Queue in SharedPreferences
        val txId = UUID.randomUUID().toString()
        val timestamp = System.currentTimeMillis()

        savePendingTransaction(
            id = txId,
            amount = amount,
            merchant = merchant,
            sourceApp = appName,
            type = type,
            timestamp = timestamp,
            rawText = content
        )

        // 5. Post High-Priority Actionable Notification
        postPocketTransactionNotification(
            id = txId,
            amount = amount,
            merchant = merchant,
            sourceApp = appName,
            type = type,
            timestamp = timestamp
        )
    }

    private fun extractAmount(text: String): Double? {
        // Match: ₹450, Rs. 1,200.50, INR 500, Rs 300, etc.
        val pattern = Pattern.compile("(?:Rs\\.?|INR|₹|\\$)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(text)
        if (matcher.find()) {
            val amountStr = matcher.group(1)?.replace(",", "") ?: ""
            return amountStr.toDoubleOrNull()
        }

        // Secondary match: 450.00 Rs / INR / ₹
        val secondaryPattern = Pattern.compile("([0-9,]+(?:\\.[0-9]{1,2})?)\\s*(?:INR|Rs\\.?|₹)", Pattern.CASE_INSENSITIVE)
        val secondaryMatcher = secondaryPattern.matcher(text)
        if (secondaryMatcher.find()) {
            val amountStr = secondaryMatcher.group(1)?.replace(",", "") ?: ""
            return amountStr.toDoubleOrNull()
        }

        return null
    }

    private fun extractType(text: String): String {
        val lower = text.lowercase()
        if (lower.contains("credited") || lower.contains("received") || lower.contains("deposited") ||
            lower.contains("refund") || lower.contains("cashback") || lower.contains(" cr ")) {
            return "income"
        }
        return "expense"
    }

    private fun extractMerchant(text: String, title: String): String {
        // Regex patterns for merchants: "paid to Swiggy", "to Ramesh Kumar", "at Starbucks", "towards Electricity"
        val pattern = Pattern.compile("(?:paid to|to|at|towards|info|vpa|for)\\s+([A-Za-z0-9\\s\\.\\&\\*\\-_@]{2,30}?)(?:\\s+on|\\s+ref|\\s+upi|\\s+avl|\\s+bal|\\s+via|\\.|\\n|$)", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(text)
        if (matcher.find()) {
            val raw = matcher.group(1)?.trim() ?: ""
            if (raw.isNotEmpty() && !raw.equals("you", ignoreCase = true) && !raw.equals("your", ignoreCase = true)) {
                return cleanMerchantName(raw)
            }
        }

        // Fallback: Check title
        if (title.isNotEmpty() && !title.contains("Paid", ignoreCase = true) && !title.contains("Transaction", ignoreCase = true)) {
            return cleanMerchantName(title)
        }

        return "UPI Payment"
    }

    private fun cleanMerchantName(name: String): String {
        return name.replace(Regex("[^A-Za-z0-9\\s\\&\\.\\-]"), "")
            .replace(Regex("\\s+"), " ")
            .trim()
            .take(30)
    }

    private fun savePendingTransaction(
        id: String,
        amount: Double,
        merchant: String,
        sourceApp: String,
        type: String,
        timestamp: Long,
        rawText: String
    ) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(KEY_PENDING_LIST, "[]") ?: "[]"
        val jsonArray = try { JSONArray(existingJson) } catch (_: Exception) { JSONArray() }

        val obj = JSONObject().apply {
            put("id", id)
            put("amount", amount)
            put("merchant", merchant)
            put("sourceApp", sourceApp)
            put("type", type)
            put("timestamp", timestamp)
            put("rawText", rawText)
            put("status", "pending")
        }

        jsonArray.put(obj)
        prefs.edit().putString(KEY_PENDING_LIST, jsonArray.toString()).apply()
    }

    private fun postPocketTransactionNotification(
        id: String,
        amount: Double,
        merchant: String,
        sourceApp: String,
        type: String,
        timestamp: Long
    ) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create Channel on Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Real-time alerts for incoming UPI and banking payments"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 1. Content Intent: Opens Pocket into the Review Modal
        val deepLinkUri = Uri.parse("pocket://review_transaction?id=$id&amount=$amount&merchant=${Uri.encode(merchant)}&app=${Uri.encode(sourceApp)}&type=$type&timestamp=$timestamp")
        val contentIntent = Intent(Intent.ACTION_VIEW, deepLinkUri, this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            id.hashCode(),
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 2. Action: 1-Tap Quick Save
        val quickSaveIntent = Intent(this, QuickSaveReceiver::class.java).apply {
            action = ACTION_QUICK_SAVE
            putExtra("id", id)
            putExtra("amount", amount)
            putExtra("merchant", merchant)
            putExtra("sourceApp", sourceApp)
            putExtra("type", type)
            putExtra("timestamp", timestamp)
        }
        val quickSavePendingIntent = PendingIntent.getBroadcast(
            this,
            (id + "_qs").hashCode(),
            quickSaveIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val formattedAmount = if (amount % 1.0 == 0.0) "₹${amount.toInt()}" else "₹${String.format("%.2f", amount)}"
        val actionVerb = if (type == "income") "received" else "paid"

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("$formattedAmount $actionVerb via $sourceApp")
            .setContentText("$merchant • Tap to add description & save")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Transaction of $formattedAmount $actionVerb to $merchant via $sourceApp.\nTap to add custom notes or attach a receipt."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .addAction(R.mipmap.ic_launcher, "⚡ 1-Tap Save", quickSavePendingIntent)
            .addAction(R.mipmap.ic_launcher, "✏️ Add Details", contentPendingIntent)
            .build()

        notificationManager.notify(id.hashCode(), notification)
    }
}

class QuickSaveReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        val id = intent.getStringExtra("id") ?: return

        // Mark transaction as auto-approved in SharedPreferences
        val prefs = context.getSharedPreferences(PocketNotificationListenerService.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(PocketNotificationListenerService.KEY_PENDING_LIST, "[]") ?: "[]"

        try {
            val jsonArray = JSONArray(existingJson)
            val updatedArray = JSONArray()
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.getJSONObject(i)
                if (item.optString("id") == id) {
                    item.put("status", "auto_approved")
                }
                updatedArray.put(item)
            }
            prefs.edit().putString(PocketNotificationListenerService.KEY_PENDING_LIST, updatedArray.toString()).apply()

            // Dismiss notification
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(id.hashCode())
        } catch (_: Exception) {}
    }
}
