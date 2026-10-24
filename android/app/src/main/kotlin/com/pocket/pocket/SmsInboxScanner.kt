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

        // Try both content://sms/inbox and fallback to canonical content://sms
        val urisToScan = listOf(
            Uri.parse("content://sms/inbox"),
            Uri.parse("content://sms")
        )

        var totalProcessed = 0
        val maxLimit = if (daysLookback <= 0) 10000 else 600
        val seenSmsIds = HashSet<String>()

        for (targetUri in urisToScan) {
            if (totalProcessed > 0) {
                // If primary inbox returned items, do not duplicate from secondary URI
                break
            }

            val selection = if (cutoff > 0) {
                if (targetUri.toString() == "content://sms") "type = 1 AND date >= ?" else "date >= ?"
            } else {
                if (targetUri.toString() == "content://sms") "type = 1" else null
            }
            val selectionArgs = if (cutoff > 0) arrayOf(cutoff.toString()) else null
            val sortOrder = "date DESC"

            try {
                resolver.query(
                    targetUri,
                    arrayOf("address", "body", "date", "_id"),
                    selection,
                    selectionArgs,
                    sortOrder
                )?.use { cursor ->
                    val idIdx = cursor.getColumnIndex("_id")
                    val addressIdx = cursor.getColumnIndex("address")
                    val bodyIdx = cursor.getColumnIndex("body")
                    val dateIdx = cursor.getColumnIndex("date")

                    while (cursor.moveToNext() && totalProcessed < maxLimit) {
                        val smsId = if (idIdx >= 0) cursor.getString(idIdx) ?: "" else ""
                        if (smsId.isNotBlank() && seenSmsIds.contains(smsId)) continue

                        val sender = if (addressIdx >= 0) cursor.getString(addressIdx) ?: "" else ""
                        val body = if (bodyIdx >= 0) cursor.getString(bodyIdx) ?: "" else ""
                        val date = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L

                        if (body.isBlank()) continue

                        val lower = body.lowercase()
                        val hasCurrency = lower.contains("₹") || lower.contains("rs") || lower.contains("inr") || lower.contains("$")
                        val isBankOrAccount = lower.contains("a/c") || lower.contains("acct") || lower.contains("account") ||
                                lower.contains("card ending") || lower.contains("bal") || lower.contains("balance") ||
                                lower.contains("credit card") || lower.contains("bank") || lower.contains("upi")

                        // Reject personal non-financial chats
                        if (!hasCurrency && !isBankOrAccount) {
                            continue
                        }

                        val parsed = SmsParser.parse(sender, body, date, smsId)
                        if (parsed != null && parsed.amount > 0.0) {
                            if (smsId.isNotBlank()) seenSmsIds.add(smsId)
                            resultList.put(parsed.toJson())
                            totalProcessed++
                        } else if (daysLookback <= 0 && isBankOrAccount) {
                            // For onboarding/full discovery, capture bank balance alerts or notices
                            val last4 = SmsParser.extractAccountLast4(body)
                            if (last4 != null || lower.contains("bal") || lower.contains("balance") || lower.contains("bank")) {
                                if (smsId.isNotBlank()) seenSmsIds.add(smsId)
                                val cleanSender = cleanSenderAddress(sender)
                                val stableAlertId = if (smsId.isNotBlank()) "sms_$smsId" else "sms_${Math.abs((sender + "_" + body + "_" + date).hashCode())}"
                                val obj = JSONObject().apply {
                                    put("id", stableAlertId)
                                    put("sourceMessageId", smsId.ifBlank { stableAlertId })
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
                                totalProcessed++
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        return resultList.toString()
    }

    private fun cleanSenderAddress(sender: String): String {
        val parts = sender.split("-")
        val core = if (parts.size > 1) parts[1] else sender
        return core.trim().take(12)
    }
}
