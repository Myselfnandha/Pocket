package com.pocket.pocket

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper

class PocketSmsObserver(
    private val context: Context,
    handler: Handler = Handler(Looper.getMainLooper()),
    private val onSmsReceived: ((ParsedSmsTransaction) -> Unit)? = null
) : ContentObserver(handler) {

    private var lastObservedSmsId: Long = -1L

    override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)

        try {
            val inboxUri = Uri.parse("content://sms/inbox")
            val projection = arrayOf("_id", "address", "body", "date")
            val sortOrder = "date DESC LIMIT 1"

            context.contentResolver.query(
                inboxUri,
                projection,
                null,
                null,
                sortOrder
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idIdx = cursor.getColumnIndex("_id")
                    val addressIdx = cursor.getColumnIndex("address")
                    val bodyIdx = cursor.getColumnIndex("body")
                    val dateIdx = cursor.getColumnIndex("date")

                    val smsId = if (idIdx >= 0) cursor.getLong(idIdx) else -1L
                    val sender = if (addressIdx >= 0) cursor.getString(addressIdx) ?: "" else ""
                    val body = if (bodyIdx >= 0) cursor.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx >= 0) cursor.getLong(dateIdx) else System.currentTimeMillis()

                    if (smsId != -1L && smsId == lastObservedSmsId) {
                        return
                    }

                    // Only process recent SMS (within last 3 minutes)
                    val now = System.currentTimeMillis()
                    if (Math.abs(now - date) > 180000) {
                        return
                    }

                    lastObservedSmsId = smsId

                    val parsed = SmsParser.parse(sender, body, date, smsId.toString())
                    if (parsed != null && parsed.amount > 0.0) {
                        val prefs = context.getSharedPreferences(PocketNotificationListener.PREFS_NAME, Context.MODE_PRIVATE)
                        val autoSaveSms = prefs.getBoolean("auto_save_sms", false)

                        val txJson = parsed.toJson()
                        if (autoSaveSms) {
                            txJson.put("autoSaveDirect", true)
                        }

                        PocketNotificationListener.savePendingTransaction(context, txJson)
                        onSmsReceived?.invoke(parsed)
                    }
                }
            }
        } catch (_: Exception) {
            // Defensive handling for security / permission sandbox differences
        }
    }
}
