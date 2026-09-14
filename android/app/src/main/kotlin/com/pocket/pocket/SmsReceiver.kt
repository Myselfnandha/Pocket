package com.pocket.pocket

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONObject
import java.util.UUID

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val sender = sms.displayOriginatingAddress ?: ""
                val body = sms.displayMessageBody ?: ""
                
                // Fast filter: Most bank SMS senders in India are 6-9 characters with a prefix like "AD-HDFC", "VM-ICICI", etc.
                // We'll also just check if the body has payment keywords to be safe, exactly like Notification Listener.
                val lower = body.lowercase()
                val hasPaymentKeywords = (lower.contains("debited") || lower.contains("paid") || lower.contains("spent") || lower.contains("sent rs") || lower.contains("sent inr") || lower.contains("payment of")) &&
                        (lower.contains("₹") || lower.contains("rs.") || lower.contains("inr"))
                
                if (hasPaymentKeywords) {
                    val amount = PocketNotificationListener.extractAmount(body)
                    if (amount != null && amount > 0.0) {
                        val merchant = PocketNotificationListener.extractMerchant(sender, body)
                        val refId = PocketNotificationListener.extractRefId(body)
                        
                        val txJson = JSONObject().apply {
                            put("id", UUID.randomUUID().toString())
                            put("amount", amount)
                            put("merchant", merchant)
                            put("appSource", "SMS (\$sender)")
                            put("refId", refId ?: "")
                            put("date", sms.timestampMillis)
                            put("detectionSource", "sms")
                            put("rawPayload", body)
                            put("isIncome", PocketNotificationListener.isCreditTransaction(body))
                        }
                        
                        PocketNotificationListener.savePendingTransaction(context, txJson)
                    }
                }
            }
        }
    }
}
