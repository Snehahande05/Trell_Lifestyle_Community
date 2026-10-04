import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/post.dart';
import '../models/order.dart';
import '../models/wallet.dart';
import '../models/review_and_verification.dart';

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
  Future<void> addPostComment(String postId, String userId, String userName, String text);
  Future<void> incrementPostShares(String postId);
  Future<void> recordProductClick(String postId, String productId, String userId);
  Future<void> promotePost(String postId, int durationDays);

  // Cart & Orders
  List<CartItem> getCart(String userId);
  Future<void> addToCart(String userId, Product product, String? creatorId, String? postId);
  Future<void> updateCartQuantity(String userId, String productId, String? creatorId, String? postId, int quantity);
  Future<void> removeFromCart(String userId, String productId, String? creatorId, String? postId);
  Future<void> clearCart(String userId);

  List<Order> getOrders();
  List<Order> getOrdersForUser(String userId);
  Future<Order> createOrder({
    required String buyerUserId,
    required String buyerName,
    required List<CartItem> items,
    required String shippingAddress,
    required bool simulateSuccess,
  });
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus);

  // Wallet & Commissions
  List<CommissionTransaction> getCommissionsForCreator(String creatorId);
  List<WithdrawalRequest> getWithdrawalRequests();
  List<WithdrawalRequest> getWithdrawalRequestsForCreator(String creatorId);
  Future<WithdrawalRequest?> requestWithdrawal(String creatorId, String creatorName, int amountPaise, String upiIdOrBank);
  Future<void> processWithdrawal(String requestId, bool approve, {String? reason});
  
  // Revenue Share
  List<RevenueShareRecord> getRevenueShareRecordsForCreator(String creatorId);
  Future<void> recordRevenueShare(String creatorId, int sourcePaise, double shareRate, String note);

  // Reviews & Verification
  List<ProductReview> getReviewsForProduct(String productId);
  bool hasUserPurchasedProduct(String userId, String productId);
  Future<void> addProductReview(String productId, String userId, String userName, String avatarUrl, double rating, String comment);

  List<VerificationApplication> getVerificationApplications();
  VerificationApplication? getVerificationForCreator(String creatorId);
  Future<void> submitVerification(String creatorId, String creatorName, String category, String socialLink, String reason);
  Future<void> processVerification(String applicationId, bool approve);
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
  static const String _kKeyFollowsPrefix = 'trell_follows_';
  static const String _kKeyViewedPostsPrefix = 'trell_viewed_';

  late SharedPreferences _prefs;

  List<User> _users = [];
  List<Product> _products = [];
  List<Post> _posts = [];
  List<Order> _orders = [];
  List<CommissionTransaction> _commissions = [];
  List<WithdrawalRequest> _withdrawals = [];
  List<RevenueShareRecord> _revShares = [];
  List<ProductReview> _reviews = [];
  List<VerificationApplication> _verifications = [];

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
    _users = (_decodeList(_kKeyUsers) as List).map((x) => User.fromJson(x)).toList();
    _products = (_decodeList(_kKeyProducts) as List).map((x) => Product.fromJson(x)).toList();
    _posts = (_decodeList(_kKeyPosts) as List).map((x) => Post.fromJson(x)).toList();
    _orders = (_decodeList(_kKeyOrders) as List).map((x) => Order.fromJson(x)).toList();
    _commissions = (_decodeList(_kKeyCommissions) as List).map((x) => CommissionTransaction.fromJson(x)).toList();
    _withdrawals = (_decodeList(_kKeyWithdrawals) as List).map((x) => WithdrawalRequest.fromJson(x)).toList();
    _revShares = (_decodeList(_kKeyRevShares) as List).map((x) => RevenueShareRecord.fromJson(x)).toList();
    _reviews = (_decodeList(_kKeyReviews) as List).map((x) => ProductReview.fromJson(x)).toList();
    _verifications = (_decodeList(_kKeyVerifications) as List).map((x) => VerificationApplication.fromJson(x)).toList();
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
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        role: UserRole.viewer,
        bio: 'Lifestyle enthusiast & avid shopper!',
      ),
      User(
        id: 'u_creator1',
        name: 'Priya Fashionista',
        username: 'priya_style',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        role: UserRole.creator,
        isVerifiedCreator: true,
        bio: 'Fashion & Beauty creator based in Mumbai ✨',
        followerCount: 1420,
      ),
      User(
        id: 'u_creator2',
        name: 'Rohan Traveler',
        username: 'rohan_explores',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        role: UserRole.creator,
        isVerifiedCreator: false,
        bio: 'Exploring hidden spots & tech gear 🎒',
        followerCount: 890,
      ),
      User(
        id: 'u_admin',
        name: 'Trell Admin',
        username: 'admin_portal',
        avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
        role: UserRole.admin,
        bio: 'Platform Moderator & Administrator',
      ),
    ];

    // 2. Seed Products (prices in paise, commission rates 5-15%)
    _products = [
      Product(
        id: 'p_1',
        name: 'Velvet Matte Lipstick - Ruby Red',
        imageUrl: 'https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=400',
        description: 'Long-lasting matte finish with hydrating jojoba oil. Vibrant color for evening looks.',
        category: 'Beauty',
        pricePaise: 79900, // ₹799
        commissionRate: 0.12, // 12%
      ),
      Product(
        id: 'p_2',
        name: 'Oversized Pastel Denim Jacket',
        imageUrl: 'https://images.unsplash.com/photo-1544441893-675973e31985?w=400',
        description: 'Trendy streetwear pastel blue oversized denim jacket. Premium cotton blend.',
        category: 'Fashion',
        pricePaise: 249900, // ₹2,499
        commissionRate: 0.10, // 10%
      ),
      Product(
        id: 'p_3',
        name: 'Waterproof Travel Duffle Bag 45L',
        imageUrl: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
        description: 'Durable nylon duffle bag with shoe compartment & USB port for weekender trips.',
        category: 'Travel',
        pricePaise: 189900, // ₹1,899
        commissionRate: 0.15, // 15%
      ),
      Product(
        id: 'p_4',
        name: 'Organic Matcha Green Tea Powder',
        imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=400',
        description: '100% Ceremonial grade Japanese matcha green tea. Rich in antioxidants.',
        category: 'Food',
        pricePaise: 99900, // ₹999
        commissionRate: 0.08, // 8%
      ),
      Product(
        id: 'p_5',
        name: 'Macrame Plant Hanger Craft Kit',
        imageUrl: 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=400',
        description: 'Complete DIY kit with natural cotton cord, wooden rings, and tutorial guide.',
        category: 'DIY',
        pricePaise: 64900, // ₹649
        commissionRate: 0.10, // 10%
      ),
    ];

    // 3. Seed Posts
    _posts = [
      Post(
        id: 'post_1',
        creatorId: 'u_creator1',
        creatorName: 'Priya Fashionista',
        creatorAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/fashion_trend.mp4',
        caption: '5 ways to style this cute pastel denim jacket! Which look is your fav? 💙 #FashionInspo',
        category: 'Fashion',
        taggedProductIds: ['p_2'],
        viewsCount: 1240,
        likedUserIds: ['u_viewer'],
        comments: [
          Comment(
            id: 'c1',
            userId: 'u_viewer',
            userName: 'Aanya Sharma',
            text: 'Love look #3! Just ordered the jacket!',
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          ),
        ],
        sharesCount: 34,
        productClicksCount: 88,
        filterName: 'Vintage Warm',
        musicTitle: 'Lo-Fi Chill Beats',
        isPromoted: true,
        promotionExpiry: DateTime.now().add(const Duration(days: 4)),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Post(
        id: 'post_2',
        creatorId: 'u_creator1',
        creatorName: 'Priya Fashionista',
        creatorAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/beauty_routine.mp4',
        caption: 'My 5-minute morning glam routine featuring my favorite ruby red matte lipstick! 💄✨',
        category: 'Beauty',
        taggedProductIds: ['p_1'],
        viewsCount: 950,
        likedUserIds: [],
        comments: [],
        sharesCount: 18,
        productClicksCount: 45,
        filterName: 'Soft Glow',
        musicTitle: 'Upbeat Pop Vibes',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Post(
        id: 'post_3',
        creatorId: 'u_creator2',
        creatorName: 'Rohan Traveler',
        creatorAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        isVerifiedCreator: false,
        videoPath: 'assets/videos/travel_vlog.mp4',
        caption: 'Packing for a 3-day weekend trip to Goa with this ultimate waterproof duffle bag! 🌴✈️',
        category: 'Travel',
        taggedProductIds: ['p_3'],
        viewsCount: 2100,
        likedUserIds: ['u_viewer'],
        comments: [],
        sharesCount: 52,
        productClicksCount: 120,
        filterName: 'Vibrant Summer',
        musicTitle: 'Acoustic Travel',
        createdAt: DateTime.now().subtract(const Duration(hours: 18)),
      ),
      Post(
        id: 'post_4',
        creatorId: 'u_creator2',
        creatorName: 'Rohan Traveler',
        creatorAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        isVerifiedCreator: false,
        videoPath: 'assets/videos/food_recipe.mp4',
        caption: 'How to make authentic Iced Matcha Latte at home in 2 minutes! 🍵💚 #MatchaLove',
        category: 'Food',
        taggedProductIds: ['p_4'],
        viewsCount: 620,
        likedUserIds: [],
        comments: [],
        sharesCount: 12,
        productClicksCount: 29,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Post(
        id: 'post_5',
        creatorId: 'u_creator1',
        creatorName: 'Priya Fashionista',
        creatorAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        isVerifiedCreator: true,
        videoPath: 'assets/videos/diy_craft.mp4',
        caption: 'DIY Room Decor: Making beautiful boho macrame plant hangers step-by-step! 🌿🧶',
        category: 'DIY',
        taggedProductIds: ['p_5'],
        viewsCount: 430,
        likedUserIds: [],
        comments: [],
        sharesCount: 9,
        productClicksCount: 19,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];

    // 4. Seed Historical Orders & Commissions (Attributed to Priya for post_1)
    _orders = [
      Order(
        id: 'ord_demo_101',
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
        userAvatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
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
    await _saveList(_kKeyCommissions, _commissions.map((c) => c.toJson()).toList());
    await _saveList(_kKeyWithdrawals, _withdrawals.map((w) => w.toJson()).toList());
    await _saveList(_kKeyRevShares, _revShares.map((r) => r.toJson()).toList());
    await _saveList(_kKeyReviews, _reviews.map((r) => r.toJson()).toList());
    await _saveList(_kKeyVerifications, _verifications.map((v) => v.toJson()).toList());
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
    List<String> following = _prefs.getStringList('$_kKeyFollowsPrefix$currentUserId') ?? [];
    return following.contains(targetUserId);
  }

  @override
  Future<void> toggleFollowUser(String currentUserId, String targetUserId) async {
    List<String> following = _prefs.getStringList('$_kKeyFollowsPrefix$currentUserId') ?? [];
    User? targetUser = getUserById(targetUserId);
    if (targetUser == null) return;

    if (following.contains(targetUserId)) {
      following.remove(targetUserId);
      targetUser = targetUser.copyWith(followerCount: (targetUser.followerCount - 1).clamp(0, 999999));
    } else {
      following.add(targetUserId);
      targetUser = targetUser.copyWith(followerCount: targetUser.followerCount + 1);
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
      _posts[idx] = _posts[idx].copyWith(viewsCount: _posts[idx].viewsCount + 1);
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
  Future<void> addPostComment(String postId, String userId, String userName, String text) async {
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
      _posts[idx] = _posts[idx].copyWith(sharesCount: _posts[idx].sharesCount + 1);
      await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
    }
  }

  @override
  Future<void> recordProductClick(String postId, String productId, String userId) async {
    String key = 'trell_click_${userId}_${postId}_${productId}';
    int? lastClickTime = _prefs.getInt(key);
    int now = DateTime.now().millisecondsSinceEpoch;
    // 30 minute duplicate click prevention window
    if (lastClickTime != null && (now - lastClickTime) < 30 * 60 * 1000) {
      return;
    }

    int idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _posts[idx] = _posts[idx].copyWith(productClicksCount: _posts[idx].productClicksCount + 1);
      await _prefs.setInt(key, now);
      await _saveList(_kKeyPosts, _posts.map((p) => p.toJson()).toList());
    }
  }

  @override
  Future<void> promotePost(String postId, int durationDays) async {
    int idx = _posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      _posts[idx] = _posts[idx].copyWith(
        isPromoted: true,
        promotionExpiry: DateTime.now().add(Duration(days: durationDays)),
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
  Future<void> addToCart(String userId, Product product, String? creatorId, String? postId) async {
    List<CartItem> cart = getCart(userId);
    // Separate items by product, creator, AND post attribution
    int idx = cart.indexWhere((item) =>
        item.product.id == product.id &&
        item.referrerCreatorId == creatorId &&
        item.referrerPostId == postId);

    if (idx != -1) {
      cart[idx] = cart[idx].copyWith(quantity: cart[idx].quantity + 1);
    } else {
      cart.add(CartItem(
        product: product,
        quantity: 1,
        referrerCreatorId: creatorId,
        referrerPostId: postId,
      ));
    }
    await _saveCart(userId, cart);
  }

  @override
  Future<void> updateCartQuantity(String userId, String productId, String? creatorId, String? postId, int quantity) async {
    List<CartItem> cart = getCart(userId);
    int idx = cart.indexWhere((item) =>
        item.product.id == productId &&
        item.referrerCreatorId == creatorId &&
        item.referrerPostId == postId);
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
  Future<void> removeFromCart(String userId, String productId, String? creatorId, String? postId) async {
    List<CartItem> cart = getCart(userId);
    cart.removeWhere((item) =>
        item.product.id == productId &&
        item.referrerCreatorId == creatorId &&
        item.referrerPostId == postId);
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
  }) async {
    int totalPaise = items.fold(0, (sum, item) => sum + item.totalPaise);
    OrderStatus status = simulateSuccess ? OrderStatus.paid : OrderStatus.cancelled;

    List<OrderItem> orderItems = items.map((cartItem) {
      return OrderItem(
        productId: cartItem.product.id,
        productName: cartItem.product.name,
        pricePaise: cartItem.product.pricePaise,
        quantity: cartItem.quantity,
        referrerCreatorId: cartItem.referrerCreatorId,
        referrerPostId: cartItem.referrerPostId,
        commissionRate: cartItem.product.commissionRate,
      );
    }).toList();

    Order newOrder = Order(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
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
      // Create Pending Commission for each attributed item
      for (var item in orderItems) {
        if (item.referrerCreatorId != null && item.referrerCreatorId!.isNotEmpty) {
          int commAmount = item.calculatedCommissionPaise;
          CommissionTransaction comm = CommissionTransaction(
            id: 'comm_${DateTime.now().millisecondsSinceEpoch}_${item.productId}',
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
      await clearCart(buyerUserId);
    }

    await _saveAll();
    return newOrder;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    int idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return;

    Order oldOrder = _orders[idx];
    if (oldOrder.status == newStatus) return; // Avoid double processing

    _orders[idx] = oldOrder.copyWith(status: newStatus);

    if (newStatus == OrderStatus.completed) {
      // Transition pending commissions to available
      for (int i = 0; i < _commissions.length; i++) {
        if (_commissions[i].orderId == orderId && _commissions[i].status == CommissionStatus.pending) {
          _commissions[i] = _commissions[i].copyWith(status: CommissionStatus.available);
        }
      }
    } else if (newStatus == OrderStatus.cancelled || newStatus == OrderStatus.refunded) {
      // Reverse commissions
      for (int i = 0; i < _commissions.length; i++) {
        if (_commissions[i].orderId == orderId && _commissions[i].status != CommissionStatus.reversed) {
          _commissions[i] = _commissions[i].copyWith(status: CommissionStatus.reversed);
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
  List<WithdrawalRequest> getWithdrawalRequests() => List.unmodifiable(_withdrawals);

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

    // 1. Calculate available balance
    int totalAvailable = _commissions
        .where((c) => c.creatorId == creatorId && c.status == CommissionStatus.available)
        .fold(0, (sum, c) => sum + c.amountPaise);

    // Subtract existing pending withdrawals
    int pendingWithdrawals = _withdrawals
        .where((w) => w.creatorId == creatorId && w.status == WithdrawalStatus.pending)
        .fold(0, (sum, w) => sum + w.amountPaise);

    int netAvailable = totalAvailable - pendingWithdrawals;
    if (amountPaise > netAvailable) {
      return null; // Insufficient funds
    }

    WithdrawalRequest req = WithdrawalRequest(
      id: 'wdr_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: creatorId,
      creatorName: creatorName,
      amountPaise: amountPaise,
      upiIdOrBank: upiIdOrBank,
      status: WithdrawalStatus.pending,
      requestedAt: DateTime.now(),
    );

    _withdrawals.insert(0, req);
    await _saveList(_kKeyWithdrawals, _withdrawals.map((w) => w.toJson()).toList());
    return req;
  }

  @override
  Future<void> processWithdrawal(String requestId, bool approve, {String? reason}) async {
    int idx = _withdrawals.indexWhere((w) => w.id == requestId);
    if (idx == -1) return;

    WithdrawalRequest req = _withdrawals[idx];
    if (req.status != WithdrawalStatus.pending) return;

    WithdrawalStatus newStatus = approve ? WithdrawalStatus.approved : WithdrawalStatus.rejected;

    if (approve) {
      // Re-check available funds before payout completion
      int totalAvailable = _commissions
          .where((c) => c.creatorId == req.creatorId && c.status == CommissionStatus.available)
          .fold(0, (sum, c) => sum + c.amountPaise);
      if (totalAvailable < req.amountPaise) {
        // Underfunded payout request - reject
        _withdrawals[idx] = req.copyWith(
          status: WithdrawalStatus.rejected,
          processedAt: DateTime.now(),
          rejectionReason: 'Underfunded account at time of approval',
        );
        await _saveAll();
        return;
      }

      // Deduct from available commissions by consuming available commission pool as paidOut
      int remainingDeduction = req.amountPaise;
      for (int i = 0; i < _commissions.length; i++) {
        if (_commissions[i].creatorId == req.creatorId && _commissions[i].status == CommissionStatus.available) {
          if (_commissions[i].amountPaise <= remainingDeduction) {
            remainingDeduction -= _commissions[i].amountPaise;
            _commissions[i] = _commissions[i].copyWith(status: CommissionStatus.paidOut); // Marked as paid out
          } else {
            // Split transaction if partial
            int leftover = _commissions[i].amountPaise - remainingDeduction;
            _commissions[i] = _commissions[i].copyWith(status: CommissionStatus.paidOut);
            _commissions.add(CommissionTransaction(
              id: 'comm_split_${DateTime.now().millisecondsSinceEpoch}',
              creatorId: req.creatorId,
              orderId: _commissions[i].orderId,
              productId: _commissions[i].productId,
              amountPaise: leftover,
              status: CommissionStatus.available,
              createdAt: _commissions[i].createdAt,
            ));
            remainingDeduction = 0;
            break;
          }
          if (remainingDeduction <= 0) break;
        }
      }
    }

    _withdrawals[idx] = req.copyWith(
      status: newStatus,
      processedAt: DateTime.now(),
      rejectionReason: reason,
    );

    await _saveAll();
  }

  // --- Revenue Share ---
  @override
  List<RevenueShareRecord> getRevenueShareRecordsForCreator(String creatorId) {
    return _revShares.where((r) => r.creatorId == creatorId).toList();
  }

  @override
  Future<void> recordRevenueShare(String creatorId, int sourcePaise, double shareRate, String note) async {
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

  @override
  bool hasUserPurchasedProduct(String userId, String productId) {
    return _orders.any((order) =>
        order.buyerUserId == userId &&
        (order.status == OrderStatus.paid || order.status == OrderStatus.completed) &&
        order.items.any((item) => item.productId == productId));
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
    bool isVerified = hasUserPurchasedProduct(userId, productId);
    ProductReview rev = ProductReview(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      userId: userId,
      userName: userName,
      userAvatarUrl: avatarUrl,
      rating: rating,
      comment: comment,
      isVerifiedPurchase: isVerified,
      createdAt: DateTime.now(),
    );
    _reviews.insert(0, rev);
    await _saveList(_kKeyReviews, _reviews.map((r) => r.toJson()).toList());
  }

  @override
  List<VerificationApplication> getVerificationApplications() => List.unmodifiable(_verifications);

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
    VerificationApplication app = VerificationApplication(
      id: 'ver_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: creatorId,
      creatorName: creatorName,
      category: category,
      socialLink: socialLink,
      reason: reason,
      status: VerificationStatus.pending,
      submittedAt: DateTime.now(),
    );

    _verifications.removeWhere((v) => v.creatorId == creatorId);
    _verifications.insert(0, app);
    await _saveList(_kKeyVerifications, _verifications.map((v) => v.toJson()).toList());
  }

  @override
  Future<void> processVerification(String applicationId, bool approve) async {
    int idx = _verifications.indexWhere((v) => v.id == applicationId);
    if (idx == -1) return;

    VerificationApplication app = _verifications[idx];
    VerificationStatus newStatus = approve ? VerificationStatus.approved : VerificationStatus.rejected;
    _verifications[idx] = app.copyWith(status: newStatus);

    if (approve) {
      User? user = getUserById(app.creatorId);
      if (user != null) {
        await updateUser(user.copyWith(isVerifiedCreator: true));
      }
    }

    await _saveAll();
  }
}
