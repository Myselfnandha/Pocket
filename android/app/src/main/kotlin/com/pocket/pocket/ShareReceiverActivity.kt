package com.pocket.pocket

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.regex.Pattern

class ShareReceiverActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val uri = extractUriFromIntent(intent)
        if (uri == null) {
            finish()
            return
        }

        // Process in background thread and close activity immediately
        Thread {
            try {
                processSharedImage(uri)
            } catch (_: Exception) {
            }
        }.start()

        // Immediately close the share dialog so user stays in UPI app / Gallery
        finish()
    }

    private fun extractUriFromIntent(intent: Intent?): Uri? {
        if (intent == null) return null
        if (Intent.ACTION_SEND == intent.action && intent.type?.startsWith("image/") == true) {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            } ?: intent.clipData?.getItemAt(0)?.uri ?: intent.data
        }
        return null
    }

    private fun processSharedImage(sourceUri: Uri) {
        val receiptsDir = File(filesDir, "receipts").apply { if (!exists()) mkdirs() }
        val savedFile = File(receiptsDir, "upi_shared_${System.currentTimeMillis()}.jpg")

        contentResolver.openInputStream(sourceUri)?.use { input ->
            FileOutputStream(savedFile).use { output ->
                input.copyTo(output)
            }
        }

        if (!savedFile.exists() || savedFile.length() == 0L) return

        val bitmap = BitmapFactory.decodeFile(savedFile.absolutePath) ?: return
        val image = InputImage.fromBitmap(bitmap, 0)
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                val fullText = visionText.text
                val parsed = parseUpiText(fullText)
                showTransactionNotification(parsed, savedFile.absolutePath, fullText)
            }
            .addOnFailureListener {
                // Fallback notification with just the image attached
                val fallbackParsed = ParsedData(
                    amount = "",
                    merchant = "UPI Merchant",
                    appSource = "UPI App",
                    dateTime = "",
                    refId = ""
                )
                showTransactionNotification(fallbackParsed, savedFile.absolutePath, "")
            }
    }

    private data class ParsedData(
        val amount: String,
        val merchant: String,
        val appSource: String,
        val dateTime: String,
        val refId: String
    )

    private fun parseUpiText(text: String): ParsedData {
        var amount = ""
        var merchant = ""
        var appSource = "UPI App"
        var refId = ""

        // 1. Detect UPI App Name
        val lower = text.lowercase()
        when {
            lower.contains("google pay") || lower.contains("gpay") -> appSource = "Google Pay"
            lower.contains("phonepe") -> appSource = "PhonePe"
            lower.contains("paytm") -> appSource = "Paytm"
            lower.contains("cred") -> appSource = "CRED"
            lower.contains("amazon pay") -> appSource = "Amazon Pay"
            lower.contains("bhim") -> appSource = "BHIM"
            lower.contains("hdfc") || lower.contains("payzapp") -> appSource = "HDFC Bank"
            lower.contains("sbi") || lower.contains("yono") -> appSource = "SBI"
            lower.contains("icici") || lower.contains("imobile") -> appSource = "ICICI Bank"
            lower.contains("axis") -> appSource = "Axis Bank"
        }

        // 2. Detect Amount (₹, Rs, INR)
        val amountPatterns = listOf(
            Pattern.compile("""(?:[₹₹]|Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{1,2})?)""", Pattern.CASE_INSENSITIVE),
            Pattern.compile("""(?:Paid|Payment of|Sent|Transferred)\s*(?:[₹₹]|Rs\.?|INR)?\s*([0-9,]+(?:\.[0-9]{1,2})?)""", Pattern.CASE_INSENSITIVE),
            Pattern.compile("""([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:[₹₹]|INR|Rs)""", Pattern.CASE_INSENSITIVE)
        )

        for (pattern in amountPatterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val candidate = matcher.group(1)?.replace(",", "") ?: ""
                if (candidate.isNotEmpty() && candidate.toDoubleOrNull() != null) {
                    val num = candidate.toDouble()
                    if (num > 0 && num < 10000000) {
                        amount = candidate
                        break
                    }
                }
            }
        }

        // 3. Detect Merchant / Recipient
        val merchantPatterns = listOf(
            Pattern.compile("""(?:Paid to|To:|Sent to|Transfer to|Payment to)\s+([A-Za-z0-9\s&.\-_]+?)(?:\n|\r|UPI|Banking|Completed|Successful|Ref|₹|Rs|$)""", Pattern.CASE_INSENSITIVE),
            Pattern.compile("""(?:at|towards|merchant)\s+([A-Za-z0-9\s&.\-_]{2,35}?)(?:\n|\r|UPI|on|via|ref|$)""", Pattern.CASE_INSENSITIVE)
        )

        for (pattern in merchantPatterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val candidate = matcher.group(1)?.trim() ?: ""
                if (candidate.isNotEmpty() && candidate.length > 1 && !candidate.lowercase().contains("google pay")) {
                    merchant = cleanMerchantName(candidate)
                    break
                }
            }
        }

        // 4. UPI Ref / Transaction ID
        val refPattern = Pattern.compile("""(?:UPI (?:Ref(?:erence)?|Txn|Transaction)?\s*(?:No|ID)?[:\s]*|UTR[:\s]*)([0-9A-Za-z]{8,22})""", Pattern.CASE_INSENSITIVE)
        val refMatcher = refPattern.matcher(text)
        if (refMatcher.find()) {
            refId = refMatcher.group(1) ?: ""
        }

        if (merchant.isEmpty()) {
            merchant = if (appSource != "UPI App") "$appSource Payment" else "UPI Transaction"
        }

        return ParsedData(
            amount = amount,
            merchant = merchant,
            appSource = appSource,
            dateTime = "",
            refId = refId
        )
    }

    private fun cleanMerchantName(name: String): String {
        return name.replace(Regex("""(?i)@ok[a-z]+|@okhdfcbank|@axisbank|@ybl|@ibl|@paytm|@upi"""), "")
            .replace(Regex("""(?i)\b(completed|successful|paid|to|ref|no|verified merchant)\b"""), "")
            .trim()
            .take(35)
    }

    private fun showTransactionNotification(parsedData: ParsedData, imagePath: String, rawText: String) {
        val channelId = "pocket_upi_shares"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "UPI & Receipt Shares",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Instant 1-tap logging for shared UPI and banking screenshots"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val payloadJson = JSONObject().apply {
            put("amount", parsedData.amount)
            put("merchant", parsedData.merchant)
            put("app_source", parsedData.appSource)
            put("ref_id", parsedData.refId)
            put("image_path", imagePath)
            put("raw_text", rawText)
        }.toString()

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            setData(Uri.parse("pocket://log_shared_transaction"))
            putExtra("shared_transaction_payload", payloadJson)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val amountDisplay = if (parsedData.amount.isNotEmpty()) "₹${parsedData.amount}" else "Receipt"
        val title = "💳 $amountDisplay at ${parsedData.merchant}"
        val body = "Paid via ${parsedData.appSource} • Tap to complete & log transaction"

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        notificationManager.notify(1099, notification)
    }
}
