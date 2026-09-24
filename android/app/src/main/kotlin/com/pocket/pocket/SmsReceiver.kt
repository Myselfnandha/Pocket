package com.pocket.pocket

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONObject
import java.util.UUID

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION || intent.action == "com.pocket.pocket.TEST_SMS") {
            val messagesList = mutableListOf<Pair<String, String>>()
            var timestamp = System.currentTimeMillis()
            
            if (intent.action == "com.pocket.pocket.TEST_SMS") {
                val sender = intent.getStringExtra("sender") ?: "TESTBANK"
                val body = intent.getStringExtra("body") ?: ""
                messagesList.add(Pair(sender, body))
            } else {
                val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                for (sms in messages) {
                    val sender = sms.displayOriginatingAddress ?: ""
                    val body = sms.displayMessageBody ?: ""
                    messagesList.add(Pair(sender, body))
                    timestamp = sms.timestampMillis
                }
            }

            for ((sender, body) in messagesList) {
                // Fast filter: Most bank SMS senders in India are 6-9 characters with a prefix like "AD-HDFC", "VM-ICICI", etc.
                // We'll also just check if the body has payment keywords to be safe, exactly like Notification Listener.
                val lower = body.lowercase()
                val hasPaymentKeywords = (lower.contains("debited") || lower.contains("paid") || lower.contains("spent") || lower.contains("sent rs") || lower.contains("sent inr") || lower.contains("payment of")) &&
                        (lower.contains("₹") || lower.contains("rs.") || lower.contains("inr") || lower.contains("$"))
                
                if (hasPaymentKeywords) {
                    val amount = PocketNotificationListener.extractAmount(body)
                    if (amount != null && amount > 0.0) {
                        val merchant = PocketNotificationListener.extractMerchant(sender, body)
                        val refId = PocketNotificationListener.extractRefId(body)
                        
                        val txJson = JSONObject().apply {
                            put("id", java.util.UUID.randomUUID().toString())
                            put("amount", amount)
                            put("merchant", merchant)
                            put("appSource", "SMS ($sender)")
                            put("refId", refId ?: "")
                            put("date", timestamp)
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
