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
            lower.contains("kotak") -> appSource = "Kotak Bank"
            lower.contains("super.money") || lower.contains("supermoney") -> appSource = "Super.money"
            lower.contains("famapp") || lower.contains("fampay") -> appSource = "FamPay"
        }

        // 2. Multi-Stage Amount Scanner (Stage 1: Explicit Currency & Action Verbs)
        val amountPatterns = listOf(
            // Direct currency prefixes (₹ 1500, Rs. 1500.00, INR 1500)
            Pattern.compile("""(?:[₹₹]|Rs\.?|INR|\$)\s*([0-9,]+(?:\.[0-9]{1,2})?)""", Pattern.CASE_INSENSITIVE),
            // Action verbs (Paid 1500, Sent Rs 1500, Debited ₹1500, Total ₹1500)
            Pattern.compile("""(?:Paid|Payment of|Sent|Transferred|Amount|Total|Debited|Debited by|Spent)\s*(?:[₹₹]|Rs\.?|INR)?\s*([0-9,]+(?:\.[0-9]{1,2})?)""", Pattern.CASE_INSENSITIVE),
            // Trailing currency (1500 ₹, 1500.00 INR)
            Pattern.compile("""([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:[₹₹]|INR|Rs)""", Pattern.CASE_INSENSITIVE)
        )

        for (pattern in amountPatterns) {
            val matcher = pattern.matcher(text)
            if (matcher.find()) {
                val candidate = matcher.group(1)?.replace(",", "") ?: ""
                val num = candidate.toDoubleOrNull()
                if (num != null && num > 0 && num < 10000000) {
                    amount = candidate
                    break
                }
            }
        }

        // Stage 2: Line-by-Line Contextual Scanner (handles ₹ on one line, amount on next line)
        if (amount.isEmpty()) {
            val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }
            for (i in lines.indices) {
                val line = lines[i]
                // Look for standalone number on its own line: e.g. "450.00" or "450"
                val lineAmountMatch = Pattern.compile("""^[₹₹RsINR\s]*([0-9,]+(?:\.[0-9]{1,2})?)\s*$""", Pattern.CASE_INSENSITIVE).matcher(line)
                if (lineAmountMatch.find()) {
                    val candidate = lineAmountMatch.group(1)?.replace(",", "") ?: ""
                    val num = candidate.toDoubleOrNull()
                    if (num != null && num > 0 && num < 10000000) {
                        // Check if previous or current line has currency or payment indicator
                        val prevLine = if (i > 0) lines[i - 1].lowercase() else ""
                        if (prevLine.contains("₹") || prevLine.contains("rs") || prevLine.contains("paid") || prevLine.contains("sent") || prevLine.contains("amount") || line.contains("₹")) {
                            amount = candidate
                            break
                        }
                    }
                }
            }
        }

        // Stage 3: Fallback largest decimal monetary amount found on screen (e.g. 250.00)
        if (amount.isEmpty()) {
            val decimalPattern = Pattern.compile("""\b([0-9]{1,6}\.[0-9]{2})\b""")
            val matcher = decimalPattern.matcher(text)
            var maxCandidate = 0.0
            while (matcher.find()) {
                val candidate = matcher.group(1) ?: ""
                val num = candidate.toDoubleOrNull()
                if (num != null && num > 0 && num < 10000000) {
                    if (num > maxCandidate) {
                        maxCandidate = num
                        amount = candidate
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
                if (candidate.isNotEmpty() && candidate.length > 1 && !candidate.lowercase().contains("google pay") && !candidate.lowercase().contains("phonepe")) {
                    merchant = cleanMerchantName(candidate)
                    break
                }
            }
        }

        // 4. UPI Ref / Transaction ID / UTR Scanner
        val refPattern = Pattern.compile("""(?:UPI\s*(?:Ref(?:erence)?|Txn|Transaction)?\s*(?:No|ID|Num)?[:\s]*|UTR[:\s]*|Txn\s*ID[:\s]*|Transaction\s*ID[:\s]*|Ref\s*(?:No|ID)?[:\s]*|Google transaction ID[:\s]*|PhonePe transaction ID[:\s]*)([0-9A-Za-z]{8,24})""", Pattern.CASE_INSENSITIVE)
        val refMatcher = refPattern.matcher(text)
        if (refMatcher.find()) {
            refId = refMatcher.group(1)?.trim() ?: ""
        } else {
            // Standalone 12-digit standard UPI UTR pattern
            val utr12Matcher = Pattern.compile("""\b([0-9]{12})\b""").matcher(text)
            if (utr12Matcher.find()) {
                refId = utr12Matcher.group(1) ?: ""
            }
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

        val logPendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val dismissIntent = Intent(this, NotificationDismissReceiver::class.java)
        val dismissPendingIntent = PendingIntent.getBroadcast(
            this,
            (System.currentTimeMillis() + 1).toInt(),
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val amountDisplay = if (parsedData.amount.isNotEmpty()) "₹${parsedData.amount}" else "Receipt"
        val title = "💳 $amountDisplay at ${parsedData.merchant}"
        val body = "Paid via ${parsedData.appSource} • Tap to log transaction"

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(logPendingIntent)
            .addAction(R.mipmap.ic_launcher, "⚡ Log Now", logPendingIntent)
            .addAction(R.mipmap.ic_launcher, "✕ Dismiss", dismissPendingIntent)
            .build()

        notificationManager.notify(1099, notification)
    }
}
