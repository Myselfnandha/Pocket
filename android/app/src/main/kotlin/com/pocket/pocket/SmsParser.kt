package com.pocket.pocket

import org.json.JSONObject
import java.util.UUID
import java.util.regex.Pattern

data class ParsedSmsTransaction(
    val id: String = UUID.randomUUID().toString(),
    val amount: Double,
    val merchant: String,
    val appSource: String,
    val refId: String?,
    val date: Long,
    val detectionSource: String = "sms",
    val rawPayload: String,
    val isIncome: Boolean,
    val accountLast4: String? = null,
    val senderBank: String? = null,
    val senderName: String? = null,
    val receiverName: String? = null,
    val sourceMessageId: String? = null
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("amount", amount)
            put("merchant", merchant)
            put("appSource", appSource)
            put("refId", refId ?: "")
            put("date", date)
            put("detectionSource", detectionSource)
            put("rawPayload", rawPayload)
            put("isIncome", isIncome)
            if (accountLast4 != null) {
                put("counterpartyLast4", accountLast4)
            }
            if (senderBank != null) {
                put("senderBank", senderBank)
            }
            if (senderName != null) {
                put("senderName", senderName)
            }
            if (receiverName != null) {
                put("receiverName", receiverName)
            }
            if (sourceMessageId != null) {
                put("sourceMessageId", sourceMessageId)
            }
        }
    }
}

object SmsParser {

    private val AMOUNT_PATTERN = Pattern.compile(
        "(?:₹|rs\\.?|rs:|inr|usd|\\$)\\s*([0-9]+(?:,[0-9]{2,3})*(?:\\.[0-9]{1,2})?)",
        Pattern.CASE_INSENSITIVE
    )

    private val SECONDARY_AMOUNT_PATTERN = Pattern.compile(
        "(?:paid|debited(?:\\s+by|\\s+for)?|spent|credited(?:\\s+with|\\s+for)?|transferred)\\s+(?:₹|rs\\.?|rs:|inr|usd|\\$)?\\s*([0-9]+(?:,[0-9]{2,3})*(?:\\.[0-9]{1,2})?)",
        Pattern.CASE_INSENSITIVE
    )

    private val ACCOUNT_LAST4_PATTERN = Pattern.compile(
        "(?:a/c|ac|account|card|acct|loan\\s*a/c|loan\\s*no\\.?)\\s*(?:no\\.?|num\\.?)?\\s*(?:ending(?:\\s+in|\\s+with)?)?\\s*[:\\s]*[0-9]*[*xX.-]+([0-9]{3,6})\\b",
        Pattern.CASE_INSENSITIVE
    )

    private val SECONDARY_ACCOUNT_PATTERN = Pattern.compile(
        "(?:a/c|ac|account|card|acct|loan\\s*a/c|loan\\s*no\\.?)\\s*(?:no\\.?|num\\.?)?\\s*(?:ending(?:\\s+in|\\s+with)?)?\\s*[:\\s]*[*xX.-]*([0-9]{3,6})\\b",
        Pattern.CASE_INSENSITIVE
    )

    private val REF_ID_PATTERN = Pattern.compile(
        "(?:upi\\s*ref(?:\\s*no)?|ref(?:\\s*id|\\s*no)?|txn(?:\\s*id)?|rrn)[:\\s.-]*([0-9]{8,18})",
        Pattern.CASE_INSENSITIVE
    )

    private val MERCHANT_PATTERNS = listOf(
        // UPI ref / info patterns: "UPI/P2P/123456789012/Receiver", "UPI/P2A/...", "UPI/DR/...", "UPI/REV/..."
        Pattern.compile("""UPI/(?:P2P|P2M|P2A|DR|CR|REV)/[0-9]+/([A-Za-z0-9&'._\s]{2,35})""", Pattern.CASE_INSENSITIVE),
        // UPI Lite transactions: "via UPI Lite to Merchant" or "using UPI Lite to Merchant"
        Pattern.compile("""(?:via|using)\s+upi\s+lite\s+to\s+([A-Za-z0-9&'._\s]{2,35}?)""", Pattern.CASE_INSENSITIVE),
        // "to VPA user@bank" or "to user@bank"
        Pattern.compile("""(?:to\s+vpa|to)\s+([a-zA-Z0-9.\-_]{2,35}@[a-zA-Z0-9.\-_]{2,20})""", Pattern.CASE_INSENSITIVE),
        // "trf to Maggi", "transfer to John", "transferred to Alex"
        Pattern.compile("(?:trf\\s+to|transfer\\s+to|transferred\\s+to)\\s+([A-Za-z0-9&'._\\s]{2,35}?)(?:\\s+(?:ref|refno|upi|via|on|avl|bal|\\.|$)|\$)", Pattern.CASE_INSENSITIVE),
        // "paid to Zomato", "payment to Swiggy", "sent to Blinkit", "paid towards Swiggy", "debited towards Flipkart"
        Pattern.compile("(?:paid\\s+(?:to|towards)|payment\\s+(?:to|towards)|sent\\s+(?:to|towards)|debited\\s+(?:for|towards)|spent\\s+(?:on|towards))\\s+([A-Za-z0-9&'._\\s]{2,35}?)(?:\\s+(?:via|using|on|ref|upi|for|\\.|$)|\$)", Pattern.CASE_INSENSITIVE),
        // "towards AMAZON PAY", "towards: STARBUCKS", "for NETFLIX"
        Pattern.compile("(?:towards|for)[:\\s]+([A-Za-z0-9&'._\\s]{2,35}?)(?:\\s+(?:via|using|on|ref|upi|avl|bal|\\.|$)|\$)", Pattern.CASE_INSENSITIVE),
        // "at RELIANCE RETAIL", "at STARBUCKS"
        Pattern.compile("(?:\\bat\\s+)([A-Za-z0-9&'._\\s]{2,35}?)(?:\\s+(?:on|via|ref|upi|avl|bal|\\.|$)|\$)", Pattern.CASE_INSENSITIVE),
        // "credited by transfer from TECHCORP"
        Pattern.compile("(?:from|by\\s+transfer\\s+from)\\s+([A-Za-z0-9&'._\\s]{2,35}?)(?:\\s+(?:ref|upi|on|avl|bal|\\.|$)|\$)", Pattern.CASE_INSENSITIVE)
    )

    fun parse(sender: String, body: String, timestamp: Long, smsId: String? = null): ParsedSmsTransaction? {
        val lower = body.lowercase()

        // 1. Check for transaction indicators
        val isDebit = isDebitText(lower)
        val isCredit = isCreditText(lower)

        if (!isDebit && !isCredit) {
            return null
        }

        // 2. Extract Amount
        val amount = extractAmount(body) ?: return null
        if (amount <= 0.0) return null

        // 3. Extract Merchant
        val merchant = extractMerchant(sender, body, isCredit)

        // 4. Extract Ref ID
        val refId = extractRefId(body)

        // 5. Extract Account Last 4
        val accountLast4 = extractAccountLast4(body)

        // Clean sender display
        val cleanSender = cleanSenderAddress(sender)

        // 6. Extract Bank & Parties
        val senderBank = extractSenderBank(sender, body)

        val isGenericMerchant = merchant.equals("Payment", ignoreCase = true) ||
                merchant.equals("UPI Payment", ignoreCase = true) ||
                merchant.equals("Payment Received", ignoreCase = true) ||
                merchant.equals(cleanSender, ignoreCase = true) ||
                (senderBank != null && merchant.equals(senderBank, ignoreCase = true))

        val senderName = if (isCredit && !isGenericMerchant) merchant else null
        val receiverName = if (!isCredit && !isGenericMerchant) merchant else null

        val stableId = if (!smsId.isNullOrBlank()) {
            "sms_$smsId"
        } else {
            val contentHash = Math.abs((sender + "_" + body + "_" + timestamp).hashCode())
            "sms_$contentHash"
        }

        return ParsedSmsTransaction(
            id = stableId,
            amount = amount,
            merchant = merchant,
            appSource = "SMS ($cleanSender)",
            refId = refId,
            date = if (timestamp > 0) timestamp else System.currentTimeMillis(),
            rawPayload = body,
            isIncome = isCredit,
            accountLast4 = accountLast4,
            senderBank = senderBank,
            senderName = senderName,
            receiverName = receiverName,
            sourceMessageId = smsId ?: stableId
        )
    }

    fun extractSenderBank(sender: String, body: String): String? {
        val combined = "$sender $body".lowercase()
        return when {
            combined.contains("sbiinb") || combined.contains("sbipay") || combined.contains("state bank") || combined.contains("sbi") -> "State Bank of India"
            combined.contains("hdfcbk") || combined.contains("hdfc") -> "HDFC Bank"
            combined.contains("icicib") || combined.contains("icici") -> "ICICI Bank"
            combined.contains("axisbk") || combined.contains("axis") -> "Axis Bank"
            combined.contains("kotakb") || combined.contains("kotak") -> "Kotak Mahindra Bank"
            combined.contains("indusind") || combined.contains("indusb") -> "IndusInd Bank"
            combined.contains("indian bank") || combined.contains("indbnk") -> "Indian Bank"
            combined.contains("pnbsms") || combined.contains("punjab national") || combined.contains("pnb") -> "Punjab National Bank"
            combined.contains("bobsms") || combined.contains("bank of baroda") || combined.contains("bob") -> "Bank of Baroda"
            combined.contains("canbnk") || combined.contains("canara") -> "Canara Bank"
            combined.contains("unionb") || combined.contains("ubin") || combined.contains("uboi") || combined.contains("union bank") -> "Union Bank of India"
            combined.contains("idfcfb") || combined.contains("idfc") -> "IDFC FIRST Bank"
            combined.contains("fedbnk") || combined.contains("federal bank") -> "Federal Bank"
            combined.contains("rblbnk") || combined.contains("rbl") -> "RBL Bank"
            combined.contains("yesbnk") || combined.contains("yes bank") -> "Yes Bank"
            combined.contains("paytmb") || combined.contains("paytm bank") -> "Paytm Payments Bank"
            combined.contains("airtel") -> "Airtel Payments Bank"
            combined.contains("aubank") || combined.contains("au small finance") -> "AU Small Finance Bank"
            combined.contains("scbl") || combined.contains("standard chartered") || combined.contains("stanchart") -> "Standard Chartered"
            combined.contains("dbs") || combined.contains("digibank") -> "DBS Bank"
            combined.contains("equitas") || combined.contains("eqitas") -> "Equitas Small Finance Bank"
            combined.contains("cbin") || combined.contains("central bank") -> "Central Bank of India"
            combined.contains("boisms") || combined.contains("bank of india") || combined.contains("boi") -> "Bank of India"
            combined.contains("jiopay") || combined.contains("jio payments") -> "Jio Payments Bank"
            combined.contains("slice") -> "Slice"
            combined.contains("cred") -> "CRED"
            combined.contains("jupiter") -> "Jupiter"
            combined.contains("fi money") || combined.contains("fibank") -> "Fi Money"
            else -> null
        }
    }

    private fun isDebitText(lower: String): Boolean {
        val hasDebitKeyword = lower.contains("debited") ||
                lower.contains("spent") ||
                lower.contains("paid") ||
                Regex("""\bsent\b""").containsMatchIn(lower) ||
                lower.contains("withdrawn") ||
                lower.contains("purchase") ||
                lower.contains("payment of") ||
                lower.contains("transferred to")
        val hasCurrency = Regex("""(?i)(?:₹|rs\.?|inr|usd|\$)""").containsMatchIn(lower)
        val isOtp = lower.contains("otp") || lower.contains("verification code") || lower.contains("one time password")
        val isExplicitFailure = lower.contains("failed") || lower.contains("declined") || lower.contains("unsuccessful")
        val isPendingRequestOnly = lower.contains("request") &&
                !lower.contains("debited") &&
                !lower.contains("spent") &&
                !lower.contains("paid") &&
                !lower.contains("transferred") &&
                !lower.contains("successful")
        return hasDebitKeyword && hasCurrency && !isOtp && !isExplicitFailure && !isPendingRequestOnly
    }

    private fun isCreditText(lower: String): Boolean {
        val hasCreditKeyword = lower.contains("credited") ||
                Regex("""\breceived\b""").containsMatchIn(lower) ||
                lower.contains("deposited") ||
                lower.contains("salary") ||
                lower.contains("refund") ||
                lower.contains("cashback") ||
                lower.contains("added to your account") ||
                lower.contains("payment received")
        val hasCurrency = Regex("""(?i)(?:₹|rs\.?|inr|usd|\$)""").containsMatchIn(lower)
        val isOtp = lower.contains("otp") || lower.contains("verification code") || lower.contains("one time password")
        val isExplicitFailure = lower.contains("failed") || lower.contains("declined") || lower.contains("unsuccessful")
        val isPendingRequestOnly = lower.contains("request") &&
                !lower.contains("credited") &&
                !lower.contains("deposited") &&
                !lower.contains("received") &&
                !lower.contains("successful")
        return hasCreditKeyword && hasCurrency && !lower.contains("debited") && !isOtp && !isExplicitFailure && !isPendingRequestOnly
    }

    fun extractAmount(text: String): Double? {
        val matcher = AMOUNT_PATTERN.matcher(text)
        if (matcher.find()) {
            val raw = matcher.group(1)?.replace(",", "")?.trim()
            val parsed = raw?.toDoubleOrNull()
            if (parsed != null && parsed > 0.0) return parsed
        }

        val secMatcher = SECONDARY_AMOUNT_PATTERN.matcher(text)
        if (secMatcher.find()) {
            val raw = secMatcher.group(1)?.replace(",", "")?.trim()
            return raw?.toDoubleOrNull()
        }

        return null
    }

    fun extractMerchant(sender: String, body: String, isCredit: Boolean): String {
        for (pattern in MERCHANT_PATTERNS) {
            val matcher = pattern.matcher(body)
            if (matcher.find()) {
                val candidate = matcher.group(1)?.trim()
                if (!candidate.isNullOrEmpty() &&
                    !candidate.equals("vpa", true) &&
                    !candidate.equals("account", true) &&
                    !candidate.equals("bank", true)
                ) {
                    val cleaned = cleanMerchantName(candidate)
                    if (cleaned.length >= 2) return cleaned
                }
            }
        }

        // Contextual fallback
        if (isCredit) {
            if (body.contains("salary", ignoreCase = true)) return "Salary"
            if (body.contains("refund", ignoreCase = true)) return "Refund"
            if (body.contains("cashback", ignoreCase = true)) return "Cashback"
            return "Payment Received"
        }

        if (body.contains("upi", ignoreCase = true)) {
            return "UPI Payment"
        }

        return "Payment"
    }

    fun extractRefId(text: String): String? {
        val matcher = REF_ID_PATTERN.matcher(text)
        if (matcher.find()) {
            return matcher.group(1)?.trim()
        }
        return null
    }

    fun extractAccountLast4(text: String): String? {
        val matcher = ACCOUNT_LAST4_PATTERN.matcher(text)
        if (matcher.find()) {
            val candidate = matcher.group(1)?.trim()
            if (!candidate.isNullOrEmpty()) {
                return if (candidate.length > 4) candidate.substring(candidate.length - 4) else candidate
            }
        }
        val secMatcher = SECONDARY_ACCOUNT_PATTERN.matcher(text)
        if (secMatcher.find()) {
            val candidate = secMatcher.group(1)?.trim()
            if (!candidate.isNullOrEmpty()) {
                return if (candidate.length > 4) candidate.substring(candidate.length - 4) else candidate
            }
        }
        return null
    }

    private fun cleanMerchantName(name: String): String {
        return name
            .replace(Regex("(?i)\\b(ltd|pvt|limited|india|store|upi|payment|pos|ecom|vpa)\\b"), "")
            .replace(Regex("[^a-zA-Z0-9&'._\\s-]"), "")
            .trim()
            .take(30)
            .ifEmpty { "Payment" }
    }

    private fun cleanSenderAddress(sender: String): String {
        // Indian bank SMS format has a 2-letter operator prefix e.g. "VK-INDBNK", "AD-HDFCBK", "JM-SBIINB"
        val parts = sender.split("-")
        val core = if (parts.size > 1) parts[1] else sender
        return core.trim().take(12)
    }
}
