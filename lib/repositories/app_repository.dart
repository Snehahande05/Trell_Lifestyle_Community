import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../models/product.dart';
import '../models/post.dart';
import '../models/order.dart';
import '../models/wallet.dart';
import '../models/review_and_verification.dart';
import '../models/promotion.dart';

abstract class AppRepositoryInterface {
  Future<void> init();
  Future<void> resetDemoData();

  // Users
  List<User> getUsers();
  User? getUserById(String id);
  Future<void> updateUser(User user);
  Future<void> toggleFollowUser(String currentUserId, String targetUserId);
  bool isFollowing(String currentUserId, String targetUserId);

  // Products
  List<Product> getProducts();
  Product? getProductById(String id);
  Future<void> addProduct(Product product);

  // Posts
  List<Post> getPosts();
  Post? getPostById(String id);
  Future<void> addPost(Post post);
  Future<void> updatePost(Post post);
  Future<bool> incrementPostViews(String postId, String viewerUserId);
  Future<void> togglePostLike(String postId, String userId);
  Future<void> addPostComment(
    String postId,
    String userId,
    String userName,
    String text,
  );
  Future<void> incrementPostShares(String postId);
  Future<void> recordProductClick(
    String postId,
    String productId,
    String userId,
  );
  Future<void> promotePost(String postId, int durationDays);

  // Cart & Orders
  List<CartItem> getCart(String userId);
  Future<void> addToCart(
    String userId,
    Product product,
    String? creatorId,
    String? postId,
  );
  Future<void> updateCartQuantity(
    String userId,
    String productId,
    String? creatorId,
    String? postId,
    int quantity,
  );
  Future<void> removeFromCart(
    String userId,
    String productId,
    String? creatorId,
    String? postId,
  );
  Future<void> clearCart(String userId);

  List<Order> getOrders();
  List<Order> getOrdersForUser(String userId);
  Future<Order> createOrder({
    required String buyerUserId,
    required String buyerName,
    required List<CartItem> items,
    required String shippingAddress,
    required bool simulateSuccess,
    String? idempotencyKey,
  });
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus);

  // Wallet & Commissions
  List<CommissionTransaction> getCommissionsForCreator(String creatorId);
  List<WithdrawalRequest> getWithdrawalRequests();
  List<WithdrawalRequest> getWithdrawalRequestsForCreator(String creatorId);
  Future<WithdrawalRequest?> requestWithdrawal(
    String creatorId,
    String creatorName,
    int amountPaise,
    String upiIdOrBank,
  );
  Future<void> processWithdrawal(
    String requestId,
    bool approve, {
    String? reason,
  });

  // Revenue Share
  List<RevenueShareRecord> getRevenueShareRecordsForCreator(String creatorId);
  Future<void> recordRevenueShare(
    String creatorId,
    int sourcePaise,
    double shareRate,
    String note,
  );

  // Reviews & Verification
  List<ProductReview> getReviewsForProduct(String productId);

  /// Returns true iff [userId] has at least one COMPLETED (delivered),
  /// non-refunded order containing [productId]. See badge eligibility rules.
  bool hasUserPurchasedProduct(String userId, String productId);
  Future<void> addProductReview(
    String productId,
    String userId,
    String userName,
    String avatarUrl,
    double rating,
    String comment,
  );

  /// Re-evaluates all existing reviews for [productId] and updates their
  /// isVerifiedPurchase flag without deleting review text.
  Future<void> reEvaluateReviewBadges(String productId);

  List<VerificationApplication> getVerificationApplications();
  VerificationApplication? getVerificationForCreator(String creatorId);
  Future<void> submitVerification(
    String creatorId,
    String creatorName,
    String category,
    String socialLink,
    String reason,
  );

  /// [adminId] must be a user with UserRole.admin. [rejectionReason] is
  /// required when approve == false. Self-approval (adminId == creatorId)
  /// is rejected. Stale/repeated decisions are ignored idempotently.
  Future<void> processVerification(
    String applicationId,
    bool approve, {
    required String adminId,
    String? rejectionReason,
  });

  // Promotions (Step 10)
  List<PromotionRecord> getPromotionsForCreator(String creatorId);
  List<PromotionRecord> getAllPromotions();

  /// Creates or resolves an idempotent promotion payment attempt.
  /// [paymentAttemptId] is a stable caller-supplied key.
  /// Returns the existing record if the attempt was already processed.
  Future<PromotionRecord> createPromotionAttempt({
    required String paymentAttemptId,
    required String postId,
    required String creatorId,
    required bool simulateSuccess,
    String? failureReason,
  });
}

class LocalDemoRepository implements AppRepositoryInterface {
  static const String _kKeyUsers = 'trell_users';
  static const String _kKeyProducts = 'trell_products';
  static const String _kKeyPosts = 'trell_posts';
  static const String _kKeyCartPrefix = 'trell_cart_';
  static const String _kKeyOrders = 'trell_orders';
  static const String _kKeyCommissions = 'trell_commissions';
  static const String _kKeyWithdrawals = 'trell_withdrawals';
  static const String _kKeyRevShares = 'trell_rev_shares';
  static const String _kKeyReviews = 'trell_reviews';
  static const String _kKeyVerifications = 'trell_verifications';
  static const String _kKeyPromotions = 'trell_promotions';
  static const String _kKeyFollowsPrefix = 'trell_follows_';
  static const String _kKeyViewedPostsPrefix = 'trell_viewed_';

  late SharedPreferences _prefs;

  List<User> _users = [
    User(
      id: 'u_viewer',
      name: 'Aanya Sharma (Viewer)',
      username: 'aanya_shopper',
      avatarUrl: 'assets/images/viewer_aanya.png',
      role: UserRole.viewer,
      bio: 'Lifestyle enthusiast & avid shopper!',
    ),
    User(
      id: 'u_creator1',
      name: 'Priya Fashionista',
      username: 'priya_style',
      avatarUrl: 'assets/images/creator_priya.png',
      role: UserRole.creator,
      isVerifiedCreator: true,
      bio: 'Fashion creator based in Mumbai ✨',
      followerCount: 1420,
    ),
    User(
      id: 'u_creator2',
      name: 'Rahul Style',
      username: 'rahul_fashion',
      avatarUrl: 'assets/images/creator_rohan.png',
      role: UserRole.creator,
      isVerifiedCreator: false,
      bio: 'Men\'s fashion & streetwear.',
      followerCount: 890,
    ),
    User(
      id: 'u_creator3',
      name: 'Simran Glow',
      username: 'simran_beauty',
      avatarUrl: 'assets/images/creator_priya.png',
      role: UserRole.creator,
      isVerifiedCreator: true,
      bio: 'Beauty & Skincare routines 💄',
      followerCount: 3400,
    ),
    User(
      id: 'u_creator4',
      name: 'Kavya Looks',
      username: 'kavya_makeup',
      avatarUrl: 'assets/images/creator_priya.png',
      role: UserRole.creator,
      isVerifiedCreator: false,
      bio: 'Makeup tutorials and product reviews.',
      followerCount: 1200,
    ),
    User(
      id: 'u_creator5',
      name: 'Rohan Traveler',
      username: 'rohan_explores',
      avatarUrl: 'assets/images/creator_rohan.png',
      role: UserRole.creator,
      isVerifiedCreator: true,
      bio: 'Exploring hidden spots & tech gear 🎒',
      followerCount: 8900,
    ),
    User(
      id: 'u_creator6',
      name: 'Aryan Nomad',
      username: 'aryan_travels',
      avatarUrl: 'assets/images/creator_rohan.png',
      role: UserRole.creator,
      isVerifiedCreator: false,
      bio: 'Backpacking across the globe 🌍',
      followerCount: 2300,
    ),
    User(
      id: 'u_creator7',
      name: 'Megha Bites',
      username: 'megha_foodie',
      avatarUrl: 'assets/images/creator_priya.png',
      role: UserRole.creator,
      isVerifiedCreator: true,
      bio: 'Street food lover & recipe creator 🥘',
      followerCount: 4500,
    ),
    User(
      id: 'u_creator8',
      name: 'Chef Karan',
      username: 'karan_cooks',
      avatarUrl: 'assets/images/creator_rohan.png',
      role: UserRole.creator,
      isVerifiedCreator: false,
      bio: 'Home cooking made easy 👨‍🍳',
      followerCount: 1500,
    ),
    User(
      id: 'u_creator9',
      name: 'Diya Crafts',
      username: 'diya_diy',
      avatarUrl: 'assets/images/creator_priya.png',
      role: UserRole.creator,
      isVerifiedCreator: true,
      bio: 'DIY crafts and home decor 🧶',
      followerCount: 2800,
    ),
    User(
      id: 'u_creator10',
      name: 'Lifestyle With Sam',
      username: 'sam_lifestyle',
      avatarUrl: 'assets/images/creator_rohan.png',
      role: UserRole.creator,
      isVerifiedCreator: true,
      bio: 'Fashion, food, and everything in between ✨',
      followerCount: 5600,
    ),
    User(
      id: 'u_admin',
      name: 'Trell Admin',
      username: 'admin_portal',
      avatarUrl: 'assets/images/creator_rohan.png',
      role: UserRole.admin,
      bio: 'Platform Moderator & Administrator',
    ),
  ];
  List<Product> _products = [];
  List<Post> _posts = [
    Post(
      id: 'post_fashion_1',
      creatorId: 'u_creator2',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/fashion/fashion_01.mp4',
      caption: 'Awesome fashion content #1! Check this out. #Fashion',
      category: 'Fashion',
      taggedProductIds: ['p_2'],
      viewsCount: 854,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 22,
      productClicksCount: 18,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Post(
      id: 'post_fashion_2',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/fashion/fashion_02.mp4',
      caption: 'Awesome fashion content #2! Check this out. #Fashion',
      category: 'Fashion',
      taggedProductIds: ['p_2'],
      viewsCount: 1049,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 34,
      productClicksCount: 33,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Post(
      id: 'post_fashion_3',
      creatorId: 'u_creator1',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/fashion/fashion_03.mp4',
      caption: 'Awesome fashion content #3! Check this out. #Fashion',
      category: 'Fashion',
      taggedProductIds: ['p_2'],
      viewsCount: 1544,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 48,
      productClicksCount: 15,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Post(
      id: 'post_fashion_4',
      creatorId: 'u_creator2',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/fashion/fashion_04.mp4',
      caption: 'Awesome fashion content #4! Check this out. #Fashion',
      category: 'Fashion',
      taggedProductIds: ['p_2'],
      viewsCount: 1650,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 9,
      productClicksCount: 24,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Post(
      id: 'post_fashion_5',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/fashion/fashion_05.mp4',
      caption: 'Awesome fashion content #5! Check this out. #Fashion',
      category: 'Fashion',
      taggedProductIds: ['p_2'],
      viewsCount: 945,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 47,
      productClicksCount: 26,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Post(
      id: 'post_beauty_1',
      creatorId: 'u_creator4',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/beauty/beauty_01.mp4',
      caption: 'Awesome beauty content #1! Check this out. #Beauty',
      category: 'Beauty',
      taggedProductIds: ['p_1'],
      viewsCount: 1126,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 13,
      productClicksCount: 16,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Post(
      id: 'post_beauty_2',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/beauty/beauty_02.mp4',
      caption: 'Awesome beauty content #2! Check this out. #Beauty',
      category: 'Beauty',
      taggedProductIds: ['p_1'],
      viewsCount: 510,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 23,
      productClicksCount: 10,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Post(
      id: 'post_beauty_3',
      creatorId: 'u_creator3',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/beauty/beauty_03.mp4',
      caption: 'Awesome beauty content #3! Check this out. #Beauty',
      category: 'Beauty',
      taggedProductIds: ['p_1'],
      viewsCount: 1865,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 50,
      productClicksCount: 94,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Post(
      id: 'post_beauty_4',
      creatorId: 'u_creator4',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/beauty/beauty_04.mp4',
      caption: 'Awesome beauty content #4! Check this out. #Beauty',
      category: 'Beauty',
      taggedProductIds: ['p_1'],
      viewsCount: 1504,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 49,
      productClicksCount: 63,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Post(
      id: 'post_beauty_5',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/beauty/beauty_05.mp4',
      caption: 'Awesome beauty content #5! Check this out. #Beauty',
      category: 'Beauty',
      taggedProductIds: ['p_1'],
      viewsCount: 584,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 50,
      productClicksCount: 36,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Post(
      id: 'post_travel_1',
      creatorId: 'u_creator6',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/travel/travel_01.mp4',
      caption: 'Awesome travel content #1! Check this out. #Travel',
      category: 'Travel',
      taggedProductIds: ['p_3'],
      viewsCount: 1853,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 12,
      productClicksCount: 29,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Post(
      id: 'post_travel_2',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/travel/travel_02.mp4',
      caption: 'Awesome travel content #2! Check this out. #Travel',
      category: 'Travel',
      taggedProductIds: ['p_3'],
      viewsCount: 267,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 8,
      productClicksCount: 65,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Post(
      id: 'post_travel_3',
      creatorId: 'u_creator5',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/travel/travel_03.mp4',
      caption: 'Awesome travel content #3! Check this out. #Travel',
      category: 'Travel',
      taggedProductIds: ['p_3'],
      viewsCount: 1245,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 34,
      productClicksCount: 82,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Post(
      id: 'post_travel_4',
      creatorId: 'u_creator6',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/travel/travel_04.mp4',
      caption: 'Awesome travel content #4! Check this out. #Travel',
      category: 'Travel',
      taggedProductIds: ['p_3'],
      viewsCount: 207,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 25,
      productClicksCount: 100,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Post(
      id: 'post_travel_5',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/travel/travel_05.mp4',
      caption: 'Awesome travel content #5! Check this out. #Travel',
      category: 'Travel',
      taggedProductIds: ['p_3'],
      viewsCount: 1409,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 31,
      productClicksCount: 95,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Post(
      id: 'post_food_1',
      creatorId: 'u_creator8',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/food/food_01.mp4',
      caption: 'Awesome food content #1! Check this out. #Food',
      category: 'Food',
      taggedProductIds: ['p_4'],
      viewsCount: 1228,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 32,
      productClicksCount: 56,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Post(
      id: 'post_food_2',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/food/food_02.mp4',
      caption: 'Awesome food content #2! Check this out. #Food',
      category: 'Food',
      taggedProductIds: ['p_4'],
      viewsCount: 540,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 19,
      productClicksCount: 47,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Post(
      id: 'post_food_3',
      creatorId: 'u_creator7',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/food/food_03.mp4',
      caption: 'Awesome food content #3! Check this out. #Food',
      category: 'Food',
      taggedProductIds: ['p_4'],
      viewsCount: 779,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 20,
      productClicksCount: 74,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Post(
      id: 'post_food_4',
      creatorId: 'u_creator8',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/food/food_04.mp4',
      caption: 'Awesome food content #4! Check this out. #Food',
      category: 'Food',
      taggedProductIds: ['p_4'],
      viewsCount: 600,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 48,
      productClicksCount: 70,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Post(
      id: 'post_food_5',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/food/food_05.mp4',
      caption: 'Awesome food content #5! Check this out. #Food',
      category: 'Food',
      taggedProductIds: ['p_4'],
      viewsCount: 318,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 25,
      productClicksCount: 81,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    Post(
      id: 'post_diy_1',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/diy/diy_01.mp4',
      caption: 'Awesome diy content #1! Check this out. #DIY',
      category: 'DIY',
      taggedProductIds: ['p_5'],
      viewsCount: 777,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 6,
      productClicksCount: 94,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Post(
      id: 'post_diy_2',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/diy/diy_02.mp4',
      caption: 'Awesome diy content #2! Check this out. #DIY',
      category: 'DIY',
      taggedProductIds: ['p_5'],
      viewsCount: 1641,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 9,
      productClicksCount: 75,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Post(
      id: 'post_diy_3',
      creatorId: 'u_creator9',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/diy/diy_03.mp4',
      caption: 'Awesome diy content #3! Check this out. #DIY',
      category: 'DIY',
      taggedProductIds: ['p_5'],
      viewsCount: 1066,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 8,
      productClicksCount: 13,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Post(
      id: 'post_diy_4',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/diy/diy_04.mp4',
      caption: 'Awesome diy content #4! Check this out. #DIY',
      category: 'DIY',
      taggedProductIds: ['p_5'],
      viewsCount: 1431,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 34,
      productClicksCount: 96,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    Post(
      id: 'post_diy_5',
      creatorId: 'u_creator10',
      creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
      creatorAvatarUrl: 'assets/images/creator_rohan.png',
      isVerifiedCreator: true,
      videoPath: 'assets/videos/categories/diy/diy_05.mp4',
      caption: 'Awesome diy content #5! Check this out. #DIY',
      category: 'DIY',
      taggedProductIds: ['p_5'],
      viewsCount: 405,
      likedUserIds: ['u_viewer'],
      comments: [],
      sharesCount: 46,
      productClicksCount: 74,
      filterName: 'Normal',
      musicTitle: 'Lo-Fi Chill Beats',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];
  List<Order> _orders = [];
  List<CommissionTransaction> _commissions = [];
  List<WithdrawalRequest> _withdrawals = [];
  List<RevenueShareRecord> _revShares = [];
  List<ProductReview> _reviews = [];
  List<VerificationApplication> _verifications = [];
  List<PromotionRecord> _promotions = [];

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs.containsKey(_kKeyUsers)) {
      await _seedInitialDemoData();
    } else {
      await _loadFromStorage();
    }
  }

  @override
  Future<void> resetDemoData() async {
    await _prefs.clear();
    await _seedInitialDemoData();
  }

  Future<void> _loadFromStorage() async {
    _users = _decodeList(_kKeyUsers).map((x) => User.fromJson(x)).toList();
    _products = _decodeList(_kKeyProducts)
        .map((x) => Product.fromJson(x))
        .toList();
    _posts = _decodeList(_kKeyPosts).map((x) => Post.fromJson(x)).toList();
    _orders = _decodeList(_kKeyOrders).map((x) => Order.fromJson(x)).toList();
    _commissions = _decodeList(_kKeyCommissions)
        .map((x) => CommissionTransaction.fromJson(x))
        .toList();
    _withdrawals = _decodeList(_kKeyWithdrawals)
        .map((x) => WithdrawalRequest.fromJson(x))
        .toList();
    _revShares = _decodeList(_kKeyRevShares)
        .map((x) => RevenueShareRecord.fromJson(x))
        .toList();
    _reviews = _decodeList(_kKeyReviews)
        .map((x) => ProductReview.fromJson(x))
        .toList();
    _verifications = _decodeList(_kKeyVerifications)
        .map((x) => VerificationApplication.fromJson(x))
        .toList();
    // Backward compat: promotions key may not exist in old saves — default to []
    _promotions = _decodeList(_kKeyPromotions)
        .map((x) => PromotionRecord.fromJson(x))
        .toList();
  }

  List<dynamic> _decodeList(String key) {
    String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    return jsonDecode(raw);
  }

  Future<void> _saveList(String key, List<dynamic> items) async {
    String encoded = jsonEncode(items);
    await _prefs.setString(key, encoded);
  }

  Future<void> _seedInitialDemoData() async {
    // 1. Seed Users
    _users = [
      User(
        id: 'u_viewer',
        name: 'Aanya Sharma (Viewer)',
        username: 'aanya_shopper',
        avatarUrl: 'assets/images/viewer_aanya.png',
        role: UserRole.viewer,
        bio: 'Lifestyle enthusiast & avid shopper!',
      ),
      User(
        id: 'u_creator1',
        name: 'Priya Fashionista',
        username: 'priya_style',
        avatarUrl: 'assets/images/creators/creator_01.png',
        role: UserRole.creator,
        isVerifiedCreator: true,
        bio: 'Fashion creator based in Mumbai ✨',
        followerCount: 1420,
      ),
      User(
        id: 'u_creator2',
        name: 'Rahul Style',
        username: 'rahul_fashion',
        avatarUrl: 'assets/images/creators/creator_02.png',
        role: UserRole.creator,
        isVerifiedCreator: false,
        bio: 'Men\'s fashion & streetwear.',
        followerCount: 890,
      ),
      User(
        id: 'u_creator3',
        name: 'Simran Glow',
        username: 'simran_beauty',
        avatarUrl: 'assets/images/creators/creator_03.png',
        role: UserRole.creator,
        isVerifiedCreator: true,
        bio: 'Beauty & Skincare routines 💄',
        followerCount: 3400,
      ),
      User(
        id: 'u_creator4',
        name: 'Kavya Looks',
        username: 'kavya_makeup',
        avatarUrl: 'assets/images/creators/creator_04.png',
        role: UserRole.creator,
        isVerifiedCreator: false,
        bio: 'Makeup tutorials and product reviews.',
        followerCount: 1200,
      ),
      User(
        id: 'u_creator5',
        name: 'Rohan Traveler',
        username: 'rohan_explores',
        avatarUrl: 'assets/images/creators/creator_05.png',
        role: UserRole.creator,
        isVerifiedCreator: true,
        bio: 'Exploring hidden spots & tech gear 🎒',
        followerCount: 8900,
      ),
      User(
        id: 'u_creator6',
        name: 'Aryan Nomad',
        username: 'aryan_travels',
        avatarUrl: 'assets/images/creators/creator_06.png',
        role: UserRole.creator,
        isVerifiedCreator: false,
        bio: 'Backpacking across the globe 🌍',
        followerCount: 2300,
      ),
      User(
        id: 'u_creator7',
        name: 'Megha Bites',
        username: 'megha_foodie',
        avatarUrl: 'assets/images/creators/creator_07.png',
        role: UserRole.creator,
        isVerifiedCreator: true,
        bio: 'Street food lover & recipe creator 🥘',
        followerCount: 4500,
      ),
      User(
        id: 'u_creator8',
        name: 'Chef Karan',
        username: 'karan_cooks',
        avatarUrl: 'assets/images/creators/creator_08.png',
        role: UserRole.creator,
        isVerifiedCreator: false,
        bio: 'Home cooking made easy 👨‍🍳',
        followerCount: 1500,
      ),
      User(
        id: 'u_creator9',
        name: 'Diya Crafts',
        username: 'diya_diy',
        avatarUrl: 'assets/images/creators/creator_09.png',
        role: UserRole.creator,
        isVerifiedCreator: true,
        bio: 'DIY crafts and home decor 🧶',
        followerCount: 2800,
      ),
      User(
        id: 'u_creator10',
        name: 'Lifestyle With Sam',
        username: 'sam_lifestyle',
        avatarUrl: 'assets/images/creators/creator_10.png',
        role: UserRole.creator,
        isVerifiedCreator: true,
        bio: 'Fashion, food, and everything in between ✨',
        followerCount: 5600,
      ),
      User(
        id: 'u_admin',
        name: 'Trell Admin',
        username: 'admin_portal',
        avatarUrl: 'assets/images/creator_rohan.png',
        role: UserRole.admin,
        bio: 'Platform Moderator & Administrator',
      ),
    ];

    // 2. Seed Products (prices in paise, commission rates 5-15%)
    _products = [
      Product(
        id: 'p_1',
        name: 'Velvet Matte Lipstick - Ruby Red',
        imageUrl: 'assets/images/product_lipstick.png',
        description: 'Long-lasting matte finish with hydrating jojoba oil. Vibrant color for evening looks.',
        category: 'Beauty',
        pricePaise: 79900, // ₹799
        commissionRate: 0.12, // 12%
      ),
      Product(
        id: 'p_2',
        name: 'Oversized Pastel Denim Jacket',
        imageUrl: 'assets/images/product_jacket.png',
        description: 'Trendy streetwear pastel blue oversized denim jacket. Premium cotton blend.',
        category: 'Fashion',
        pricePaise: 249900, // ₹2,499
        commissionRate: 0.10, // 10%
      ),
      Product(
        id: 'p_3',
        name: 'Waterproof Travel Duffle Bag 45L',
        imageUrl: 'assets/images/product_duffle.png',
        description: 'Durable nylon duffle bag with shoe compartment & USB port for weekender trips.',
        category: 'Travel',
        pricePaise: 189900, // ₹1,899
        commissionRate: 0.15, // 15%
      ),
      Product(
        id: 'p_4',
        name: 'Organic Matcha Green Tea Powder',
        imageUrl: 'assets/images/categories/food/Food_01.png',
        description: '100% Ceremonial grade Japanese matcha green tea. Rich in antioxidants.',
        category: 'Food',
        pricePaise: 99900, // ₹999
        commissionRate: 0.08, // 8%
      ),
      Product(
        id: 'p_5',
        name: 'Macrame Plant Hanger Craft Kit',
        imageUrl: 'assets/images/categories/diy/Diy_01.png',
        description: 'Complete DIY kit with natural cotton cord, wooden rings, and tutorial guide.',
        category: 'DIY',
        pricePaise: 64900, // ₹649
        commissionRate: 0.10, // 10%
      ),
      Product(
        id: 'p_6',
        name: 'Traveler Waterproof Camera Backpack 35L',
        imageUrl: 'assets/images/categories/travel/Travel_02.png',
        description: 'Padded multi-compartment camera & laptop travel backpack with rain cover.',
        category: 'Travel',
        pricePaise: 299900, // ₹2,999
        commissionRate: 0.12, // 12%
      ),
      Product(
        id: 'p_7',
        name: 'Organic Hydrating Lip Balm Set',
        imageUrl: 'assets/images/categories/beauty/Beauty_02.png',
        description: 'Natural shea butter lip balm trio for daily moisture and soft glow.',
        category: 'Beauty',
        pricePaise: 49900, // ₹499
        commissionRate: 0.10, // 10%
      ),
      Product(
        id: 'p_8',
        name: 'Urban Streetwear Casual Sneakers',
        imageUrl: 'assets/images/categories/fashion/Fashion_03.png',
        description: 'Lightweight cushioned sneakers for daily streetwear fashion and comfort.',
        category: 'Fashion',
        pricePaise: 349900, // ₹3,499
        commissionRate: 0.15, // 15%
      ),
      Product(
        id: 'p_9',
        name: 'Artisanal Organic Spice Blend Box',
        imageUrl: 'assets/images/categories/food/Food_02.png',
        description: 'Hand-picked organic culinary spices in airtight glass jar collection.',
        category: 'Food',
        pricePaise: 89900, // ₹899
        commissionRate: 0.08, // 8%
      ),
      Product(
        id: 'p_10',
        name: 'Handcrafted Wall Hanging Decor Kit',
        imageUrl: 'assets/images/categories/diy/Diy_02.png',
        description: 'Modern bohemian wall hanging DIY kit with wooden dowel and cotton yarn.',
        category: 'DIY',
        pricePaise: 79900, // ₹799
        commissionRate: 0.10, // 10%
      ),
    ];

    // 3. Seed Posts
    _posts = [
      Post(
        id: 'post_fashion_1',
        creatorId: 'u_creator2',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/fashion/fashion_01.mp4',
        caption: 'Awesome fashion content #1! Check this out. #Fashion',
        category: 'Fashion',
        taggedProductIds: ['p_2'],
        viewsCount: 854,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 22,
        productClicksCount: 18,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Post(
        id: 'post_fashion_2',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/fashion/fashion_02.mp4',
        caption: 'Awesome fashion content #2! Check this out. #Fashion',
        category: 'Fashion',
        taggedProductIds: ['p_2'],
        viewsCount: 1049,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 34,
        productClicksCount: 33,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'post_fashion_3',
        creatorId: 'u_creator1',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/fashion/fashion_03.mp4',
        caption: 'Awesome fashion content #3! Check this out. #Fashion',
        category: 'Fashion',
        taggedProductIds: ['p_2'],
        viewsCount: 1544,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 48,
        productClicksCount: 15,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Post(
        id: 'post_fashion_4',
        creatorId: 'u_creator2',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/fashion/fashion_04.mp4',
        caption: 'Awesome fashion content #4! Check this out. #Fashion',
        category: 'Fashion',
        taggedProductIds: ['p_2'],
        viewsCount: 1650,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 9,
        productClicksCount: 24,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Post(
        id: 'post_fashion_5',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/fashion/fashion_05.mp4',
        caption: 'Awesome fashion content #5! Check this out. #Fashion',
        category: 'Fashion',
        taggedProductIds: ['p_2'],
        viewsCount: 945,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 47,
        productClicksCount: 26,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Post(
        id: 'post_beauty_1',
        creatorId: 'u_creator4',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/beauty/beauty_01.mp4',
        caption: 'Awesome beauty content #1! Check this out. #Beauty',
        category: 'Beauty',
        taggedProductIds: ['p_1'],
        viewsCount: 1126,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 13,
        productClicksCount: 16,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Post(
        id: 'post_beauty_2',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/beauty/beauty_02.mp4',
        caption: 'Awesome beauty content #2! Check this out. #Beauty',
        category: 'Beauty',
        taggedProductIds: ['p_1'],
        viewsCount: 510,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 23,
        productClicksCount: 10,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'post_beauty_3',
        creatorId: 'u_creator3',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/beauty/beauty_03.mp4',
        caption: 'Awesome beauty content #3! Check this out. #Beauty',
        category: 'Beauty',
        taggedProductIds: ['p_1'],
        viewsCount: 1865,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 50,
        productClicksCount: 94,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Post(
        id: 'post_beauty_4',
        creatorId: 'u_creator4',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/beauty/beauty_04.mp4',
        caption: 'Awesome beauty content #4! Check this out. #Beauty',
        category: 'Beauty',
        taggedProductIds: ['p_1'],
        viewsCount: 1504,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 49,
        productClicksCount: 63,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Post(
        id: 'post_beauty_5',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/beauty/beauty_05.mp4',
        caption: 'Awesome beauty content #5! Check this out. #Beauty',
        category: 'Beauty',
        taggedProductIds: ['p_1'],
        viewsCount: 584,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 50,
        productClicksCount: 36,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Post(
        id: 'post_travel_1',
        creatorId: 'u_creator6',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/travel/travel_01.mp4',
        caption: 'Awesome travel content #1! Check this out. #Travel',
        category: 'Travel',
        taggedProductIds: ['p_3'],
        viewsCount: 1853,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 12,
        productClicksCount: 29,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Post(
        id: 'post_travel_2',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/travel/travel_02.mp4',
        caption: 'Awesome travel content #2! Check this out. #Travel',
        category: 'Travel',
        taggedProductIds: ['p_3'],
        viewsCount: 267,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 8,
        productClicksCount: 65,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'post_travel_3',
        creatorId: 'u_creator5',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/travel/travel_03.mp4',
        caption: 'Awesome travel content #3! Check this out. #Travel',
        category: 'Travel',
        taggedProductIds: ['p_3'],
        viewsCount: 1245,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 34,
        productClicksCount: 82,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Post(
        id: 'post_travel_4',
        creatorId: 'u_creator6',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/travel/travel_04.mp4',
        caption: 'Awesome travel content #4! Check this out. #Travel',
        category: 'Travel',
        taggedProductIds: ['p_3'],
        viewsCount: 207,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 25,
        productClicksCount: 100,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Post(
        id: 'post_travel_5',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/travel/travel_05.mp4',
        caption: 'Awesome travel content #5! Check this out. #Travel',
        category: 'Travel',
        taggedProductIds: ['p_3'],
        viewsCount: 1409,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 31,
        productClicksCount: 95,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Post(
        id: 'post_food_1',
        creatorId: 'u_creator8',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/food/food_01.mp4',
        caption: 'Awesome food content #1! Check this out. #Food',
        category: 'Food',
        taggedProductIds: ['p_4'],
        viewsCount: 1228,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 32,
        productClicksCount: 56,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Post(
        id: 'post_food_2',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/food/food_02.mp4',
        caption: 'Awesome food content #2! Check this out. #Food',
        category: 'Food',
        taggedProductIds: ['p_4'],
        viewsCount: 540,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 19,
        productClicksCount: 47,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'post_food_3',
        creatorId: 'u_creator7',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/food/food_03.mp4',
        caption: 'Awesome food content #3! Check this out. #Food',
        category: 'Food',
        taggedProductIds: ['p_4'],
        viewsCount: 779,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 20,
        productClicksCount: 74,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Post(
        id: 'post_food_4',
        creatorId: 'u_creator8',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/food/food_04.mp4',
        caption: 'Awesome food content #4! Check this out. #Food',
        category: 'Food',
        taggedProductIds: ['p_4'],
        viewsCount: 600,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 48,
        productClicksCount: 70,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Post(
        id: 'post_food_5',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/food/food_05.mp4',
        caption: 'Awesome food content #5! Check this out. #Food',
        category: 'Food',
        taggedProductIds: ['p_4'],
        viewsCount: 318,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 25,
        productClicksCount: 81,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Post(
        id: 'post_diy_1',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/diy/diy_01.mp4',
        caption: 'Awesome diy content #1! Check this out. #DIY',
        category: 'DIY',
        taggedProductIds: ['p_5'],
        viewsCount: 777,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 6,
        productClicksCount: 94,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Post(
        id: 'post_diy_2',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/diy/diy_02.mp4',
        caption: 'Awesome diy content #2! Check this out. #DIY',
        category: 'DIY',
        taggedProductIds: ['p_5'],
        viewsCount: 1641,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 9,
        productClicksCount: 75,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'post_diy_3',
        creatorId: 'u_creator9',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/diy/diy_03.mp4',
        caption: 'Awesome diy content #3! Check this out. #DIY',
        category: 'DIY',
        taggedProductIds: ['p_5'],
        viewsCount: 1066,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 8,
        productClicksCount: 13,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Post(
        id: 'post_diy_4',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/diy/diy_04.mp4',
        caption: 'Awesome diy content #4! Check this out. #DIY',
        category: 'DIY',
        taggedProductIds: ['p_5'],
        viewsCount: 1431,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 34,
        productClicksCount: 96,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Post(
        id: 'post_diy_5',
        creatorId: 'u_creator10',
        creatorName: 'Creator Name', // will be resolved dynamically by UI usually, but let's put dummy
        creatorAvatarUrl: 'assets/images/creator_rohan.png',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/categories/diy/diy_05.mp4',
        caption: 'Awesome diy content #5! Check this out. #DIY',
        category: 'DIY',
        taggedProductIds: ['p_5'],
        viewsCount: 405,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 46,
        productClicksCount: 74,
        filterName: 'Normal',
        musicTitle: 'Lo-Fi Chill Beats',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
    ];

    // 4. Seed Historical Orders & Commissions (Attributed to Priya for post_1)
    _orders = [
      Order(
        id: 'ord_demo_101',
        idempotencyKey: 'idem_demo_101',
        buyerUserId: 'u_viewer',
        buyerName: 'Aanya Sharma',
        items: [
          OrderItem(
            productId: 'p_2',
            productName: 'Oversized Pastel Denim Jacket',
            pricePaise: 249900,
            quantity: 1,
            referrerCreatorId: 'u_creator1',
            referrerPostId: 'post_1',
            commissionRate: 0.10,
          ),
        ],
        totalPaise: 249900,
        shippingAddress: '123 Park Street, Bandra West, Mumbai, MH - 400050',
        status: OrderStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    _commissions = [
      CommissionTransaction(
        id: 'comm_demo_101',
        creatorId: 'u_creator1',
        orderId: 'ord_demo_101',
        productId: 'p_2',
        amountPaise: 24990, // ₹249.90 commission
        status: CommissionStatus.available,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    _revShares = [
      RevenueShareRecord(
        id: 'rev_1',
        creatorId: 'u_creator1',
        sourceAmountPaise: 1000000, // ₹10,000 platform campaign budget
        shareRate: 0.20, // 20%
        calculatedSharePaise: 200000, // ₹2,000 share
        note: 'Q3 Lifestyle Creator Bonus Program Allocation',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    _reviews = [
      ProductReview(
        id: 'rev_p2_1',
        productId: 'p_2',
        userId: 'u_viewer',
        userName: 'Aanya Sharma',
        userAvatarUrl: 'assets/images/viewer_aanya.png',
        rating: 5.0,
        comment: 'Absolutely love the denim jacket! Excellent quality and fast shipping.',
        isVerifiedPurchase: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];

    _verifications = [
      VerificationApplication(
        id: 'ver_app_1',
        creatorId: 'u_creator1',
        creatorName: 'Priya Fashionista',
        category: 'Fashion & Beauty',
        socialLink: 'https://instagram.com/priya_style',
        reason: 'Established lifestyle content creator with over 50k Instagram followers.',
        status: VerificationStatus.approved,
        submittedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];

    await _saveAll();
  }

  Future<void> _saveAll() async {
    await _saveList(_kKeyUsers, _users.map((u) => u.toJson()).toList());
    await _saveList(_kKeyProducts, _products.map((p) => p.toJson()).toList());
    await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
    await _saveList(_kKeyOrders, _orders.map((o) => o.toJson()).toList());
    await _saveList(
      _kKeyCommissions,
      _commissions.map((c) => c.toJson()).toList(),
    );
    await _saveList(
      _kKeyWithdrawals,
      _withdrawals.map((w) => w.toJson()).toList(),
    );
    await _saveList(_kKeyRevShares, _revShares.map((r) => r.toJson()).toList());
    await _saveList(_kKeyReviews, _reviews.map((r) => r.toJson()).toList());
    await _saveList(
      _kKeyVerifications,
      _verifications.map((v) => v.toJson()).toList(),
    );
    await _saveList(
      _kKeyPromotions,
      _promotions.map((p) => p.toJson()).toList(),
    );
  }

  // --- Implement AppRepositoryInterface Methods ---

  @override
  List<User> getUsers() => List.unmodifiable(_users);

  @override
  User? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateUser(User user) async {
    int idx = _users.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      _users[idx] = user;
      await _saveList(_kKeyUsers, _users.map((u) => u.toJson()).toList());
    }
  }

  @override
  bool isFollowing(String currentUserId, String targetUserId) {
    List<String> following =
        _prefs.getStringList('$_kKeyFollowsPrefix$currentUserId') ?? [];
    return following.contains(targetUserId);
  }

  @override
  Future<void> toggleFollowUser(
    String currentUserId,
    String targetUserId,
  ) async {
    // Self-follow prevention
    if (currentUserId == targetUserId) return;

    List<String> following =
        _prefs.getStringList('$_kKeyFollowsPrefix$currentUserId') ?? [];
    User? targetUser = getUserById(targetUserId);
    if (targetUser == null) return;

    if (following.contains(targetUserId)) {
      following.remove(targetUserId);
      targetUser = targetUser.copyWith(
        followerCount: (targetUser.followerCount - 1).clamp(0, 999999),
      );
    } else {
      // Prevent duplicate followers
      following.add(targetUserId);
      targetUser = targetUser.copyWith(
        followerCount: targetUser.followerCount + 1,
      );
    }
    await _prefs.setStringList('$_kKeyFollowsPrefix$currentUserId', following);
    await updateUser(targetUser);
  }

  @override
  List<Product> getProducts() => List.unmodifiable(_products);

  @override
  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addProduct(Product product) async {
    _products.add(product);
    await _saveList(_kKeyProducts, _products.map((p) => p.toJson()).toList());
  }

  @override
  List<Post> getPosts() => List.unmodifiable(_posts);

  @override
  Post? getPostById(String id) {
    try {
      return _posts.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addPost(Post post) async {
    _posts.insert(0, post);
    await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
  }

  @override
  Future<void> updatePost(Post post) async {
    int idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx != -1) {
      _posts[idx] = post;
      await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
    }
  }

  @override
  Future<bool> incrementPostViews(String postId, String viewerUserId) async {
    // Prevent widget rebuild from triggering multiple view increments
    String key = '$_kKeyViewedPostsPrefix${viewerUserId}_$postId';
    if (_prefs.getBool(key) == true) return false;

    int idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _posts[idx] = _posts[idx].copyWith(
        viewsCount: _posts[idx].viewsCount + 1,
      );
      await _prefs.setBool(key, true);
      await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
      return true;
    }
    return false;
  }

  @override
  Future<void> togglePostLike(String postId, String userId) async {
    int idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    Post post = _posts[idx];
    List<String> likes = List.from(post.likedUserIds);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }
    _posts[idx] = post.copyWith(likedUserIds: likes);
    await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
  }

  @override
  Future<void> addPostComment(
    String postId,
    String userId,
    String userName,
    String text,
  ) async {
    int idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    Post post = _posts[idx];
    Comment comment = Comment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      text: text,
      createdAt: DateTime.now(),
    );
    List<Comment> updatedComments = List.from(post.comments)..add(comment);
    _posts[idx] = post.copyWith(comments: updatedComments);
    await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
  }

  @override
  Future<void> incrementPostShares(String postId) async {
    int idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _posts[idx] = _posts[idx].copyWith(
        sharesCount: _posts[idx].sharesCount + 1,
      );
      await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
    }
  }

  @override
  Future<void> recordProductClick(
    String postId,
    String productId,
    String userId,
  ) async {
    int idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      if (_posts[idx].creatorId == userId) {
        return; // Exclude self-clicks
      }

      String key = 'trell_click_${userId}_${postId}_$productId';
      int? lastClickTime = _prefs.getInt(key);
      int now = DateTime.now().millisecondsSinceEpoch;
      // 30 minute duplicate click prevention window
      if (lastClickTime != null && (now - lastClickTime) < 30 * 60 * 1000) {
        return;
      }

      _posts[idx] = _posts[idx].copyWith(
        productClicksCount: _posts[idx].productClicksCount + 1,
      );
      await _prefs.setInt(key, now);
      await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
    }
  }

  @override
  Future<void> promotePost(String postId, int durationDays) async {
    // Kept for backward compatibility — delegates to Post model flags.
    // New callers should use createPromotionAttempt for proper record-keeping.
    int idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final now = DateTime.now().toUtc();
      _posts[idx] = _posts[idx].copyWith(
        isPromoted: true,
        promotionExpiry: now.add(Duration(days: durationDays)),
      );
      await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
    }
  }

  // --- Cart Implementation ---
  @override
  List<CartItem> getCart(String userId) {
    String key = '$_kKeyCartPrefix$userId';
    List<dynamic> raw = _decodeList(key);
    return raw.map((x) => CartItem.fromJson(x)).toList();
  }

  Future<void> _saveCart(String userId, List<CartItem> cart) async {
    String key = '$_kKeyCartPrefix$userId';
    await _saveList(key, cart.map((item) => item.toJson()).toList());
  }

  @override
  Future<void> addToCart(
    String userId,
    Product product,
    String? creatorId,
    String? postId,
  ) async {
    List<CartItem> cart = getCart(userId);
    // Separate items by product, creator, AND post attribution
    int idx = cart.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.referrerCreatorId == creatorId &&
          item.referrerPostId == postId,
    );

    if (idx != -1) {
      cart[idx] = cart[idx].copyWith(quantity: cart[idx].quantity + 1);
    } else {
      // Build a stable cartItemId from the three identity fields so that the
      // same product+creator+post combination always gets the same key.
      final cartItemId =
          'ci_${product.id}_${creatorId ?? 'direct'}_${postId ?? 'none'}';
      cart.add(
        CartItem(
          cartItemId: cartItemId,
          product: product,
          quantity: 1,
          referrerCreatorId: creatorId,
          referrerPostId: postId,
        ),
      );
    }
    await _saveCart(userId, cart);
  }

  @override
  Future<void> updateCartQuantity(
    String userId,
    String productId,
    String? creatorId,
    String? postId,
    int quantity,
  ) async {
    List<CartItem> cart = getCart(userId);
    int idx = cart.indexWhere(
      (item) =>
          item.product.id == productId &&
          item.referrerCreatorId == creatorId &&
          item.referrerPostId == postId,
    );
    if (idx != -1) {
      if (quantity <= 0) {
        cart.removeAt(idx);
      } else {
        cart[idx] = cart[idx].copyWith(quantity: quantity);
      }
      await _saveCart(userId, cart);
    }
  }

  @override
  Future<void> removeFromCart(
    String userId,
    String productId,
    String? creatorId,
    String? postId,
  ) async {
    List<CartItem> cart = getCart(userId);
    cart.removeWhere(
      (item) =>
          item.product.id == productId &&
          item.referrerCreatorId == creatorId &&
          item.referrerPostId == postId,
    );
    await _saveCart(userId, cart);
  }

  @override
  Future<void> clearCart(String userId) async {
    await _prefs.remove('$_kKeyCartPrefix$userId');
  }

  // --- Orders & Checkout ---
  @override
  List<Order> getOrders() => List.unmodifiable(_orders);

  @override
  List<Order> getOrdersForUser(String userId) {
    return _orders.where((o) => o.buyerUserId == userId).toList();
  }

  @override
  Future<Order> createOrder({
    required String buyerUserId,
    required String buyerName,
    required List<CartItem> items,
    required String shippingAddress,
    required bool simulateSuccess,
    String? idempotencyKey,
  }) async {
    // ── Idempotency check ─────────────────────────────────────────────────────
    // If this exact checkout attempt was already processed, return existing order.
    if (idempotencyKey != null) {
      final existing = _orders.where((o) => o.idempotencyKey == idempotencyKey);
      if (existing.isNotEmpty) {
        return existing.first;
      }
    }

    final idem =
        idempotencyKey ?? 'idem_${DateTime.now().millisecondsSinceEpoch}';
    int totalPaise = items.fold(0, (sum, item) => sum + item.totalPaise);
    OrderStatus status = simulateSuccess
        ? OrderStatus.paid
        : OrderStatus.cancelled;

    // Snapshot product data into order items (immutable historical record)
    List<OrderItem> orderItems = items.map((cartItem) {
      // Validate commission rate is in 5–15% range
      double rate = cartItem.product.commissionRate.clamp(0.05, 0.15);
      return OrderItem(
        productId: cartItem.product.id,
        productName: cartItem.product.name,
        pricePaise: cartItem.product.pricePaise, // snapshot at purchase time
        quantity: cartItem.quantity,
        referrerCreatorId: cartItem.referrerCreatorId,
        referrerPostId: cartItem.referrerPostId,
        commissionRate: rate,
      );
    }).toList();

    Order newOrder = Order(
      id: 'ord_${DateTime.now().microsecondsSinceEpoch}',
      idempotencyKey: idem,
      buyerUserId: buyerUserId,
      buyerName: buyerName,
      items: orderItems,
      totalPaise: totalPaise,
      shippingAddress: shippingAddress,
      status: status,
      createdAt: DateTime.now(),
    );

    _orders.insert(0, newOrder);

    if (simulateSuccess) {
      // Create Pending Commission only for attributed items
      for (var item in orderItems) {
        if (item.referrerCreatorId != null &&
            item.referrerCreatorId!.isNotEmpty) {
          // Duplicate commission prevention: check no commission already exists
          bool alreadyExists = _commissions.any(
            (c) =>
                c.orderId == newOrder.id &&
                c.productId == item.productId &&
                c.creatorId == item.referrerCreatorId,
          );
          if (!alreadyExists) {
            int commAmount = item.calculatedCommissionPaise;
            CommissionTransaction comm = CommissionTransaction(
              id: 'comm_${DateTime.now().microsecondsSinceEpoch}_${item.productId}',
              creatorId: item.referrerCreatorId!,
              orderId: newOrder.id,
              productId: item.productId,
              amountPaise: commAmount,
              status: CommissionStatus.pending,
              createdAt: DateTime.now(),
            );
            _commissions.insert(0, comm);
          }
        }
      }
      await clearCart(buyerUserId);
    }
    // Failed/cancelled orders: cart is preserved, no commission created.

    await _saveAll();
    return newOrder;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    int idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;

    Order oldOrder = _orders[idx];
    if (oldOrder.status == newStatus) {
      return; // Idempotent: already in target state
    }

    // ── Enforce transition table ──────────────────────────────────────────────
    if (!oldOrder.status.canTransitionTo(newStatus)) {
      // Silently ignore invalid transitions (repository-level enforcement).
      // Callers should validate before calling, but this prevents corruption.
      return;
    }

    _orders[idx] = oldOrder.copyWith(status: newStatus);

    if (newStatus == OrderStatus.completed) {
      // Transition pending commissions for this order to available (settlement)
      for (int i = 0; i < _commissions.length; i++) {
        if (_commissions[i].orderId == orderId &&
            _commissions[i].status == CommissionStatus.pending) {
          _commissions[i] = _commissions[i].copyWith(
            status: CommissionStatus.available,
          );
        }
      }
    } else if (newStatus == OrderStatus.cancelled) {
      // Reverse only pending commissions (if cancelled before completion)
      for (int i = 0; i < _commissions.length; i++) {
        if (_commissions[i].orderId == orderId &&
            _commissions[i].status == CommissionStatus.pending) {
          _commissions[i] = _commissions[i].copyWith(
            status: CommissionStatus.reversed,
          );
        }
      }
    } else if (newStatus == OrderStatus.refunded) {
      // Refund after payment — handle by commission lifecycle stage:
      for (int i = 0; i < _commissions.length; i++) {
        if (_commissions[i].orderId != orderId) continue;
        final comm = _commissions[i];
        switch (comm.status) {
          case CommissionStatus.pending:
          case CommissionStatus.available:
            // Before or after settlement but before reservation: reverse
            _commissions[i] = comm.copyWith(status: CommissionStatus.reversed);
            break;
          case CommissionStatus.reserved:
            // While reserved: cancel reservation back to reversed
            _commissions[i] = comm.copyWith(status: CommissionStatus.reversed);
            break;
          case CommissionStatus.paidOut:
            // After payout: create clawback record (debt to platform)
            // Preserve the paidOut record as historical cash record.
            _commissions.add(
              CommissionTransaction(
                id: 'claw_${DateTime.now().microsecondsSinceEpoch}_${comm.productId}',
                creatorId: comm.creatorId,
                orderId: orderId,
                productId: comm.productId,
                amountPaise: -comm.amountPaise, // Negative = debt
                status: CommissionStatus.clawback,
                createdAt: DateTime.now(),
                withdrawalId: comm.withdrawalId,
              ),
            );
            break;
          case CommissionStatus.reversed:
          case CommissionStatus.clawback:
            break; // Already reversed or already has clawback — idempotent
        }
      }
    }

    await _saveAll();
  }

  // --- Wallet & Withdrawals ---
  @override
  List<CommissionTransaction> getCommissionsForCreator(String creatorId) {
    return _commissions.where((c) => c.creatorId == creatorId).toList();
  }

  @override
  List<WithdrawalRequest> getWithdrawalRequests() =>
      List.unmodifiable(_withdrawals);

  @override
  List<WithdrawalRequest> getWithdrawalRequestsForCreator(String creatorId) {
    return _withdrawals.where((w) => w.creatorId == creatorId).toList();
  }

  @override
  Future<WithdrawalRequest?> requestWithdrawal(
    String creatorId,
    String creatorName,
    int amountPaise,
    String upiIdOrBank,
  ) async {
    // Repository rule: Minimum withdrawal of ₹100 (10,000 paise) & positive amount
    if (amountPaise < 10000 || amountPaise <= 0) {
      return null;
    }
    // UPI/bank must not be empty
    if (upiIdOrBank.trim().isEmpty) return null;

    // 1. Check for outstanding clawback debt — block new withdrawals if debt exists
    int totalClawback = _commissions
        .where(
          (c) =>
              c.creatorId == creatorId && c.status == CommissionStatus.clawback,
        )
        .fold(
          0,
          (sum, c) => sum + c.amountPaise,
        ); // amountPaise is negative for clawback
    // totalClawback is negative; if it's below zero, creator owes money
    if (totalClawback < 0) {
      return null; // Outstanding recovery due; cannot withdraw
    }

    // 2. Calculate available balance
    int totalAvailable = _commissions
        .where(
          (c) =>
              c.creatorId == creatorId &&
              c.status == CommissionStatus.available,
        )
        .fold(0, (sum, c) => sum + c.amountPaise);

    // Subtract existing pending withdrawal reservations (already requested but not processed)
    int pendingWithdrawals = _withdrawals
        .where(
          (w) =>
              w.creatorId == creatorId && w.status == WithdrawalStatus.pending,
        )
        .fold(0, (sum, w) => sum + w.amountPaise);

    int netAvailable = totalAvailable - pendingWithdrawals;
    if (amountPaise > netAvailable) {
      return null; // Insufficient funds
    }

    final reqId = 'wdr_${DateTime.now().millisecondsSinceEpoch}';
    WithdrawalRequest req = WithdrawalRequest(
      id: reqId,
      creatorId: creatorId,
      creatorName: creatorName,
      amountPaise: amountPaise,
      upiIdOrBank: upiIdOrBank,
      status: WithdrawalStatus.pending,
      requestedAt: DateTime.now(),
    );

    // Move requested amount from available → reserved in commission ledger
    int remainingReservation = amountPaise;
    for (int i = 0; i < _commissions.length; i++) {
      if (_commissions[i].creatorId == creatorId &&
          _commissions[i].status == CommissionStatus.available) {
        if (_commissions[i].amountPaise <= remainingReservation) {
          remainingReservation -= _commissions[i].amountPaise;
          _commissions[i] = _commissions[i].copyWith(
            status: CommissionStatus.reserved,
            withdrawalId: reqId,
          );
        } else {
          // Partial split: create a reserved portion and keep remainder available
          int reservedPortion = remainingReservation;
          int leftover = _commissions[i].amountPaise - reservedPortion;
          _commissions[i] = _commissions[i].copyWith(
            amountPaise: reservedPortion,
            status: CommissionStatus.reserved,
            withdrawalId: reqId,
          );
          _commissions.add(
            CommissionTransaction(
              id: 'comm_split_${DateTime.now().microsecondsSinceEpoch}',
              creatorId: creatorId,
              orderId: _commissions[i].orderId,
              productId: _commissions[i].productId,
              amountPaise: leftover,
              status: CommissionStatus.available,
              createdAt: _commissions[i].createdAt,
            ),
          );
          remainingReservation = 0;
          break;
        }
        if (remainingReservation <= 0) break;
      }
    }

    _withdrawals.insert(0, req);
    await _saveAll();
    return req;
  }

  @override
  Future<void> processWithdrawal(
    String requestId,
    bool approve, {
    String? reason,
  }) async {
    int idx = _withdrawals.indexWhere((w) => w.id == requestId);
    if (idx == -1) return;

    WithdrawalRequest req = _withdrawals[idx];
    // Idempotent: only process pending requests
    if (req.status != WithdrawalStatus.pending) return;

    if (approve) {
      // Verify reserved commissions for this withdrawal still exist
      int reserved = _commissions
          .where(
            (c) =>
                c.withdrawalId == requestId &&
                c.status == CommissionStatus.reserved,
          )
          .fold(0, (sum, c) => sum + c.amountPaise);
      if (reserved < req.amountPaise) {
        // Funds no longer reserved (e.g., refund happened while pending)
        // Auto-reject with explanation
        _withdrawals[idx] = req.copyWith(
          status: WithdrawalStatus.rejected,
          processedAt: DateTime.now(),
          rejectionReason: 'Reserved funds were adjusted (refund occurred); please re-request',
        );
        // Release remaining reserved commissions for this withdrawal back to available
        for (int i = 0; i < _commissions.length; i++) {
          if (_commissions[i].withdrawalId == requestId &&
              _commissions[i].status == CommissionStatus.reserved) {
            _commissions[i] = _commissions[i].copyWith(
              status: CommissionStatus.available,
            );
          }
        }
        await _saveAll();
        return;
      }

      // Move reserved → paidOut (ONLY the reserved amount for this withdrawal)
      for (int i = 0; i < _commissions.length; i++) {
        if (_commissions[i].withdrawalId == requestId &&
            _commissions[i].status == CommissionStatus.reserved) {
          _commissions[i] = _commissions[i].copyWith(
            status: CommissionStatus.paidOut,
          );
        }
      }

      _withdrawals[idx] = req.copyWith(
        status: WithdrawalStatus.approved,
        processedAt: DateTime.now(),
      );
    } else {
      // Rejection: release reserved commissions back to available
      for (int i = 0; i < _commissions.length; i++) {
        if (_commissions[i].withdrawalId == requestId &&
            _commissions[i].status == CommissionStatus.reserved) {
          _commissions[i] = _commissions[i].copyWith(
            status: CommissionStatus.available,
            withdrawalId: null,
          );
        }
      }

      _withdrawals[idx] = req.copyWith(
        status: WithdrawalStatus.rejected,
        processedAt: DateTime.now(),
        rejectionReason: reason ?? 'Rejected by admin',
      );
    }

    await _saveAll();
  }

  // --- Revenue Share ---
  @override
  List<RevenueShareRecord> getRevenueShareRecordsForCreator(String creatorId) {
    return _revShares.where((r) => r.creatorId == creatorId).toList();
  }

  @override
  Future<void> recordRevenueShare(
    String creatorId,
    int sourcePaise,
    double shareRate,
    String note,
  ) async {
    double clampedRate = shareRate.clamp(0.0, 0.30); // Max 30% cap
    int sharePaise = (sourcePaise * clampedRate).round();

    RevenueShareRecord rec = RevenueShareRecord(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: creatorId,
      sourceAmountPaise: sourcePaise,
      shareRate: clampedRate,
      calculatedSharePaise: sharePaise,
      note: note,
      createdAt: DateTime.now(),
    );

    _revShares.insert(0, rec);
    await _saveList(_kKeyRevShares, _revShares.map((r) => r.toJson()).toList());
  }

  // --- Reviews & Verifications ---
  @override
  List<ProductReview> getReviewsForProduct(String productId) {
    return _reviews.where((r) => r.productId == productId).toList();
  }

  // ── Verified Purchase eligibility (Step 9 §1) ─────────────────────────────
  // A review is eligible for Verified Purchase badge iff the reviewing user
  // has at least one order that:
  //   • belongs to the same userId
  //   • has status == OrderStatus.completed   (delivered; paid alone does not qualify)
  //   • is NOT refunded (status != refunded)
  //   • contains an OrderItem for [productId]
  // Failed, cancelled, unpaid, and fully refunded orders do NOT qualify.
  // A different user's order never qualifies.
  @override
  bool hasUserPurchasedProduct(String userId, String productId) {
    return _orders.any(
      (order) =>
          order.buyerUserId == userId &&
          order.status == OrderStatus.completed && // Must be delivered
          order.items.any((item) => item.productId == productId),
    );
  }

  @override
  Future<void> addProductReview(
    String productId,
    String userId,
    String userName,
    String avatarUrl,
    double rating,
    String comment,
  ) async {
    // Validate rating range [1.0, 5.0]
    final clampedRating = rating.clamp(1.0, 5.0);
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) return; // Reject empty reviews

    final isVerified = hasUserPurchasedProduct(userId, productId);

    // One review per (userId, productId): overwrite existing if present
    final existingIdx = _reviews.indexWhere(
      (r) => r.userId == userId && r.productId == productId,
    );

    final rev = ProductReview(
      id: existingIdx != -1
          ? _reviews[existingIdx]
                .id // Preserve original review ID on edit
          : 'rev_${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      userId: userId,
      userName: userName,
      userAvatarUrl: avatarUrl,
      rating: clampedRating,
      comment: trimmedComment,
      isVerifiedPurchase: isVerified,
      createdAt: existingIdx != -1
          ? _reviews[existingIdx].createdAt
          : DateTime.now(),
    );

    if (existingIdx != -1) {
      _reviews[existingIdx] = rev;
    } else {
      _reviews.insert(0, rev);
    }
    await _saveList(_kKeyReviews, _reviews.map((r) => r.toJson()).toList());
  }

  // Re-evaluate all existing reviews for [productId] after order changes.
  // Updates isVerifiedPurchase without deleting review text (Step 9 §2).
  @override
  Future<void> reEvaluateReviewBadges(String productId) async {
    bool changed = false;
    for (int i = 0; i < _reviews.length; i++) {
      if (_reviews[i].productId != productId) continue;
      final newFlag = hasUserPurchasedProduct(_reviews[i].userId, productId);
      if (_reviews[i].isVerifiedPurchase != newFlag) {
        _reviews[i] = _reviews[i].copyWith(isVerifiedPurchase: newFlag);
        changed = true;
      }
    }
    if (changed) {
      await _saveList(_kKeyReviews, _reviews.map((r) => r.toJson()).toList());
    }
  }

  @override
  List<VerificationApplication> getVerificationApplications() =>
      List.unmodifiable(_verifications);

  @override
  VerificationApplication? getVerificationForCreator(String creatorId) {
    try {
      return _verifications.firstWhere((v) => v.creatorId == creatorId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> submitVerification(
    String creatorId,
    String creatorName,
    String category,
    String socialLink,
    String reason,
  ) async {
    // Validate fields — must be non-empty after trimming
    if (category.trim().isEmpty ||
        socialLink.trim().isEmpty ||
        reason.trim().isEmpty) {
      return;
    }

    // Prevent duplicate pending application: only allow resubmission if
    // previous application is rejected (documented reapplication rule).
    final existing = _verifications.where((v) => v.creatorId == creatorId);
    if (existing.isNotEmpty) {
      final prev = existing.first;
      if (prev.status == VerificationStatus.pending ||
          prev.status == VerificationStatus.approved) {
        return; // Already pending or approved — no duplicate submission
      }
    }

    final app = VerificationApplication(
      id: 'ver_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: creatorId,
      creatorName: creatorName,
      category: category.trim(),
      socialLink: socialLink.trim(),
      reason: reason.trim(),
      status: VerificationStatus.pending,
      submittedAt: DateTime.now(),
    );

    _verifications.removeWhere((v) => v.creatorId == creatorId);
    _verifications.insert(0, app);
    await _saveList(
      _kKeyVerifications,
      _verifications.map((v) => v.toJson()).toList(),
    );
  }

  @override
  Future<void> processVerification(
    String applicationId,
    bool approve, {
    required String adminId,
    String? rejectionReason,
  }) async {
    // Enforce admin role at repository level (Step 9 §4)
    final adminUser = getUserById(adminId);
    if (adminUser == null || adminUser.role != UserRole.admin) return;

    int idx = _verifications.indexWhere((v) => v.id == applicationId);
    if (idx == -1) return;

    final app = _verifications[idx];

    // Idempotent: only process pending applications
    if (app.status != VerificationStatus.pending) return;

    // Self-approval guard: admin cannot approve their own creator application
    if (adminId == app.creatorId) return;

    // Rejection requires a reason
    if (!approve &&
        (rejectionReason == null || rejectionReason.trim().isEmpty)) {
      return;
    }

    final newStatus = approve
        ? VerificationStatus.approved
        : VerificationStatus.rejected;
    _verifications[idx] = app.copyWith(
      status: newStatus,
      decidedByAdminId: adminId,
      decidedAt: DateTime.now(),
      rejectionReason: approve ? null : rejectionReason!.trim(),
    );

    if (approve) {
      // Update creator's isVerifiedCreator flag — posts resolve this dynamically
      final user = getUserById(app.creatorId);
      if (user != null) {
        await updateUser(user.copyWith(isVerifiedCreator: true));
      }
    }

    await _saveAll();
  }

  // ─── Promotions (Step 10) ──────────────────────────────────────────────────

  @override
  List<PromotionRecord> getPromotionsForCreator(String creatorId) {
    return _promotions.where((p) => p.creatorId == creatorId).toList();
  }

  @override
  List<PromotionRecord> getAllPromotions() => List.unmodifiable(_promotions);

  @override
  Future<PromotionRecord> createPromotionAttempt({
    required String paymentAttemptId,
    required String postId,
    required String creatorId,
    required bool simulateSuccess,
    String? failureReason,
  }) async {
    // ── Idempotency: same attempt key → return existing record ──────────────
    final existing = _promotions.where(
      (p) => p.paymentAttemptId == paymentAttemptId,
    );
    if (existing.isNotEmpty) return existing.first;

    // ── Ownership check: only the creator may promote their own post ─────────
    final post = getPostById(postId);
    if (post == null || post.creatorId != creatorId) {
      // Create a failed record for audit trail
      final failed = PromotionRecord(
        id: 'promo_${DateTime.now().microsecondsSinceEpoch}',
        paymentAttemptId: paymentAttemptId,
        postId: postId,
        creatorId: creatorId,
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.failed,
        failureReason: 'Post not found or ownership mismatch',
        createdAt: DateTime.now().toUtc(),
      );
      _promotions.insert(0, failed);
      await _saveList(
        _kKeyPromotions,
        _promotions.map((p) => p.toJson()).toList(),
      );
      return failed;
    }

    // ── Prevent concurrent pending attempts for the same post ────────────────
    final hasPendingAttempt = _promotions.any(
      (p) =>
          p.postId == postId &&
          p.paymentStatus == PromotionPaymentStatus.pending,
    );
    if (hasPendingAttempt) {
      // Return the existing pending attempt so caller can resolve it
      return _promotions.firstWhere(
        (p) =>
            p.postId == postId &&
            p.paymentStatus == PromotionPaymentStatus.pending,
      );
    }

    // ── Prevent duplicate active promotions for the same post ────────────────
    if (simulateSuccess) {
      final hasActivePromotion = _promotions.any(
        (p) => p.postId == postId && p.isActive(),
      );
      if (hasActivePromotion) {
        // Return existing active promotion as if this was a replay
        return _promotions.firstWhere(
          (p) => p.postId == postId && p.isActive(),
        );
      }
    }

    final now = DateTime.now().toUtc();
    PromotionRecord record;

    if (simulateSuccess) {
      record = PromotionRecord(
        id: 'promo_${DateTime.now().microsecondsSinceEpoch}',
        paymentAttemptId: paymentAttemptId,
        postId: postId,
        creatorId: creatorId,
        packagePricePaise: 49900, // ₹499 in paise
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: now,
        expiryTime: now.add(const Duration(days: 7)),
        createdAt: now,
      );
      // Also update Post flags for backward compatibility with feed sorting
      final idx = _posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        _posts[idx] = _posts[idx].copyWith(
          isPromoted: true,
          promotionExpiry: now.add(const Duration(days: 7)),
        );
      }
    } else {
      record = PromotionRecord(
        id: 'promo_${DateTime.now().microsecondsSinceEpoch}',
        paymentAttemptId: paymentAttemptId,
        postId: postId,
        creatorId: creatorId,
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: failureReason == null
            ? PromotionPaymentStatus.cancelled
            : PromotionPaymentStatus.failed,
        failureReason: failureReason,
        createdAt: now,
      );
      // Failed/cancelled: do NOT update Post promotion flags
    }

    _promotions.insert(0, record);
    await _saveAll();
    return record;
  }
}
