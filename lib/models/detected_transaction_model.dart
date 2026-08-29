import 'category_model.dart';

class DetectedTransactionModel {
  final String id;
  final double amount;
  final String merchant;
  final String sourceApp;
  final TransactionType type;
  final DateTime timestamp;
  final String rawText;
  final String status;

  const DetectedTransactionModel({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.sourceApp,
    required this.type,
    required this.timestamp,
    required this.rawText,
    this.status = 'pending',
  });

  factory DetectedTransactionModel.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?)?.toLowerCase() ?? 'expense';
    final type = (typeStr == 'income') ? TransactionType.income : TransactionType.expense;

    final ts = json['timestamp'];
    final dateTime = ts is int
        ? DateTime.fromMillisecondsSinceEpoch(ts)
        : (ts is String ? DateTime.tryParse(ts) ?? DateTime.now() : DateTime.now());

    return DetectedTransactionModel(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchant: (json['merchant'] as String?)?.trim() ?? 'UPI Payment',
      sourceApp: (json['sourceApp'] as String?)?.trim() ?? 'UPI',
      type: type,
      timestamp: dateTime,
      rawText: (json['rawText'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'merchant': merchant,
      'sourceApp': sourceApp,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'timestamp': timestamp.millisecondsSinceEpoch,
      'rawText': rawText,
      'status': status,
    };
  }

  DetectedTransactionModel copyWith({
    String? id,
    double? amount,
    String? merchant,
    String? sourceApp,
    TransactionType? type,
    DateTime? timestamp,
    String? rawText,
    String? status,
  }) {
    return DetectedTransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      sourceApp: sourceApp ?? this.sourceApp,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      rawText: rawText ?? this.rawText,
      status: status ?? this.status,
    );
  }
}
