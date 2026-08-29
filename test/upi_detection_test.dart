import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/models/category_model.dart';
import 'package:pocket/models/detected_transaction_model.dart';
import 'package:pocket/models/wallet_model.dart';
import 'package:pocket/services/upi_detection_service.dart';

void main() {
  group('UPI Detection Model & Heuristics Tests', () {
    test('DetectedTransactionModel serializes and deserializes properly', () {
      final now = DateTime.now();
      final model = DetectedTransactionModel(
        id: 'test_tx_123',
        amount: 450.50,
        merchant: 'Swiggy',
        sourceApp: 'Google Pay',
        type: TransactionType.expense,
        timestamp: now,
        rawText: 'Paid Rs. 450.50 to Swiggy on 29Aug',
        status: 'pending',
      );

      final json = model.toJson();
      expect(json['id'], 'test_tx_123');
      expect(json['amount'], 450.50);
      expect(json['merchant'], 'Swiggy');
      expect(json['sourceApp'], 'Google Pay');
      expect(json['type'], 'expense');
      expect(json['status'], 'pending');

      final reconstructed = DetectedTransactionModel.fromJson(json);
      expect(reconstructed.id, model.id);
      expect(reconstructed.amount, model.amount);
      expect(reconstructed.merchant, model.merchant);
      expect(reconstructed.sourceApp, model.sourceApp);
      expect(reconstructed.type, model.type);
    });

    test('UpiDetectionService.matchWalletForApp accurately maps UPI and Bank wallets', () {
      final wallets = [
        const WalletModel(id: 'w1', name: 'Cash In Hand', icon: '💵', colorValue: 0xFF4CAF50, walletType: WalletType.cash, currentBalance: 1000),
        const WalletModel(id: 'w2', name: 'HDFC Salary Bank', icon: '🏦', colorValue: 0xFF2196F3, walletType: WalletType.bank, currentBalance: 50000),
        const WalletModel(id: 'w3', name: 'GPay UPI', icon: '📱', colorValue: 0xFF9C27B0, walletType: WalletType.upi, currentBalance: 5000),
        const WalletModel(id: 'w4', name: 'PhonePe Wallet', icon: '🟣', colorValue: 0xFF5F259F, walletType: WalletType.upi, currentBalance: 2500),
        const WalletModel(id: 'w5', name: 'CRED Card', icon: '💳', colorValue: 0xFF000000, walletType: WalletType.creditCard, currentBalance: 0),
      ];

      expect(UpiDetectionService.matchWalletForApp('Google Pay', wallets)?.id, 'w3');
      expect(UpiDetectionService.matchWalletForApp('GPay', wallets)?.id, 'w3');
      expect(UpiDetectionService.matchWalletForApp('PhonePe', wallets)?.id, 'w4');
      expect(UpiDetectionService.matchWalletForApp('CRED', wallets)?.id, 'w5');
      expect(UpiDetectionService.matchWalletForApp('HDFC Bank', wallets)?.id, 'w2');
    });

    test('UpiDetectionService.predictCategoryForMerchant predicts Food, Transport, Shopping, Bills correctly', () {
      final categories = [
        const CategoryModel(id: 'cat_food', name: 'Food & Dining', icon: '🍔', colorValue: 0xFFFF5722, type: TransactionType.expense),
        const CategoryModel(id: 'cat_transport', name: 'Transportation', icon: '🚗', colorValue: 0xFF2196F3, type: TransactionType.expense),
        const CategoryModel(id: 'cat_shopping', name: 'Shopping', icon: '🛍️', colorValue: 0xFF9C27B0, type: TransactionType.expense),
        const CategoryModel(id: 'cat_entertainment', name: 'Entertainment', icon: '🎬', colorValue: 0xFFE91E63, type: TransactionType.expense),
        const CategoryModel(id: 'cat_bills', name: 'Bills & Utilities', icon: '💡', colorValue: 0xFFFF9800, type: TransactionType.expense),
        const CategoryModel(id: 'cat_health', name: 'Health & Medical', icon: '💊', colorValue: 0xFF009688, type: TransactionType.expense),
        const CategoryModel(id: 'cat_salary', name: 'Salary', icon: '💰', colorValue: 0xFF4CAF50, type: TransactionType.income),
      ];

      // Food
      expect(UpiDetectionService.predictCategoryForMerchant('Swiggy', categories)?.id, 'cat_food');
      expect(UpiDetectionService.predictCategoryForMerchant('Zomato Order', categories)?.id, 'cat_food');
      expect(UpiDetectionService.predictCategoryForMerchant('Starbucks Coffee', categories)?.id, 'cat_food');
      expect(UpiDetectionService.predictCategoryForMerchant('Dominos Pizza', categories)?.id, 'cat_food');

      // Transport & Fuel
      expect(UpiDetectionService.predictCategoryForMerchant('Uber Trip', categories)?.id, 'cat_transport');
      expect(UpiDetectionService.predictCategoryForMerchant('Ola Cabs', categories)?.id, 'cat_transport');
      expect(UpiDetectionService.predictCategoryForMerchant('Indian Oil Petrol Pump', categories)?.id, 'cat_transport');
      expect(UpiDetectionService.predictCategoryForMerchant('Fastag Recharge', categories)?.id, 'cat_transport');

      // Shopping
      expect(UpiDetectionService.predictCategoryForMerchant('Amazon India', categories)?.id, 'cat_shopping');
      expect(UpiDetectionService.predictCategoryForMerchant('Flipkart Internet', categories)?.id, 'cat_shopping');
      expect(UpiDetectionService.predictCategoryForMerchant('Blinkit Groceries', categories)?.id, 'cat_shopping');
      expect(UpiDetectionService.predictCategoryForMerchant('Zepto Now', categories)?.id, 'cat_shopping');

      // Bills
      expect(UpiDetectionService.predictCategoryForMerchant('Bescom Electricity Bill', categories)?.id, 'cat_bills');
      expect(UpiDetectionService.predictCategoryForMerchant('Jio Mobile Recharge', categories)?.id, 'cat_bills');

      // Health
      expect(UpiDetectionService.predictCategoryForMerchant('Apollo Pharmacy', categories)?.id, 'cat_health');
      expect(UpiDetectionService.predictCategoryForMerchant('1mg Medicines', categories)?.id, 'cat_health');

      // Salary
      expect(UpiDetectionService.predictCategoryForMerchant('Monthly Salary Payout', categories)?.id, 'cat_salary');
    });
  });
}
