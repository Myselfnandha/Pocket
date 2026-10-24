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
                    // Two-way enrichment: attach screenshot image, bank details, or richer merchant name
                    val newImg = jsonObject.optString("imagePath", "")
                    if (newImg.isNotEmpty() && existing.optString("imagePath", "").isEmpty()) {
                        existing.put("imagePath", newImg)
                    }
                    val newAppSource = jsonObject.optString("appSource", "")
                    if (newAppSource.contains("SMS") && !existing.optString("appSource", "").contains("SMS")) {
                        existing.put("smsSource", newAppSource)
                    }
                    if (jsonObject.optBoolean("autoSaveDirect", false)) {
                        existing.put("autoSaveDirect", true)
                    }
                    val exMerch = existing.optString("merchant", "")
                    val newMerch = jsonObject.optString("merchant", "")
                    if ((exMerch.contains("Payment") || exMerch.contains("Alert") || exMerch == "UPI Payment") &&
                        newMerch.isNotEmpty() && !newMerch.contains("Payment") && !newMerch.contains("Alert")) {
                        existing.put("merchant", newMerch)
                    }
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

        fun extractAmount(text: String): Double? {
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

        fun extractMerchant(title: String, content: String): String {
            // "Paid to [Merchant]", "Payment to [Merchant]", "Paid towards [Merchant]"
            val toPattern = Pattern.compile("(?:paid\\s+(?:to|towards)|payment\\s+(?:to|towards)|transferred\\s+(?:to|towards)|sent\\s+(?:to|towards)|towards|at)\\s+([A-Za-z0-9&'._\\s]{2,35}?)(?:\\s+(?:via|using|on|ref|upi|for|\\.|$)|\$)", Pattern.CASE_INSENSITIVE)
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

        fun extractRefId(text: String): String? {
            val pattern = Pattern.compile("(?:upi\\s*ref(?:\\s*no)?|ref(?:\\s*id)?|txn(?:\\s*id)?)\\s*[:.-]?\\s*([0-9]{8,16})", Pattern.CASE_INSENSITIVE)
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                return matcher.group(1)?.trim()
            }
            return null
        }

        fun isCreditTransaction(text: String): Boolean {
            val lower = text.lowercase()
            return (lower.contains("credited") || lower.contains("received") || lower.contains("refund")) &&
                    !lower.contains("debited")
        }

        fun extractAccountLast4(text: String): String? {
            val pattern = Pattern.compile("(?:a/c|ac|account|card|acct|ending\\s*(?:in|with)?|using|linked to)[\\s:.-]*[*xX•.-]*([0-9]{3,4})\\b", Pattern.CASE_INSENSITIVE)
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                return matcher.group(1)?.trim()
            }
            return null
        }

        fun extractSenderBank(text: String, appSource: String): String? {
            val lower = "$appSource $text".lowercase()
            return when {
                lower.contains("state bank") || lower.contains("sbi") -> "State Bank of India"
                lower.contains("hdfc") -> "HDFC Bank"
                lower.contains("icici") -> "ICICI Bank"
                lower.contains("axis") -> "Axis Bank"
                lower.contains("kotak") -> "Kotak Mahindra Bank"
                lower.contains("indusind") || lower.contains("indusb") -> "IndusInd Bank"
                lower.contains("punjab national") || lower.contains("pnb") -> "Punjab National Bank"
                lower.contains("bank of baroda") || lower.contains("bob") -> "Bank of Baroda"
                lower.contains("canara") -> "Canara Bank"
                lower.contains("union bank") || lower.contains("uboi") -> "Union Bank of India"
                lower.contains("indian bank") || lower.contains("indbnk") -> "Indian Bank"
                lower.contains("idfc") -> "IDFC FIRST Bank"
                lower.contains("federal bank") -> "Federal Bank"
                lower.contains("rbl") -> "RBL Bank"
                lower.contains("yes bank") -> "Yes Bank"
                lower.contains("paytm bank") || lower.contains("paytm payments bank") -> "Paytm Payments Bank"
                lower.contains("airtel payments bank") -> "Airtel Payments Bank"
                lower.contains("jupiter") -> "Jupiter"
                lower.contains("fi money") -> "Fi Money"
                else -> null
            }
        }

        private fun cleanMerchantName(name: String): String {
            return name.replace(Regex("(?i)(ltd|pvt|limited|india|store|upi|payment)$"), "")
                .trim()
                .take(30)
                .ifEmpty { "Payment" }
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
        val isIncome = isCreditTransaction(content)
        val last4 = extractAccountLast4(content)
        val senderBank = extractSenderBank(content, appSource)
        val senderName = if (isIncome) merchant else null
        val receiverName = if (!isIncome) merchant else null
        val isPaytm = pkgName == "net.one97.paytm" || appSource.contains("Paytm", true) || content.contains("paytm", true)

        val txJson = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("amount", amount)
            put("merchant", merchant)
            put("appSource", appSource)
            put("refId", refId ?: "")
            put("date", if (postTime > 0) postTime else System.currentTimeMillis())
            put("detectionSource", "notification")
            put("rawPayload", content)
            put("isIncome", isIncome)
            if (!last4.isNullOrEmpty()) {
                put("counterpartyLast4", last4)
            }
            if (!senderBank.isNullOrEmpty()) {
                put("senderBank", senderBank)
            }
            if (!senderName.isNullOrEmpty()) {
                put("senderName", senderName)
            }
            if (!receiverName.isNullOrEmpty()) {
                put("receiverName", receiverName)
            }
            if (isPaytm) {
                put("autoSaveDirect", true)
            }
        }

        savePendingTransaction(applicationContext, txJson)

        // Automatically update home screen widgets without foreground app running!
        if (isPaytm || isAutoSaveEnabled(applicationContext)) {
            updateWidgetDirectly(applicationContext, amount, isIncome, merchant)
        }
    }

    private fun isAutoSaveEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean("auto_save_sms", false) || prefs.getBoolean("auto_save_upi", true)
    }

    private fun updateWidgetDirectly(context: Context, amount: Double, isIncome: Boolean, merchant: String) {
        try {
            val widgetPrefs = try {
                es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            } catch (_: Exception) {
                @Suppress("DEPRECATION")
                android.preference.PreferenceManager.getDefaultSharedPreferences(context)
            }

            val currentTotalRaw = widgetPrefs.getString("raw_total_balance", null)
                ?: widgetPrefs.getString("total_balance", "₹0.00") ?: "₹0.00"

            val currSymbol = if (currentTotalRaw.contains("$")) "$" else "₹"
            val numRegex = Regex("""([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]+)?)""")
            val currentTotalMatch = numRegex.find(currentTotalRaw.replace(",", ""))
            val currentTotalVal = currentTotalMatch?.value?.toDoubleOrNull() ?: 0.0

            val newTotalVal = if (isIncome) currentTotalVal + amount else (currentTotalVal - amount)
            val formattedNewTotal = String.format(java.util.Locale.US, "%.2f", newTotalVal)
            val displayTotal = "$currSymbol$formattedNewTotal"

            // Today's expense
            val currentTodayStr = widgetPrefs.getString("today_expense", "₹0.00 Today") ?: "₹0.00 Today"
            val todayNumMatch = numRegex.find(currentTodayStr.replace(",", ""))
            val currentTodayVal = todayNumMatch?.value?.toDoubleOrNull() ?: 0.0
            val newTodayVal = if (!isIncome) currentTodayVal + amount else currentTodayVal
            val formattedNewToday = String.format(java.util.Locale.US, "%.2f", newTodayVal)
            val displayToday = "$currSymbol$formattedNewToday Today"

            // Save updated balance to widget SharedPreferences
            widgetPrefs.edit()
                .putString("total_balance", displayTotal)
                .putString("raw_total_balance", displayTotal)
                .putString("card_balance", displayTotal)
                .putString("raw_card_balance", displayTotal)
                .putString("today_expense", displayToday)
                .apply()

            // Trigger instant update across all 4 widget sizes
            PocketWidgetProvider.refreshAll(context)
            PocketCardWidgetProvider.refreshAll(context)
            PocketRunwayWidgetProvider.refreshAll(context)
            PocketBarWidgetProvider.refreshAll(context)

            // Broadcast system widget update
            val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(context)
            for (cls in listOf(
                PocketWidgetProvider::class.java,
                PocketCardWidgetProvider::class.java,
                PocketRunwayWidgetProvider::class.java,
                PocketBarWidgetProvider::class.java
            )) {
                val ids = appWidgetManager.getAppWidgetIds(android.content.ComponentName(context, cls))
                if (ids != null && ids.isNotEmpty()) {
                    val intent = android.content.Intent(android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                        component = android.content.ComponentName(context, cls)
                        putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    context.sendBroadcast(intent)
                }
            }
        } catch (_: Exception) {}
    }
}
