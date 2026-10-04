// ============================================================
// REVIEW & VERIFICATION MODELS — Trell Lifestyle Community (Step 9)
// ============================================================
//
// VERIFIED PURCHASE BADGE RULES (enforced in repository, not UI):
//   Eligible iff the review author has at least one Order that:
//     - belongs to the same userId as the reviewer
//     - has status == OrderStatus.completed   (delivered)
//     - has NOT been fully refunded (status != OrderStatus.refunded)
//     - contains an OrderItem with productId == review.productId
//       AND that item's quantity after any partial refund >= 1
//   Failed, cancelled, and unpaid orders do NOT qualify.
//   A different user's order does NOT qualify.
//   If the only qualifying order is later refunded, badge is removed on
//   next eligibility re-evaluation (without deleting the review text).
//   Badge verifies purchase eligibility only — not truthfulness of review.
//
// REVIEW POLICY:
//   One review per (userId, productId). A second submission by the same
//   user for the same product overwrites the first (edit semantics).
//   Rating must be in [1.0, 5.0]. Comment must be non-empty after trimming.
//
// VERIFICATION STATES:
//   notApplied → pending  (creator submits application)
//   pending    → approved (admin approves)
//   pending    → rejected (admin rejects with mandatory reason)
//   rejected   → pending  (creator may reapply — no cooldown in demo;
//                          this is the documented reapplication rule)
//   approved is terminal unless admin revokes (revocation preserved if
//   already exists in the project; not added here as out-of-scope).
//
// ROLE RESTRICTIONS (demo-local only):
//   Only users with UserRole.admin may call processVerification.
//   Enforced at repository level; UI additionally hides controls.
//   Self-approval is prevented by checking adminId != creatorId in repo.
//
// ============================================================

enum VerificationStatus { notApplied, pending, approved, rejected }

class ProductReview {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String userAvatarUrl;

  /// Rating in [1.0, 5.0]. Validated at submission time.
  final double rating;

  /// Non-empty review text. Validated at submission time.
  final String comment;

  /// Derived at write-time from order records; re-evaluated on order changes.
  /// True only when the reviewer has a completed, non-refunded order containing
  /// this product. NOT set by UI checkbox — repository-enforced only.
  final bool isVerifiedPurchase;

  final DateTime createdAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.rating,
    required this.comment,
    this.isVerifiedPurchase = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'userId': userId,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'rating': rating,
        'comment': comment,
        'isVerifiedPurchase': isVerifiedPurchase,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
        id: json['id'] as String,
        productId: json['productId'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String,
        userAvatarUrl: json['userAvatarUrl'] as String,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String,
        isVerifiedPurchase: json['isVerifiedPurchase'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  ProductReview copyWith({bool? isVerifiedPurchase}) => ProductReview(
        id: id,
        productId: productId,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        rating: rating,
        comment: comment,
        isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
        createdAt: createdAt,
      );
}

class VerificationApplication {
  final String id;
  final String creatorId;
  final String creatorName;

  /// Validation: must be non-empty after trimming.
  final String category;

  /// Validation: must be non-empty after trimming.
  final String socialLink;

  /// Validation: must be non-empty after trimming.
  final String reason;

  final VerificationStatus status;
  final DateTime submittedAt;

  // ── Decision fields (null until admin acts) ──────────────────────────────
  /// ID of the admin user who made the decision.
  final String? decidedByAdminId;

  /// UTC timestamp of the admin decision.
  final DateTime? decidedAt;

  /// Mandatory rejection reason (non-null when status == rejected).
  final String? rejectionReason;

  const VerificationApplication({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.category,
    required this.socialLink,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.decidedByAdminId,
    this.decidedAt,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorId': creatorId,
        'creatorName': creatorName,
        'category': category,
        'socialLink': socialLink,
        'reason': reason,
        'status': status.index,
        'submittedAt': submittedAt.toIso8601String(),
        'decidedByAdminId': decidedByAdminId,
        'decidedAt': decidedAt?.toIso8601String(),
        'rejectionReason': rejectionReason,
      };

  factory VerificationApplication.fromJson(Map<String, dynamic> json) =>
      VerificationApplication(
        id: json['id'] as String,
        creatorId: json['creatorId'] as String,
        creatorName: json['creatorName'] as String,
        category: json['category'] as String,
        socialLink: json['socialLink'] as String,
        reason: json['reason'] as String,
        // Backward compat: old records used 0=none(now notApplied),1=pending,
        // 2=approved,3=rejected. The new enum inserts notApplied at index 0;
        // existing stored indices remain valid because the previous enum started
        // at 0=none which maps cleanly to 0=notApplied.
        status: VerificationStatus.values[json['status'] as int],
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        decidedByAdminId: json['decidedByAdminId'] as String?,
        decidedAt: json['decidedAt'] != null
            ? DateTime.parse(json['decidedAt'] as String)
            : null,
        rejectionReason: json['rejectionReason'] as String?,
      );

  VerificationApplication copyWith({
    VerificationStatus? status,
    String? decidedByAdminId,
    DateTime? decidedAt,
    String? rejectionReason,
  }) =>
      VerificationApplication(
        id: id,
        creatorId: creatorId,
        creatorName: creatorName,
        category: category,
        socialLink: socialLink,
        reason: reason,
        status: status ?? this.status,
        submittedAt: submittedAt,
        decidedByAdminId: decidedByAdminId ?? this.decidedByAdminId,
        decidedAt: decidedAt ?? this.decidedAt,
        rejectionReason: rejectionReason ?? this.rejectionReason,
      );
}
