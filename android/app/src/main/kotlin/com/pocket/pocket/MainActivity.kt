package com.pocket.pocket

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {
    private val CONTACT_CHANNEL = "com.pocket.pocket/contact_picker"
    private val UPI_DETECTOR_CHANNEL = "com.pocket.pocket/upi_detector"
    private val WIDGET_CHANNEL = "com.pocket.pocket/system_widget"
    private val REQUEST_CODE_PICK_CONTACT = 1001
    private var pendingContactResult: MethodChannel.Result? = null
    private var upiDetectorChannel: MethodChannel? = null
    private var initialDeepLink: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.data?.let {
            initialDeepLink = it.toString()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.let { uri ->
            val link = uri.toString()
            initialDeepLink = link
            upiDetectorChannel?.invokeMethod("onDeepLinkReceived", link)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Contact Picker Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickContact") {
                if (pendingContactResult != null) {
                    result.error("ALREADY_PENDING", "A contact picking operation is already in progress", null)
                    return@setMethodCallHandler
                }
                pendingContactResult = result
                try {
                    val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                    startActivityForResult(intent, REQUEST_CODE_PICK_CONTACT)
                } catch (e: Exception) {
                    try {
                        val fallbackIntent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
                        startActivityForResult(fallbackIntent, REQUEST_CODE_PICK_CONTACT)
                    } catch (ex: Exception) {
                        pendingContactResult = null
                        result.error("PICKER_FAILED", "Failed to launch system contact picker: ${ex.localizedMessage}", null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. UPI Real-Time Detector Channel
        upiDetectorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPI_DETECTOR_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationAccessGranted" -> {
                        try {
                            val enabledListeners = NotificationManagerCompat.getEnabledListenerPackages(this@MainActivity)
                            result.success(enabledListeners.contains(packageName))
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openNotificationAccessSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", "Unable to open Notification Access settings: ${e.localizedMessage}", null)
                        }
                    }
                    "getPendingDetectedTransactions" -> {
                        val prefs = getSharedPreferences(PocketNotificationListenerService.PREFS_NAME, Context.MODE_PRIVATE)
                        val jsonStr = prefs.getString(PocketNotificationListenerService.KEY_PENDING_LIST, "[]") ?: "[]"
                        result.success(jsonStr)
                    }
                    "removePendingDetectedTransaction" -> {
                        val id = call.argument<String>("id")
                        if (id != null) {
                            val prefs = getSharedPreferences(PocketNotificationListenerService.PREFS_NAME, Context.MODE_PRIVATE)
                            val jsonStr = prefs.getString(PocketNotificationListenerService.KEY_PENDING_LIST, "[]") ?: "[]"
                            try {
                                val jsonArray = JSONArray(jsonStr)
                                val newArray = JSONArray()
                                for (i in 0 until jsonArray.length()) {
                                    val item = jsonArray.getJSONObject(i)
                                    if (item.optString("id") != id) {
                                        newArray.put(item)
                                    }
                                }
                                prefs.edit().putString(PocketNotificationListenerService.KEY_PENDING_LIST, newArray.toString()).apply()
                            } catch (_: Exception) {}
                        }
                        result.success(true)
                    }
                    "clearAllPendingDetectedTransactions" -> {
                        val prefs = getSharedPreferences(PocketNotificationListenerService.PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit().putString(PocketNotificationListenerService.KEY_PENDING_LIST, "[]").apply()
                        result.success(true)
                    }
                    "getInitialDeepLink" -> {
                        val link = initialDeepLink
                        initialDeepLink = null
                        result.success(link)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // 3. System Home Screen Widget Channel (Pinning)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPinWidgetSupported" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val appWidgetManager = AppWidgetManager.getInstance(this)
                            result.success(appWidgetManager.isRequestPinAppWidgetSupported)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "requestPinWidget" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val appWidgetManager = AppWidgetManager.getInstance(this)
                            val provider = ComponentName(this, PocketWidgetProvider::class.java)
                            if (appWidgetManager.isRequestPinAppWidgetSupported) {
                                val pinned = appWidgetManager.requestPinAppWidget(provider, null, null)
                                result.success(pinned)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("PIN_FAILED", "Failed to pin widget: ${e.localizedMessage}", null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_PICK_CONTACT) {
            val result = pendingContactResult ?: return
            pendingContactResult = null

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result.success(null)
                return
            }

            val contactUri: Uri = data.data!!
            var contactName: String? = null
            var contactPhone: String? = null

            try {
                contentResolver.query(contactUri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                        if (nameIndex >= 0) {
                            contactName = cursor.getString(nameIndex)
                        }

                        val numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                        if (numberIndex >= 0) {
                            contactPhone = cursor.getString(numberIndex)
                        }

                        if (contactName.isNullOrBlank()) {
                            val altNameIndex = cursor.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)
                            if (altNameIndex >= 0) {
                                contactName = cursor.getString(altNameIndex)
                            }
                        }
                    }
                }
            } catch (_: Exception) {
            }

            val contactMap = hashMapOf<String, Any?>(
                "name" to (contactName ?: ""),
                "phone" to (contactPhone ?: "")
            )
            result.success(contactMap)
        }
    }
}
