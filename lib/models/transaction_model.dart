import 'category_model.dart';

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String walletId;
  final DateTime date;
  final String? note;
  final String? receiptImagePath;
  final String? senderName;
  final String? receiverName;
  final String? refId;
  final String? counterpartyLast4;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.walletId,
    required this.date,
    this.note,
    this.receiptImagePath,
    this.senderName,
    this.receiverName,
    this.refId,
    this.counterpartyLast4,
    required this.createdAt,
  });

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? walletId,
    DateTime? date,
    String? note,
    String? receiptImagePath,
    String? senderName,
    String? receiverName,
    String? refId,
    String? counterpartyLast4,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      date: date ?? this.date,
      note: note ?? this.note,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      senderName: senderName ?? this.senderName,
      receiverName: receiverName ?? this.receiverName,
      refId: refId ?? this.refId,
      counterpartyLast4: counterpartyLast4 ?? this.counterpartyLast4,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.name,
        'categoryId': categoryId,
        'walletId': walletId,
        'date': date.toIso8601String(),
        'note': note,
        'receiptImagePath': receiptImagePath,
        'senderName': senderName,
        'receiverName': receiverName,
        'refId': refId,
        'counterpartyLast4': counterpartyLast4,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        type: TransactionType.values
            .byName(json['type'] as String? ?? 'expense'),
        categoryId: json['categoryId'] as String,
        walletId: json['walletId'] as String,
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        receiptImagePath: json['receiptImagePath'] as String?,
        senderName: json['senderName'] as String?,
        receiverName: json['receiverName'] as String?,
        refId: json['refId'] as String?,
        counterpartyLast4: json['counterpartyLast4'] as String?,
        createdAt: DateTime.parse(
          json['createdAt'] as String? ?? json['date'] as String,
        ),
      );
}
