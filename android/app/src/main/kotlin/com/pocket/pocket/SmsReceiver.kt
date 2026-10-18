package com.pocket.pocket

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

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
                if (!messages.isNullOrEmpty()) {
                    val senderMap = mutableMapOf<String, StringBuilder>()
                    var lastTimestamp = System.currentTimeMillis()
                    for (sms in messages) {
                        val sender = sms.displayOriginatingAddress ?: ""
                        val body = sms.displayMessageBody ?: ""
                        senderMap.getOrPut(sender) { StringBuilder() }.append(body)
                        lastTimestamp = sms.timestampMillis
                    }
                    timestamp = lastTimestamp
                    for ((sender, bodyBuilder) in senderMap) {
                        messagesList.add(Pair(sender, bodyBuilder.toString()))
                    }
                }
            }

            val prefs = context.getSharedPreferences(PocketNotificationListener.PREFS_NAME, Context.MODE_PRIVATE)
            val autoSaveSms = prefs.getBoolean("auto_save_sms", false)

            for ((sender, body) in messagesList) {
                val parsed = SmsParser.parse(sender, body, timestamp)
                if (parsed != null && parsed.amount > 0.0) {
                    val txJson = parsed.toJson()
                    if (autoSaveSms) {
                        txJson.put("autoSaveDirect", true)
                    }
                    PocketNotificationListener.savePendingTransaction(context, txJson)
                }
            }
        }
    }
}
