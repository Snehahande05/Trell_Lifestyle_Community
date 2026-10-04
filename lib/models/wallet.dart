// ============================================================
// LEDGER MODEL — Trell Lifestyle Community (Step 7)
// ============================================================
//
// ROUNDING RULE: All paise amounts use Dart's built-in .round()
//   (rounds half-to-even / "banker's rounding"). Applied once
//   at commission creation using: (totalPaise * commissionRate).round()
//
// COMMISSION LIFECYCLE:
//   pending   — created when a paid order with attribution is confirmed.
//               Not withdrawable yet. Reversed if order is cancelled.
//   available — moved here when admin marks order as "completed".
//               Can be requested for withdrawal.
//   reserved  — moved here when a withdrawal is requested (= reservation).
//               Prevents double-spending without committing payout.
//   paidOut   — moved here when admin approves a withdrawal request.
//               The actual split record stores only the withdrawn portion.
//   reversed  — commission reversed by refund/cancellation.
//               Cannot be counted as earnings.
//   clawback  — created when a commission is refunded AFTER payout.
//               Represents a debt to the platform, recovered from future
//               earnings before any new withdrawal can proceed.
//
// RECONCILIATION EQUATION:
//   gross_commission - reversals
//   = pending + available + reserved + net_cash_paid - recovery_due
//
//   Where:
//     gross_commission = sum of ALL commission amounts ever created
//     reversals = sum of all reversed commission amounts
//     net_cash_paid = sum of paidOut amounts minus clawback recovered
//     recovery_due = sum of outstanding clawback (unrecovered)
//     pending/available/reserved = sums of those status amounts
//
// SETTLEMENT RULE:
//   Commission becomes "available" exactly when the corresponding Order
//   transitions to OrderStatus.completed. Only the admin can mark this.
//
// WITHDRAWAL MINIMUM: ₹100 (10,000 paise). Enforced in both UI and repo.
// ============================================================

enum CommissionStatus {
  pending, // Created on paid order; not yet withdrawable
  available, // Order completed; ready for withdrawal
  reserved, // Withdrawal request pending admin approval
  paidOut, // Withdrawal approved and paid out (demo)
  reversed, // Refunded or cancelled; no longer an entitlement
  clawback, // Refunded AFTER payout; debt owed to platform
}

class CommissionTransaction {
  final String id;
  final String creatorId;
  final String orderId;
  final String productId;
  final int amountPaise;
  final CommissionStatus status;
  final DateTime createdAt;

  /// Optional: ID of the withdrawal request that consumed this commission
  final String? withdrawalId;

  CommissionTransaction({
    required this.id,
    required this.creatorId,
    required this.orderId,
    required this.productId,
    required this.amountPaise,
    required this.status,
    required this.createdAt,
    this.withdrawalId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'creatorId': creatorId,
    'orderId': orderId,
    'productId': productId,
    'amountPaise': amountPaise,
    'status': status.index,
    'createdAt': createdAt.toIso8601String(),
    'withdrawalId': withdrawalId,
  };

  factory CommissionTransaction.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?) ?? 'legacy_commission';

    final amount =
        (json['amountPaise'] as num?)?.toInt() ??
        (json['commissionPaise'] as num?)?.toInt() ??
        0;

    final statusIndex = (json['status'] as num?)?.toInt();

    final status =
        statusIndex != null &&
            statusIndex >= 0 &&
            statusIndex < CommissionStatus.values.length
        ? CommissionStatus.values[statusIndex]
        : CommissionStatus.values.first;

    final createdAtRaw = json['createdAt'] as String?;

    return CommissionTransaction(
      id: id,
      creatorId: (json['creatorId'] as String?) ?? 'legacy_creator',
      orderId: (json['orderId'] as String?) ?? 'legacy_order_$id',
      productId: (json['productId'] as String?) ?? 'legacy_product_$id',
      amountPaise: amount,
      status: status,
      createdAt: createdAtRaw != null
          ? DateTime.parse(createdAtRaw)
          : DateTime.fromMillisecondsSinceEpoch(0),
      withdrawalId: json['withdrawalId'] as String?,
    );
  }

  CommissionTransaction copyWith({
    CommissionStatus? status,
    int? amountPaise,
    String? withdrawalId,
  }) => CommissionTransaction(
    id: id,
    creatorId: creatorId,
    orderId: orderId,
    productId: productId,
    amountPaise: amountPaise ?? this.amountPaise,
    status: status ?? this.status,
    createdAt: createdAt,
    withdrawalId: withdrawalId ?? this.withdrawalId,
  );
}

// Transition table for WithdrawalStatus (enforced in repository):
//   pending  → approved   (admin approves payout)
//   pending  → rejected   (admin rejects request)
//   No further transitions allowed (terminal states: approved, rejected)
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
        status: WithdrawalStatus.values[json['status'] as int],
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
  }) => WithdrawalRequest(
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
