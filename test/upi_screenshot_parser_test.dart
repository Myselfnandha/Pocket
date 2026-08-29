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
        "ref_id": "UPI423984729384",
        "image_path": "/data/user/0/com.pocket.pocket/files/receipts/upi_shared_1.jpg",
        "raw_text": "Paid ₹450 to Zomato Completed UPI Transaction ID 423984729384"
      }
      ''';

      final parsed = UpiParsedTransaction.fromPayloadString(gpayJson);
      expect(parsed.amount, 450.0);
      expect(parsed.merchant, 'Zomato');
      expect(parsed.appSource, 'Google Pay');
      expect(parsed.refId, 'UPI423984729384');
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
