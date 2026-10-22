class PendingTransactionModel {
  final String id;
  final double amount;
  final String merchant;
  final String appSource;
  final String? refId;
  final DateTime date;
  final String? suggestedCategoryId;
  final String? suggestedWalletId;
  final String? imagePath;
  final String detectionSource; // 'notification', 'screen_reader', 'screenshot'
  final String? rawPayload;
  final String? counterpartyLast4;
  final bool isIncome;
  final String? sourceMessageId;

  const PendingTransactionModel({
    required this.id,
    required this.amount,
    required this.merchant,
    this.appSource = 'UPI App',
    this.refId,
    required this.date,
    this.suggestedCategoryId,
    this.suggestedWalletId,
    this.imagePath,
    this.detectionSource = 'notification',
    this.rawPayload,
    this.counterpartyLast4,
    this.isIncome = false,
    this.sourceMessageId,
  });

  /// Stable deterministic signature for idempotency and tombstone checks
  String get signature {
    final ref = (refId != null && refId!.trim().isNotEmpty) ? refId!.trim() : '';
    final last4 = (counterpartyLast4 != null && counterpartyLast4!.trim().isNotEmpty) ? counterpartyLast4!.trim() : '';
    final timeMin = date.millisecondsSinceEpoch ~/ (1000 * 60 * 30); // 30-minute bucket
    return '${amount.toStringAsFixed(2)}_${timeMin}_${ref}_$last4';
  }

  PendingTransactionModel copyWith({
    String? id,
    double? amount,
    String? merchant,
    String? appSource,
    String? refId,
    DateTime? date,
    String? suggestedCategoryId,
    String? suggestedWalletId,
    String? imagePath,
    String? detectionSource,
    String? rawPayload,
    String? counterpartyLast4,
    bool? isIncome,
    String? sourceMessageId,
  }) {
    return PendingTransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      appSource: appSource ?? this.appSource,
      refId: refId ?? this.refId,
      date: date ?? this.date,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      suggestedWalletId: suggestedWalletId ?? this.suggestedWalletId,
      imagePath: imagePath ?? this.imagePath,
      detectionSource: detectionSource ?? this.detectionSource,
      rawPayload: rawPayload ?? this.rawPayload,
      counterpartyLast4: counterpartyLast4 ?? this.counterpartyLast4,
      isIncome: isIncome ?? this.isIncome,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'merchant': merchant,
        'appSource': appSource,
        'refId': refId,
        'date': date.millisecondsSinceEpoch,
        'suggestedCategoryId': suggestedCategoryId,
        'suggestedWalletId': suggestedWalletId,
        'imagePath': imagePath,
        'detectionSource': detectionSource,
        'rawPayload': rawPayload,
        'counterpartyLast4': counterpartyLast4,
        'isIncome': isIncome,
        'sourceMessageId': sourceMessageId,
      };

  factory PendingTransactionModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final dateVal = json['date'];
    if (dateVal is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(dateVal);
    } else if (dateVal is String) {
      parsedDate = DateTime.tryParse(dateVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final amtVal = json['amount'];
    double parsedAmount = 0.0;
    if (amtVal is num) {
      parsedAmount = amtVal.toDouble();
    } else if (amtVal is String) {
      parsedAmount = double.tryParse(amtVal.replaceAll(',', '').trim()) ?? 0.0;
    }

    return PendingTransactionModel(
      id: json['id'] as String? ?? UniqueKey().toString(),
      amount: parsedAmount,
      merchant: (json['merchant'] as String?)?.trim().isNotEmpty == true
          ? json['merchant'] as String
          : 'Payment',
      appSource: json['appSource'] as String? ?? 'UPI App',
      refId: json['refId'] as String?,
      date: parsedDate,
      suggestedCategoryId: json['suggestedCategoryId'] as String?,
      suggestedWalletId: json['suggestedWalletId'] as String?,
      imagePath: json['imagePath'] as String?,
      detectionSource: json['detectionSource'] as String? ?? 'notification',
      rawPayload: json['rawPayload'] as String?,
      counterpartyLast4: json['counterpartyLast4'] as String?,
      isIncome: json['isIncome'] == true,
      sourceMessageId: json['sourceMessageId'] as String?,
    );
  }
}

// Fallback UniqueKey generator without importing full material
class UniqueKey {
  @override
  String toString() =>
      'key_${DateTime.now().microsecondsSinceEpoch}_${(DateTime.now().millisecond * 31).toString()}';
}
