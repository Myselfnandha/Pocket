package com.pocket.pocket

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import org.json.JSONObject
import java.io.File
import java.util.UUID

class PocketScreenshotObserver(
    private val context: Context,
    handler: Handler = Handler(Looper.getMainLooper())
) : ContentObserver(handler) {

    private var lastObservedPath: String? = null
    private var lastObservedTimestamp: Long = 0L

    override fun onChange(selfChange: Boolean, uri: Uri?) {
        super.onChange(selfChange, uri)

        try {
            val projection = arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DATA,
                MediaStore.Images.Media.DATE_ADDED
            )

            val cursor = context.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC"
            )

            cursor?.use {
                if (it.moveToFirst()) {
                    val dataIdx = it.getColumnIndex(MediaStore.Images.Media.DATA)
                    val dateIdx = it.getColumnIndex(MediaStore.Images.Media.DATE_ADDED)

                    if (dataIdx != -1) {
                        val path = it.getString(dataIdx)
                        val dateSec = if (dateIdx != -1) it.getLong(dateIdx) else 0L
                        val dateMs = dateSec * 1000L

                        val lowerPath = path.lowercase()
                        val isScreenshot = lowerPath.contains("screenshot") ||
                                lowerPath.contains("screen_capture") ||
                                lowerPath.contains("screen-shot")

                        val now = System.currentTimeMillis()
                        // Ensure image was added within the last 15 seconds to ignore old files
                        val isRecent = Math.abs(now - dateMs) < 15000 || dateMs == 0L

                        if (isScreenshot && isRecent && path != lastObservedPath && File(path).exists()) {
                            lastObservedPath = path
                            lastObservedTimestamp = now

                            val txJson = JSONObject().apply {
                                put("id", UUID.randomUUID().toString())
                                put("amount", 0.0) // Will be populated by Flutter OCR
                                put("merchant", "Screenshot Receipt")
                                put("appSource", "Screenshot Watcher")
                                put("refId", "")
                                put("date", now)
                                put("imagePath", path)
                                put("detectionSource", "screenshot")
                                put("rawPayload", "")
                                put("isIncome", false)
                            }

                            PocketNotificationListener.savePendingTransaction(context, txJson)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // Defensive handling for content provider permission differences
        }
    }
}
