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
  final String? appSource;
  final String? rawPayload;
  final List<String> tags;
  final List<String> attachments; // Invoices, receipts, warranties, warranty PDFs/images
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
    this.appSource,
    this.rawPayload,
    this.tags = const [],
    this.attachments = const [],
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
    String? appSource,
    String? rawPayload,
    List<String>? tags,
    List<String>? attachments,
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
      appSource: appSource ?? this.appSource,
      rawPayload: rawPayload ?? this.rawPayload,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
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
        'appSource': appSource,
        'rawPayload': rawPayload,
        'tags': tags,
        'attachments': attachments,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final rawAmt = json['amount'];
    double parsedAmount = 0.0;
    if (rawAmt is num) {
      parsedAmount = rawAmt.toDouble();
    } else if (rawAmt is String) {
      parsedAmount = double.tryParse(rawAmt.replaceAll(',', '').trim()) ?? 0.0;
    }
    final cleanAmount = ((parsedAmount.abs() * 100).round() / 100.0);

    final rawDate = json['date'];
    final DateTime parsedDate;
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else {
      parsedDate = DateTime.now();
    }

    final rawCreated = json['createdAt'];
    final DateTime parsedCreated;
    if (rawCreated is String) {
      parsedCreated = DateTime.tryParse(rawCreated) ?? parsedDate;
    } else if (rawCreated is int) {
      parsedCreated = DateTime.fromMillisecondsSinceEpoch(rawCreated);
    } else {
      parsedCreated = parsedDate;
    }

    return TransactionModel(
      id: json['id'] as String? ?? 'tx_${DateTime.now().microsecondsSinceEpoch}',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Untitled',
      amount: cleanAmount,
      type: TransactionType.values.asNameMap()[json['type']] ??
          (json['type']?.toString().toLowerCase().contains('income') == true
              ? TransactionType.income
              : TransactionType.expense),
      categoryId: json['categoryId'] as String? ?? 'other_exp',
      walletId: json['walletId'] as String? ?? 'cash',
      date: parsedDate,
      note: json['note'] as String?,
      receiptImagePath: json['receiptImagePath'] as String?,
      senderName: json['senderName'] as String?,
      receiverName: json['receiverName'] as String?,
      refId: json['refId'] as String?,
      counterpartyLast4: json['counterpartyLast4'] as String?,
      appSource: json['appSource'] as String?,
      rawPayload: json['rawPayload'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['receiptImagePath'] != null ? [json['receiptImagePath'] as String] : const []),
      createdAt: parsedCreated,
    );
  }
}
