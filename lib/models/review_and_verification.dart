class ProductReview {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final double rating;
  final String comment;
  final bool isVerifiedPurchase;
  final DateTime createdAt;

  ProductReview({
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
        id: json['id'],
        productId: json['productId'],
        userId: json['userId'],
        userName: json['userName'],
        userAvatarUrl: json['userAvatarUrl'],
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'],
        isVerifiedPurchase: json['isVerifiedPurchase'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
      );
}

enum VerificationStatus { none, pending, approved, rejected }

class VerificationApplication {
  final String id;
  final String creatorId;
  final String creatorName;
  final String category;
  final String socialLink;
  final String reason;
  final VerificationStatus status;
  final DateTime submittedAt;

  VerificationApplication({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.category,
    required this.socialLink,
    required this.reason,
    required this.status,
    required this.submittedAt,
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
      };

  factory VerificationApplication.fromJson(Map<String, dynamic> json) =>
      VerificationApplication(
        id: json['id'],
        creatorId: json['creatorId'],
        creatorName: json['creatorName'],
        category: json['category'],
        socialLink: json['socialLink'],
        reason: json['reason'],
        status: VerificationStatus.values[json['status']],
        submittedAt: DateTime.parse(json['submittedAt']),
      );

  VerificationApplication copyWith({VerificationStatus? status}) =>
      VerificationApplication(
        id: id,
        creatorId: creatorId,
        creatorName: creatorName,
        category: category,
        socialLink: socialLink,
        reason: reason,
        status: status ?? this.status,
        submittedAt: submittedAt,
      );
}
