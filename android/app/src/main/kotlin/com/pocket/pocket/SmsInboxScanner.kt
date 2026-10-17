package com.pocket.pocket

import android.content.Context
import android.provider.Telephony
import org.json.JSONArray

object SmsInboxScanner {

    fun scanInbox(context: Context, daysLookback: Int = 30): String {
        val resultList = JSONArray()
        val resolver = context.contentResolver

        val cutoff = if (daysLookback > 0) {
            System.currentTimeMillis() - (daysLookback.toLong() * 24L * 60L * 60L * 1000L)
        } else {
            0L
        }

        val projection = arrayOf(
            Telephony.Sms.Inbox.ADDRESS,
            Telephony.Sms.Inbox.BODY,
            Telephony.Sms.Inbox.DATE,
            Telephony.Sms.Inbox._ID
        )

        val selection = if (cutoff > 0) "${Telephony.Sms.Inbox.DATE} >= ?" else null
        val selectionArgs = if (cutoff > 0) arrayOf(cutoff.toString()) else null
        val sortOrder = "${Telephony.Sms.Inbox.DATE} DESC"

        try {
            resolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )?.use { cursor ->
                val addressIdx = cursor.getColumnIndex(Telephony.Sms.Inbox.ADDRESS)
                val bodyIdx = cursor.getColumnIndex(Telephony.Sms.Inbox.BODY)
                val dateIdx = cursor.getColumnIndex(Telephony.Sms.Inbox.DATE)

                var count = 0
                val maxLimit = 600

                while (cursor.moveToNext() && count < maxLimit) {
                    val sender = if (addressIdx >= 0) cursor.getString(addressIdx) ?: "" else ""
                    val body = if (bodyIdx >= 0) cursor.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L

                    if (body.isBlank()) continue

                    // Fast reject personal chat messages that don't have currency indicators
                    val lower = body.lowercase()
                    if (!lower.contains("₹") && !lower.contains("rs.") && !lower.contains("rs ") && !lower.contains("inr") && !lower.contains("$")) {
                        continue
                    }

                    val parsed = SmsParser.parse(sender, body, date)
                    if (parsed != null && parsed.amount > 0.0) {
                        resultList.put(parsed.toJson())
                        count++
                    }
                }
            }
        } catch (e: Exception) {
            // Permission denied or query error
            e.printStackTrace()
        }

        return resultList.toString()
    }
}
