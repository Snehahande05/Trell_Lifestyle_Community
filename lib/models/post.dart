class Comment {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'],
    userId: json['userId'],
    userName: json['userName'],
    text: json['text'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class Post {
  final String id;
  final String creatorId;
  final String creatorName;
  final String creatorAvatarUrl;
  final bool isVerifiedCreator;
  final String videoPath; // Asset path or local file path
  final String caption;
  final String category; // Fashion, Beauty, Travel, Food, DIY
  final List<String> taggedProductIds;
  final int viewsCount;
  final List<String> likedUserIds;
  final List<Comment> comments;
  final int sharesCount;
  final int productClicksCount;
  final String? filterName; // Visual filter applied
  final String? musicTitle; // Audio added
  final double? musicVolume;
  final double? trimStartSeconds;
  final double? trimEndSeconds;
  final bool isPromoted;
  final DateTime? promotionExpiry;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.creatorAvatarUrl,
    this.isVerifiedCreator = false,
    required this.videoPath,
    required this.caption,
    required this.category,
    required this.taggedProductIds,
    this.viewsCount = 0,
    this.likedUserIds = const [],
    this.comments = const [],
    this.sharesCount = 0,
    this.productClicksCount = 0,
    this.filterName,
    this.musicTitle,
    this.musicVolume,
    this.trimStartSeconds,
    this.trimEndSeconds,
    this.isPromoted = false,
    this.promotionExpiry,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'creatorId': creatorId,
    'creatorName': creatorName,
    'creatorAvatarUrl': creatorAvatarUrl,
    'isVerifiedCreator': isVerifiedCreator,
    'videoPath': videoPath,
    'caption': caption,
    'category': category,
    'taggedProductIds': List<String>.from(taggedProductIds),
    'viewsCount': viewsCount,
    'likedUserIds': List<String>.from(likedUserIds),
    'comments': comments.map((c) => c.toJson()).toList(),
    'sharesCount': sharesCount,
    'productClicksCount': productClicksCount,
    'filterName': filterName,
    'musicTitle': musicTitle,
    'musicVolume': musicVolume,
    'trimStartSeconds': trimStartSeconds,
    'trimEndSeconds': trimEndSeconds,
    'isPromoted': isPromoted,
    'promotionExpiry': promotionExpiry?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'],
    creatorId: json['creatorId'],
    creatorName: json['creatorName'],
    creatorAvatarUrl: json['creatorAvatarUrl'],
    isVerifiedCreator: json['isVerifiedCreator'] ?? false,
    videoPath: json['videoPath'],
    caption: json['caption'],
    category: json['category'],
    taggedProductIds: List<String>.from(json['taggedProductIds'] ?? []),
    viewsCount: json['viewsCount'] ?? 0,
    likedUserIds: List<String>.from(json['likedUserIds'] ?? []),
    comments: (json['comments'] as List? ?? [])
        .map((c) => Comment.fromJson(c))
        .toList(),
    sharesCount: json['sharesCount'] ?? 0,
    productClicksCount: json['productClicksCount'] ?? 0,
    filterName: json['filterName'],
    musicTitle: json['musicTitle'],
    musicVolume: json['musicVolume'] != null
        ? (json['musicVolume'] as num).toDouble()
        : null,
    trimStartSeconds: json['trimStartSeconds'] != null
        ? (json['trimStartSeconds'] as num).toDouble()
        : null,
    trimEndSeconds: json['trimEndSeconds'] != null
        ? (json['trimEndSeconds'] as num).toDouble()
        : null,
    isPromoted: json['isPromoted'] ?? false,
    promotionExpiry: json['promotionExpiry'] != null
        ? DateTime.parse(json['promotionExpiry'])
        : null,
    createdAt: DateTime.parse(json['createdAt']),
  );

  Post copyWith({
    int? viewsCount,
    List<String>? likedUserIds,
    List<Comment>? comments,
    int? sharesCount,
    int? productClicksCount,
    bool? isPromoted,
    DateTime? promotionExpiry,
  }) {
    return Post(
      id: id,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorAvatarUrl: creatorAvatarUrl,
      isVerifiedCreator: isVerifiedCreator,
      videoPath: videoPath,
      caption: caption,
      category: category,
      taggedProductIds: List<String>.from(taggedProductIds),
      viewsCount: viewsCount ?? this.viewsCount,
      likedUserIds: likedUserIds ?? List<String>.from(this.likedUserIds),
      comments: comments ?? List.from(this.comments),
      sharesCount: sharesCount ?? this.sharesCount,
      productClicksCount: productClicksCount ?? this.productClicksCount,
      filterName: filterName,
      musicTitle: musicTitle,
      musicVolume: musicVolume,
      trimStartSeconds: trimStartSeconds,
      trimEndSeconds: trimEndSeconds,
      isPromoted: isPromoted ?? this.isPromoted,
      promotionExpiry: promotionExpiry ?? this.promotionExpiry,
      createdAt: createdAt,
    );
  }
}
