import 'package:uuid/uuid.dart';

enum DebtType { lent, borrowed }

extension DebtTypeExt on DebtType {
  String get displayName {
    switch (this) {
      case DebtType.lent:
        return 'Lent (You gave money)';
      case DebtType.borrowed:
        return 'Borrowed (You took money)';
    }
  }

  String get shortLabel {
    switch (this) {
      case DebtType.lent:
        return 'You are owed';
      case DebtType.borrowed:
        return 'You owe';
    }
  }
}

class DebtPaymentModel {
  final String id;
  final double amount;
  final DateTime date;
  final String? note;
  final String? walletId;

  const DebtPaymentModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
    this.walletId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'walletId': walletId,
      };

  factory DebtPaymentModel.fromJson(Map<String, dynamic> json) =>
      DebtPaymentModel(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        walletId: json['walletId'] as String?,
      );
}

class DebtModel {
  final String id;
  final String personName;
  final String? phoneNumber;
  final double totalAmount;
  final double remainingAmount;
  final DebtType type;
  final DateTime? dueDate;
  final String? walletId;
  final bool isSettled;
  final String? notes;
  final DateTime createdAt;
  final List<DebtPaymentModel> payments;

  const DebtModel({
    required this.id,
    required this.personName,
    this.phoneNumber,
    required this.totalAmount,
    required this.remainingAmount,
    required this.type,
    this.dueDate,
    this.walletId,
    this.isSettled = false,
    this.notes,
    required this.createdAt,
    this.payments = const [],
  });

  DebtModel copyWith({
    String? id,
    String? personName,
    String? phoneNumber,
    double? totalAmount,
    double? remainingAmount,
    DebtType? type,
    DateTime? dueDate,
    String? walletId,
    bool? isSettled,
    String? notes,
    DateTime? createdAt,
    List<DebtPaymentModel>? payments,
  }) {
    return DebtModel(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      walletId: walletId ?? this.walletId,
      isSettled: isSettled ?? this.isSettled,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      payments: payments ?? this.payments,
    );
  }

  DebtModel recordPayment({
    required double paymentAmount,
    String? note,
    String? walletId,
  }) {
    final payment = DebtPaymentModel(
      id: const Uuid().v4(),
      amount: paymentAmount,
      date: DateTime.now(),
      note: note,
      walletId: walletId,
    );

    final newRemaining = (remainingAmount - paymentAmount).clamp(0.0, totalAmount);
    return copyWith(
      remainingAmount: newRemaining,
      isSettled: newRemaining <= 0,
      payments: [payment, ...payments],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personName': personName,
        'phoneNumber': phoneNumber,
        'totalAmount': totalAmount,
        'remainingAmount': remainingAmount,
        'type': type.name,
        'dueDate': dueDate?.toIso8601String(),
        'walletId': walletId,
        'isSettled': isSettled,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'payments': payments.map((e) => e.toJson()).toList(),
      };

  factory DebtModel.fromJson(Map<String, dynamic> json) => DebtModel(
        id: json['id'] as String? ?? 'debt_${DateTime.now().microsecondsSinceEpoch}',
        personName: json['personName'] as String? ?? 'Contact',
        phoneNumber: json['phoneNumber'] as String?,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0.0,
        type: DebtType.values.asNameMap()[json['type']] ?? DebtType.lent,
        dueDate: json['dueDate'] != null
            ? DateTime.tryParse(json['dueDate'] as String)
            : null,
        walletId: json['walletId'] as String?,
        isSettled: json['isSettled'] as bool? ?? false,
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] != null
            ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
            : DateTime.now(),
        payments: (json['payments'] as List<dynamic>? ?? [])
            .map((e) => DebtPaymentModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
