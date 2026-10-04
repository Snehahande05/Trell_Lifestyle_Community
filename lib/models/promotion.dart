// ============================================================
// PROMOTION MODEL — Trell Lifestyle Community (Step 10)
// ============================================================
//
// PACKAGE TERMS (documented per brief §6):
//   Price  : ₹499 (49,900 paise) — stored in precise minor units
//   Duration: 7 days featured placement
//   Label  : "Demo promotion payment — no real money is charged"
//
// ACTIVE PROMOTION RULE (single source of truth):
//   A promotion is ACTIVE iff:
//     status == PaymentStatus.success
//     AND activationTime != null
//     AND activationTime <= now
//     AND expiryTime > now
//
//   Use [PromotionRecord.isCurrentlyActive] everywhere: sorting,
//   badges, history, and eligibility checks.
//
// IDEMPOTENCY:
//   paymentAttemptId is a stable caller-supplied identifier.
//   Repeated calls with the same id return the existing record.
//
// STATE MACHINE:
//   pending  → success    (simulated payment succeeds)
//   pending  → failed     (simulated payment fails)
//   pending  → cancelled  (user cancels dialog)
//   No further transitions from terminal states.
//   Expired is derived, not a stored status.
// ============================================================

enum PromotionPaymentStatus { pending, success, failed, cancelled }

class PromotionRecord {
  /// Unique promotion record ID.
  final String id;

  /// Caller-supplied stable idempotency key for the payment attempt.
  final String paymentAttemptId;

  final String postId;
  final String creatorId;

  /// Package price in paise (49,900 = ₹499).
  final int packagePricePaise;

  /// Promotion duration in days (7).
  final int durationDays;

  final PromotionPaymentStatus paymentStatus;

  /// Set on successful activation (UTC).
  final DateTime? activationTime;

  /// Set on successful activation: activationTime + durationDays (UTC).
  final DateTime? expiryTime;

  /// Reason for failure/cancellation (optional, for history display).
  final String? failureReason;

  final DateTime createdAt;

  const PromotionRecord({
    required this.id,
    required this.paymentAttemptId,
    required this.postId,
    required this.creatorId,
    required this.packagePricePaise,
    required this.durationDays,
    required this.paymentStatus,
    this.activationTime,
    this.expiryTime,
    this.failureReason,
    required this.createdAt,
  });

  // ── Centralized active-promotion rule ──────────────────────────────────────
  /// Returns true only when this promotion is currently active.
  /// Uses [now] so callers (tests, timer callbacks) can inject a controllable
  /// clock without touching the advertised package duration.
  bool isActive({DateTime? now}) {
    final t = now ?? DateTime.now().toUtc();
    return paymentStatus == PromotionPaymentStatus.success &&
        activationTime != null &&
        expiryTime != null &&
        !activationTime!.isAfter(t) &&
        expiryTime!.isAfter(t);
  }

  /// True when payment succeeded but the window has now elapsed.
  bool isExpired({DateTime? now}) {
    final t = now ?? DateTime.now().toUtc();
    return paymentStatus == PromotionPaymentStatus.success &&
        expiryTime != null &&
        !expiryTime!.isAfter(t);
  }

  // ── Serialization ──────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'paymentAttemptId': paymentAttemptId,
        'postId': postId,
        'creatorId': creatorId,
        'packagePricePaise': packagePricePaise,
        'durationDays': durationDays,
        'paymentStatus': paymentStatus.index,
        'activationTime': activationTime?.toUtc().toIso8601String(),
        'expiryTime': expiryTime?.toUtc().toIso8601String(),
        'failureReason': failureReason,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory PromotionRecord.fromJson(Map<String, dynamic> json) => PromotionRecord(
        id: json['id'] as String,
        paymentAttemptId: json['paymentAttemptId'] as String,
        postId: json['postId'] as String,
        creatorId: json['creatorId'] as String,
        packagePricePaise: json['packagePricePaise'] as int,
        durationDays: json['durationDays'] as int,
        paymentStatus:
            PromotionPaymentStatus.values[json['paymentStatus'] as int],
        activationTime: json['activationTime'] != null
            ? DateTime.parse(json['activationTime'] as String).toUtc()
            : null,
        expiryTime: json['expiryTime'] != null
            ? DateTime.parse(json['expiryTime'] as String).toUtc()
            : null,
        failureReason: json['failureReason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      );

  PromotionRecord copyWith({
    PromotionPaymentStatus? paymentStatus,
    DateTime? activationTime,
    DateTime? expiryTime,
    String? failureReason,
  }) =>
      PromotionRecord(
        id: id,
        paymentAttemptId: paymentAttemptId,
        postId: postId,
        creatorId: creatorId,
        packagePricePaise: packagePricePaise,
        durationDays: durationDays,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        activationTime: activationTime ?? this.activationTime,
        expiryTime: expiryTime ?? this.expiryTime,
        failureReason: failureReason ?? this.failureReason,
        createdAt: createdAt,
      );
}
