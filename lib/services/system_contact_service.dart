import 'package:flutter/services.dart';

class SelectedContact {
  final String name;
  final String? phone;

  const SelectedContact({
    required this.name,
    this.phone,
  });

  @override
  String toString() => 'SelectedContact(name: $name, phone: $phone)';
}

class SystemContactService {
  static const MethodChannel _channel = MethodChannel('com.pocket.pocket/contact_picker');

  /// Launches the native Android system contact picker without requiring READ_CONTACTS permission.
  static Future<SelectedContact?> pickContact() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickContact');
      if (result == null) return null;

      final rawName = (result['name'] as String?)?.trim() ?? '';
      final rawPhone = (result['phone'] as String?)?.trim() ?? '';

      // Clean phone number: keep digits and leading '+'
      String? cleanPhone;
      if (rawPhone.isNotEmpty) {
        cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
        if (cleanPhone.isEmpty) cleanPhone = null;
      }

      if (rawName.isEmpty && (cleanPhone == null || cleanPhone.isEmpty)) {
        return null;
      }

      return SelectedContact(
        name: rawName.isNotEmpty ? rawName : (cleanPhone ?? 'Unknown Contact'),
        phone: cleanPhone,
      );
    } catch (_) {
      return null;
    }
  }
}
