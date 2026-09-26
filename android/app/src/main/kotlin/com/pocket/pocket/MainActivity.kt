package com.pocket.pocket

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CONTACT_CHANNEL = "com.pocket.pocket/contact_picker"
    private val SHARED_TX_CHANNEL = "com.pocket.pocket/shared_transaction"
    private val WIDGET_CHANNEL = "com.pocket.pocket/widget_events"
    private val AUTO_IMPORT_CHANNEL = "com.pocket.pocket/auto_import"
    private val REQUEST_CODE_PICK_CONTACT = 1001
    private val REQUEST_CODE_SMS_PERMISSION = 1002

    private var pendingResult: MethodChannel.Result? = null
    private var pendingSmsResult: MethodChannel.Result? = null
    private var sharedTxChannel: MethodChannel? = null
    private var widgetChannel: MethodChannel? = null
    private var autoImportChannel: MethodChannel? = null
    private var screenshotObserver: PocketScreenshotObserver? = null
    private var pendingSharedTransactionPayload: String? = null
    private var pendingWidgetUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Zero-Permission Native Contact Picker Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickContact") {
                if (pendingResult != null) {
                    result.error("ALREADY_PENDING", "A contact picking operation is already in progress", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                try {
                    val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                    startActivityForResult(intent, REQUEST_CODE_PICK_CONTACT)
                } catch (e: Exception) {
                    try {
                        val fallbackIntent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
                        startActivityForResult(fallbackIntent, REQUEST_CODE_PICK_CONTACT)
                    } catch (ex: Exception) {
                        pendingResult = null
                        result.error("PICKER_FAILED", "Failed to launch system contact picker: ${ex.localizedMessage}", null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Shared UPI / Screenshot Transaction Channel
        sharedTxChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARED_TX_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getPendingSharedTransaction") {
                    val payload = pendingSharedTransactionPayload
                    pendingSharedTransactionPayload = null
                    result.success(payload)
                } else {
                    result.notImplemented()
                }
            }
        }

        // 3. Widget Quick Add Launch Channel & Desktop Pinning
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingWidgetUri" -> {
                        val uri = pendingWidgetUri
                        pendingWidgetUri = null
                        result.success(uri)
                    }
                    "requestPinWidget" -> {
                        val widgetType = call.argument<String>("widgetType") ?: "card"
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            try {
                                val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                                if (appWidgetManager.isRequestPinAppWidgetSupported) {
                                    val providerClass = when (widgetType) {
                                        "runway" -> PocketRunwayWidgetProvider::class.java
                                        "bar" -> PocketBarWidgetProvider::class.java
                                        else -> PocketCardWidgetProvider::class.java
                                    }
                                    val myProvider = ComponentName(applicationContext, providerClass)
                                    val success = appWidgetManager.requestPinAppWidget(myProvider, null, null)
                                    result.success(success)
                                } else {
                                    result.success(false)
                                }
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // 4. Real-Time Auto-Import Channel (Notification Listener, Accessibility & Screenshot Watcher)
        autoImportChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_IMPORT_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingTransactions" -> {
                        val data = PocketNotificationListener.getPendingTransactions(applicationContext)
                        result.success(data)
                    }
                    "clearPendingTransactions" -> {
                        PocketNotificationListener.clearPendingTransactions(applicationContext)
                        result.success(true)
                    }
                    "checkPermissions" -> {
                        val map = mapOf(
                            "notificationListener" to isNotificationListenerEnabled(),
                            "accessibility" to isAccessibilityServiceEnabled(),
                            "screenshotWatcher" to (screenshotObserver != null),
                            "smsListener" to (ContextCompat.checkSelfPermission(this@MainActivity, android.Manifest.permission.RECEIVE_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED)
                        )
                        result.success(map)
                    }
                    "requestSmsPermission" -> {
                        if (ContextCompat.checkSelfPermission(this@MainActivity, android.Manifest.permission.RECEIVE_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            if (pendingSmsResult != null) {
                                result.error("ALREADY_PENDING", "An SMS permission request is already pending", null)
                            } else {
                                pendingSmsResult = result
                                ActivityCompat.requestPermissions(
                                    this@MainActivity,
                                    arrayOf(android.Manifest.permission.RECEIVE_SMS, android.Manifest.permission.READ_SMS),
                                    REQUEST_CODE_SMS_PERMISSION
                                )
                            }
                        }
                    }
                    "openNotificationListenerSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FAILED", e.localizedMessage, null)
                        }
                    }
                    "openAccessibilitySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("FAILED", e.localizedMessage, null)
                        }
                    }
                    "setScreenshotWatcherEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setScreenshotWatcher(enabled)
                        result.success(screenshotObserver != null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Auto-enable screenshot watcher by default
        setScreenshotWatcher(true)

        // Check if app was started with intent extra or widget uri
        handleIntentForSharedTransaction(intent)
        handleIntentForWidget(intent)
    }

    private fun isNotificationListenerEnabled(): Boolean {
        return NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val expectedService = "${packageName}/${PocketAccessibilityService::class.java.name}"
        return enabledServices.contains(expectedService) || enabledServices.contains(PocketAccessibilityService::class.java.simpleName)
    }

    private fun setScreenshotWatcher(enabled: Boolean) {
        if (enabled) {
            if (screenshotObserver == null) {
                screenshotObserver = PocketScreenshotObserver(applicationContext)
                try {
                    contentResolver.registerContentObserver(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        true,
                        screenshotObserver!!
                    )
                } catch (_: Exception) {}
            }
        } else {
            screenshotObserver?.let {
                try {
                    contentResolver.unregisterContentObserver(it)
                } catch (_: Exception) {}
                screenshotObserver = null
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntentForSharedTransaction(intent)
        handleIntentForWidget(intent)
    }

    private fun handleIntentForSharedTransaction(intent: Intent?) {
        val payload = intent?.getStringExtra("shared_transaction_payload")
        if (!payload.isNullOrBlank()) {
            pendingSharedTransactionPayload = payload
            sharedTxChannel?.invokeMethod("onSharedTransactionReceived", payload)
        }
    }

    private fun handleIntentForWidget(intent: Intent?) {
        val dataUri = intent?.dataString
        if (dataUri != null && (dataUri.startsWith("pocket://") || dataUri.contains("quick-add"))) {
            pendingWidgetUri = dataUri
            widgetChannel?.invokeMethod("onWidgetUriReceived", dataUri)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_PICK_CONTACT) {
            val result = pendingResult ?: return
            pendingResult = null

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

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_SMS_PERMISSION) {
            val result = pendingSmsResult ?: return
            pendingSmsResult = null
            
            val granted = grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED
            result.success(granted)
        }
    }
}
