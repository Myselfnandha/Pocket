package com.pocket.pocket

import android.content.Context
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

object SmsInboxScanner {

    fun scanInbox(context: Context, daysLookback: Int = 30): String {
        val resultList = JSONArray()
        val resolver = context.contentResolver

        val cutoff = if (daysLookback > 0) {
            System.currentTimeMillis() - (daysLookback.toLong() * 24L * 60L * 60L * 1000L)
        } else {
            0L
        }

        val inboxUri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("address", "body", "date", "_id")

        val selection = if (cutoff > 0) "date >= ?" else null
        val selectionArgs = if (cutoff > 0) arrayOf(cutoff.toString()) else null
        val sortOrder = "date DESC"

        try {
            resolver.query(
                inboxUri,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )?.use { cursor ->
                val addressIdx = cursor.getColumnIndex("address")
                val bodyIdx = cursor.getColumnIndex("body")
                val dateIdx = cursor.getColumnIndex("date")

                var count = 0
                val maxLimit = if (daysLookback <= 0) 10000 else 600

                while (cursor.moveToNext() && count < maxLimit) {
                    val sender = if (addressIdx >= 0) cursor.getString(addressIdx) ?: "" else ""
                    val body = if (bodyIdx >= 0) cursor.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L

                    if (body.isBlank()) continue

                    val lower = body.lowercase()
                    val hasCurrency = lower.contains("₹") || lower.contains("rs") || lower.contains("inr") || lower.contains("$")
                    val isBankOrAccount = lower.contains("a/c") || lower.contains("acct") || lower.contains("account") ||
                            lower.contains("card ending") || lower.contains("bal") || lower.contains("balance")

                    // Reject personal non-financial chats
                    if (!hasCurrency && !isBankOrAccount) {
                        continue
                    }

                    val parsed = SmsParser.parse(sender, body, date)
                    if (parsed != null && parsed.amount > 0.0) {
                        resultList.put(parsed.toJson())
                        count++
                    } else if (daysLookback <= 0 && isBankOrAccount) {
                        // For onboarding/full discovery, capture bank balance alerts or notices
                        val last4 = SmsParser.extractAccountLast4(body)
                        if (last4 != null || lower.contains("bal")) {
                            val cleanSender = cleanSenderAddress(sender)
                            val obj = JSONObject().apply {
                                put("id", UUID.randomUUID().toString())
                                put("amount", 0.0)
                                put("merchant", cleanSender.ifEmpty { "Bank Alert" })
                                put("appSource", "SMS ($cleanSender)")
                                put("refId", "")
                                put("date", if (date > 0) date else System.currentTimeMillis())
                                put("detectionSource", "sms")
                                put("rawPayload", body)
                                put("isIncome", false)
                                if (last4 != null) {
                                    put("counterpartyLast4", last4)
                                }
                            }
                            resultList.put(obj)
                            count++
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return resultList.toString()
    }

    private fun cleanSenderAddress(sender: String): String {
        val parts = sender.split("-")
        val core = if (parts.size > 1) parts[1] else sender
        return core.trim().take(12)
    }
}
