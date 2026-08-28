import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ReceiptService {
  static final ReceiptService _instance = ReceiptService._internal();
  factory ReceiptService() => _instance;
  ReceiptService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<File?> pickOrCaptureReceipt({required ImageSource source}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (picked == null) return null;
      return await saveToPrivateStorage(picked);
    } catch (_) {
      return null;
    }
  }

  Future<File> saveToPrivateStorage(XFile xfile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${appDir.path}/receipts');

    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    // Create .nomedia file so media scanners completely ignore this folder in device gallery
    final noMediaFile = File('${receiptsDir.path}/.nomedia');
    if (!await noMediaFile.exists()) {
      await noMediaFile.create();
    }

    final newFileName = 'receipt_${const Uuid().v4()}.jpg';
    final destination = File('${receiptsDir.path}/$newFileName');
    return await File(xfile.path).copy(destination.path);
  }

  Future<void> deleteReceipt(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
