package com.pocket.pocket

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject
import java.util.UUID
import java.util.regex.Pattern

class PocketAccessibilityService : AccessibilityService() {

    private var lastExtractedHash: String? = null
    private var lastExtractedTimestamp: Long = 0L

    companion object {
        val TARGET_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user",
            "com.phonepe.app",
            "net.one97.paytm",
            "com.dreamplug.androidapp"
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return
        if (!TARGET_PACKAGES.contains(pkg)) return

        val rootNode = rootInActiveWindow ?: return

        try {
            val textList = mutableListOf<String>()
            collectNodeTexts(rootNode, textList)
            if (textList.isEmpty()) return

            val combined = textList.joinToString(" ")
            val lower = combined.lowercase()

            // Check if this screen is an active payment confirmation / success screen
            val isSuccessScreen = (lower.contains("paid") || lower.contains("payment successful") || lower.contains("transfer successful") || lower.contains("payment of")) &&
                    (lower.contains("₹") || lower.contains("rs.") || lower.contains("inr"))

            if (!isSuccessScreen) return

            val amount = extractAmount(combined) ?: return
            val merchant = extractMerchant(textList)
            val refId = extractRefId(combined)

            val eventHash = "$amount-$merchant-$refId"
            val now = System.currentTimeMillis()

            // 15-second cooldown to prevent duplicate captures of the same screen
            if (eventHash == lastExtractedHash && (now - lastExtractedTimestamp) < 15000) {
                return
            }

            lastExtractedHash = eventHash
            lastExtractedTimestamp = now

            val appSource = when (pkg) {
                "com.google.android.apps.nbu.paisa.user" -> "Google Pay"
                "com.phonepe.app" -> "PhonePe"
                "net.one97.paytm" -> "Paytm"
                "com.dreamplug.androidapp" -> "CRED"
                else -> "UPI App"
            }

            val txJson = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("amount", amount)
                put("merchant", merchant)
                put("appSource", appSource)
                put("refId", refId ?: "")
                put("date", now)
                put("detectionSource", "screen_reader")
                put("rawPayload", combined.take(200))
                put("isIncome", false)
            }

            PocketNotificationListener.savePendingTransaction(applicationContext, txJson)

        } catch (e: Exception) {
            // Defensive error handling for accessibility traversal
        }
    }

    private fun collectNodeTexts(node: AccessibilityNodeInfo?, list: MutableList<String>) {
        if (node == null) return
        val txt = node.text?.toString()?.trim()
        if (!txt.isNullOrEmpty() && txt.length > 1) {
            list.add(txt)
        }
        val desc = node.contentDescription?.toString()?.trim()
        if (!desc.isNullOrEmpty() && desc.length > 1 && desc != txt) {
            list.add(desc)
        }

        for (i in 0 until node.childCount) {
            collectNodeTexts(node.getChild(i), list)
        }
    }

    private fun extractAmount(text: String): Double? {
        val pattern = Pattern.compile("(?:₹|rs\\.?|inr)\\s*([0-9]+(?:,[0-9]{2,3})*(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(text)
        if (matcher.find()) {
            val raw = matcher.group(1)?.replace(",", "") ?: return null
            return raw.toDoubleOrNull()
        }
        return null
    }

    private fun extractMerchant(nodes: List<String>): String {
        for (i in 0 until nodes.size) {
            val s = nodes[i]
            val lower = s.lowercase()
            if (lower.startsWith("to ") || lower.startsWith("paid to ")) {
                val candidate = s.replace(Regex("(?i)^(paid to|to)\\s+"), "").trim()
                if (candidate.isNotEmpty() && candidate.length > 2) {
                    return candidate.take(30)
                }
            }
            if (lower == "paid to" && i + 1 < nodes.size) {
                val next = nodes[i + 1].trim()
                if (next.isNotEmpty() && !next.startsWith("₹")) {
                    return next.take(30)
                }
            }
        }

        // Fallback: look for non-amount, non-status capitalized text
        for (s in nodes) {
            val lower = s.lowercase()
            if (!lower.contains("₹") && !lower.contains("payment") && !lower.contains("successful") &&
                !lower.contains("upi") && !lower.contains("bank") && s.length in 3..25) {
                return s
            }
        }

        return "Payment"
    }

    private fun extractRefId(text: String): String? {
        val pattern = Pattern.compile("(?:upi\\s*ref(?:\\s*no)?|ref(?:\\s*id)?|txn(?:\\s*id)?)\\s*[:.-]?\\s*([0-9]{8,16})", Pattern.CASE_INSENSITIVE)
        val matcher = pattern.matcher(text)
        if (matcher.find()) {
            return matcher.group(1)?.trim()
        }
        return null
    }

    override fun onInterrupt() {}
}
