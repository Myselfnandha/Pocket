import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/services/upi_screenshot_parser_service.dart';

void main() {
  group('UPI Screenshot Parser & Category Heuristic Tests', () {
    test('Correctly parses Google Pay JSON payload', () {
      const gpayJson = '''
      {
        "amount": 450.00,
        "merchant": "Zomato",
        "app_source": "Google Pay",
        "ref_id": "423984729384",
        "image_path": "/data/user/0/com.pocket.pocket/files/receipts/upi_shared_1.jpg",
        "raw_text": "Paid ₹450 to Zomato Completed UPI Transaction ID 423984729384"
      }
      ''';

      final parsed = UpiParsedTransaction.fromPayloadString(gpayJson);
      expect(parsed.amount, 450.0);
      expect(parsed.merchant, 'Zomato');
      expect(parsed.appSource, 'Google Pay');
      expect(parsed.refId, '423984729384');
      expect(parsed.imagePath, '/data/user/0/com.pocket.pocket/files/receipts/upi_shared_1.jpg');
      expect(parsed.suggestedCategoryId, 'cat_food');
    });

    test('Correctly parses PhonePe string amount with comma', () {
      const phonePeJson = '''
      {
        "amount": "1,250.50",
        "merchant": "Blinkit Groceries",
        "app_source": "PhonePe",
        "ref_id": "T26082912345",
        "raw_text": "Payment of ₹1,250.50 to Blinkit Groceries successful"
      }
      ''';

      final parsed = UpiParsedTransaction.fromPayloadString(phonePeJson);
      expect(parsed.amount, 1250.50);
      expect(parsed.merchant, 'Blinkit Groceries');
      expect(parsed.appSource, 'PhonePe');
      expect(parsed.suggestedCategoryId, 'cat_groceries');
    });

    test('Recovers amount and ref from raw OCR text when JSON amount is empty', () {
      const gpayMultiLineJson = '''
      {
        "amount": "",
        "merchant": "Swiggy",
        "app_source": "Google Pay",
        "ref_id": "",
        "raw_text": "Paid to Swiggy\\n₹\\n385.00\\nCompleted\\nUPI Ref No: 489201948291"
      }
      ''';

      final parsed = UpiParsedTransaction.fromPayloadString(gpayMultiLineJson);
      expect(parsed.amount, 385.0);
      expect(parsed.merchant, 'Swiggy');
      expect(parsed.refId, '489201948291');
      expect(parsed.suggestedCategoryId, 'cat_food');
    });

    test('Extracts diverse amount formats in Dart fallback parser', () {
      expect(UpiScreenshotParserService.extractAmount('Debited ₹2,400.00 from A/c'), 2400.0);
      expect(UpiScreenshotParserService.extractAmount('Sent Rs 500 to Alex'), 500.0);
      expect(UpiScreenshotParserService.extractAmount('Total amount: INR 125.50'), 125.50);
      expect(UpiScreenshotParserService.extractAmount('Payment of 750 successful'), 750.0);
    });

    test('Extracts 12-digit reference numbers from raw text', () {
      expect(UpiScreenshotParserService.extractRefId('UTR: 423984729384'), '423984729384');
      expect(UpiScreenshotParserService.extractRefId('Txn ID: CIC9284729184'), 'CIC9284729184');
      expect(UpiScreenshotParserService.extractRefId('Payment completed 492019482910 via SBI'), '492019482910');
    });

    test('Correctly predicts categories for diverse merchants', () {
      expect(UpiScreenshotParserService.predictCategory('Uber India', 'Trip fare paid'), 'cat_transport');
      expect(UpiScreenshotParserService.predictCategory('Amazon Pay', 'Order #1234'), 'cat_shopping');
      expect(UpiScreenshotParserService.predictCategory('Starbucks Coffee', 'Cafe dining'), 'cat_food');
      expect(UpiScreenshotParserService.predictCategory('BookMyShow', 'Movie tickets'), 'cat_entertainment');
      expect(UpiScreenshotParserService.predictCategory('Apollo Pharmacy', 'Medicine purchase'), 'cat_health');
      expect(UpiScreenshotParserService.predictCategory('Airtel Prepaid', 'Recharge bill'), 'cat_bills');
    });

    test('Handles malformed or empty payloads gracefully', () {
      final parsed = UpiParsedTransaction.fromPayloadString('invalid json');
      expect(parsed.merchant, 'UPI Payment');
      expect(parsed.amount, null);
    });
  });
}
