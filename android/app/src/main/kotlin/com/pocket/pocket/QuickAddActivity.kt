package com.pocket.pocket

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class QuickAddActivity : FlutterActivity() {
    private val SHARED_TX_CHANNEL = "com.pocket.pocket/shared_transaction"
    private var sharedTxChannel: MethodChannel? = null
    private var pendingSharedTransactionPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Zero-latency instant HUD display over system wallpaper
        overridePendingTransition(0, 0)
        super.onCreate(savedInstanceState)

        // True edge-to-edge transparent wallpaper overlay
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )
        }

        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            or WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        )
    }

    override fun getBackgroundMode(): BackgroundMode {
        return BackgroundMode.transparent
    }

    override fun getInitialRoute(): String {
        return "/quick-add-dialog"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        handleIntentForSharedTransaction(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        sharedTxChannel?.setMethodCallHandler(null)
        sharedTxChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntentForSharedTransaction(intent)
    }

    private fun handleIntentForSharedTransaction(intent: Intent?) {
        val payload = intent?.getStringExtra("shared_transaction_payload")
        if (!payload.isNullOrBlank()) {
            pendingSharedTransactionPayload = payload
            sharedTxChannel?.invokeMethod("onSharedTransactionReceived", payload)
        }
    }

    override fun finish() {
        super.finish()
        // Seamless instant exit with zero transition delay
        overridePendingTransition(0, 0)
    }

    override fun onDestroy() {
        sharedTxChannel?.setMethodCallHandler(null)
        sharedTxChannel = null
        pendingSharedTransactionPayload = null
        super.onDestroy()
    }
}
