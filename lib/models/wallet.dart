enum CommissionStatus { pending, available, reserved, paidOut, reversed }

class CommissionTransaction {
  final String id;
  final String creatorId;
  final String orderId;
  final String productId;
  final int amountPaise;
  final CommissionStatus status;
  final DateTime createdAt;

  CommissionTransaction({
    required this.id,
    required this.creatorId,
    required this.orderId,
    required this.productId,
    required this.amountPaise,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorId': creatorId,
        'orderId': orderId,
        'productId': productId,
        'amountPaise': amountPaise,
        'status': status.index,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CommissionTransaction.fromJson(Map<String, dynamic> json) =>
      CommissionTransaction(
        id: json['id'],
        creatorId: json['creatorId'],
        orderId: json['orderId'],
        productId: json['productId'],
        amountPaise: json['amountPaise'],
        status: CommissionStatus.values[json['status']],
        createdAt: DateTime.parse(json['createdAt']),
      );

  CommissionTransaction copyWith({CommissionStatus? status}) =>
      CommissionTransaction(
        id: id,
        creatorId: creatorId,
        orderId: orderId,
        productId: productId,
        amountPaise: amountPaise,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

enum WithdrawalStatus { pending, approved, rejected }

class WithdrawalRequest {
  final String id;
  final String creatorId;
  final String creatorName;
  final int amountPaise;
  final String upiIdOrBank;
  final WithdrawalStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? rejectionReason;

  WithdrawalRequest({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.amountPaise,
    required this.upiIdOrBank,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'amountPaise': amountPaise,
        'upiIdOrBank': upiIdOrBank,
        'status': status.index,
        'requestedAt': requestedAt.toIso8601String(),
        'processedAt': processedAt?.toIso8601String(),
        'rejectionReason': rejectionReason,
      };

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) =>
      WithdrawalRequest(
        id: json['id'],
        creatorId: json['creatorId'],
        creatorName: json['creatorName'],
        amountPaise: json['amountPaise'],
        upiIdOrBank: json['upiIdOrBank'],
        status: WithdrawalStatus.values[json['status']],
        requestedAt: DateTime.parse(json['requestedAt']),
        processedAt: json['processedAt'] != null
            ? DateTime.parse(json['processedAt'])
            : null,
        rejectionReason: json['rejectionReason'],
      );

  WithdrawalRequest copyWith({
    WithdrawalStatus? status,
    DateTime? processedAt,
    String? rejectionReason,
  }) =>
      WithdrawalRequest(
        id: id,
        creatorId: creatorId,
        creatorName: creatorName,
        amountPaise: amountPaise,
        upiIdOrBank: upiIdOrBank,
        status: status ?? this.status,
        requestedAt: requestedAt,
        processedAt: processedAt ?? this.processedAt,
        rejectionReason: rejectionReason ?? this.rejectionReason,
      );
}

class RevenueShareRecord {
  final String id;
  final String creatorId;
  final int sourceAmountPaise;
  final double shareRate; // e.g. 0.20 for 20%, max 0.30 (30%)
  final int calculatedSharePaise;
  final String note;
  final DateTime createdAt;

  RevenueShareRecord({
    required this.id,
    required this.creatorId,
    required this.sourceAmountPaise,
    required this.shareRate,
    required this.calculatedSharePaise,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorId': creatorId,
        'sourceAmountPaise': sourceAmountPaise,
        'shareRate': shareRate,
        'calculatedSharePaise': calculatedSharePaise,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RevenueShareRecord.fromJson(Map<String, dynamic> json) =>
      RevenueShareRecord(
        id: json['id'],
        creatorId: json['creatorId'],
        sourceAmountPaise: json['sourceAmountPaise'],
        shareRate: (json['shareRate'] as num).toDouble(),
        calculatedSharePaise: json['calculatedSharePaise'],
        note: json['note'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}
