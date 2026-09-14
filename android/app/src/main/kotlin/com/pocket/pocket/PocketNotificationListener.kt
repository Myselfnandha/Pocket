package com.pocket.pocket

import android.app.Notification
import android.content.Context
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.regex.Pattern

class PocketNotificationListener : NotificationListenerService() {

    companion object {
        const val PREFS_NAME = "pocket_auto_import_prefs"
        const val KEY_PENDING_TX = "pending_transactions"

        val TARGET_PACKAGES = mapOf(
            "com.google.android.apps.nbu.paisa.user" to "Google Pay",
            "com.phonepe.app" to "PhonePe",
            "net.one97.paytm" to "Paytm",
            "com.dreamplug.androidapp" to "CRED",
            "in.org.npci.upiapp" to "BHIM",
            "com.snapwork.hdfc" to "HDFC Bank",
            "com.csam.icici.bank.imobile" to "ICICI Bank",
            "com.sbi.lotusintouch" to "SBI",
            "com.axis.mobile" to "Axis Bank",
            "com.msf.kbank.mobile" to "Kotak Bank"
        )

        fun getPendingTransactions(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getString(KEY_PENDING_TX, "[]") ?: "[]"
        }

        fun savePendingTransaction(context: Context, jsonObject: JSONObject) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currentRaw = prefs.getString(KEY_PENDING_TX, "[]") ?: "[]"
            val array = try {
                JSONArray(currentRaw)
            } catch (e: Exception) {
                JSONArray()
            }

            // Deduplicate against existing queue items
            val newRef = jsonObject.optString("refId", "")
            val newAmount = jsonObject.optDouble("amount", 0.0)
            val newMerchant = jsonObject.optString("merchant", "").lowercase()
            val newDate = jsonObject.optLong("date", 0L)

            var isDuplicate = false
            for (i in 0 until array.length()) {
                val existing = array.getJSONObject(i)
                val exRef = existing.optString("refId", "")
                val exAmount = existing.optDouble("amount", 0.0)
                val exMerchant = existing.optString("merchant", "").lowercase()
                val exDate = existing.optLong("date", 0L)

                if (newRef.isNotEmpty() && exRef.isNotEmpty() && newRef == exRef) {
                    isDuplicate = true
                    break
                }
                if (Math.abs(newAmount - exAmount) < 0.01 &&
                    newMerchant.isNotEmpty() && newMerchant == exMerchant &&
                    Math.abs(newDate - exDate) <= 60000
                ) {
                    isDuplicate = true
                    break
                }
            }

            if (!isDuplicate) {
                array.put(jsonObject)
                prefs.edit().putString(KEY_PENDING_TX, array.toString()).apply()
            }
        }

        fun clearPendingTransactions(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_PENDING_TX, "[]").apply()
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val pkgName = sbn.packageName ?: return
        val appSource = TARGET_PACKAGES[pkgName]

        // Allow target packages or any package with payment debit keywords
        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val fullContent = "$title $text $bigText".trim()

        if (fullContent.isEmpty()) return

        // If not in known list, only parse if text contains explicit transaction signals
        if (appSource == null) {
            val lower = fullContent.lowercase()
            val hasPaymentKeywords = (lower.contains("debited") || lower.contains("paid") || lower.contains("spent") || lower.contains("sent rs") || lower.contains("sent inr") || lower.contains("payment of")) &&
                    (lower.contains("₹") || lower.contains("rs.") || lower.contains("inr"))
            if (!hasPaymentKeywords) return
        }

        parseAndQueueNotification(pkgName, appSource ?: "Bank Alert", title, fullContent, sbn.postTime)
    }

    private fun parseAndQueueNotification(pkgName: String, appSource: String, title: String, content: String, postTime: Long) {
        val amount = extractAmount(content) ?: return
        if (amount <= 0.0) return

        val merchant = extractMerchant(title, content)
        val refId = extractRefId(content)

        val txJson = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("amount", amount)
            put("merchant", merchant)
            put("appSource", appSource)
            put("refId", refId ?: "")
            put("date", if (postTime > 0) postTime else System.currentTimeMillis())
            put("detectionSource", "notification")
            put("rawPayload", content)
            put("isIncome", isCreditTransaction(content))
        }

        savePendingTransaction(applicationContext, txJson)
    }

    private fun extractAmount(text: String): Double? {
        val pattern = Pattern.compile("(?:₹|rs\\.?|inr)\\s*([0-9]+(?:,[0-9]{2,3})*(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(text)
        if (matcher.find()) {
            val raw = matcher.group(1)?.replace(",", "") ?: return null
            return raw.toDoubleOrNull()
        }

        // Secondary pattern: "paid 450.00" or "debited by 500"
        val secPattern = Pattern.compile("(?:paid|debited(?:\\s+by)?|spent)\\s+([0-9]+(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE)
        val secMatcher = secPattern.matcher(text)
        if (secMatcher.find()) {
            val raw = secMatcher.group(1) ?: return null
            return raw.toDoubleOrNull()
        }

        return null
    }

    private fun extractMerchant(title: String, content: String): String {
        // "Paid to [Merchant]" or "Payment to [Merchant]"
        val toPattern = Pattern.compile("(?:paid to|payment to|transferred to|sent to|at)\\s+([A-Za-z0-9&'._\\s]{2,35}?)(?:\\s+(?:via|using|on|ref|upi|for|\\.|$)|\$)", Pattern.CASE_INSENSITIVE)
        val toMatcher = toPattern.matcher(content)
        if (toMatcher.find()) {
            val found = toMatcher.group(1)?.trim()
            if (!found.isNullOrEmpty() && !found.equals("vpa", true)) {
                return cleanMerchantName(found)
            }
        }

        // Fallback to title if title looks like merchant name
        if (title.isNotEmpty() && !title.contains("transaction", true) && !title.contains("alert", true) && !title.contains("pocket", true)) {
            return cleanMerchantName(title)
        }

        return "Payment"
    }

    private fun extractRefId(text: String): String? {
        val pattern = Pattern.compile("(?:upi\\s*ref(?:\\s*no)?|ref(?:\\s*id)?|txn(?:\\s*id)?)\\s*[:.-]?\\s*([0-9]{8,16})", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(text)
        if (matcher.find()) {
            return matcher.group(1)?.trim()
        }
        return null
    }

    private fun isCreditTransaction(text: String): Boolean {
        val lower = text.lowercase()
        return (lower.contains("credited") || lower.contains("received") || lower.contains("refund")) &&
                !lower.contains("debited")
    }

    private fun cleanMerchantName(name: String): String {
        return name.replace(Regex("(?i)(ltd|pvt|limited|india|store|upi|payment)$"), "")
            .trim()
            .take(30)
            .ifEmpty { "Payment" }
    }
}
