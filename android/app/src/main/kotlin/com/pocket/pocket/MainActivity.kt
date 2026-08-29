package com.pocket.pocket

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CONTACT_CHANNEL = "com.pocket.pocket/contact_picker"
    private val REQUEST_CODE_PICK_CONTACT = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
}
