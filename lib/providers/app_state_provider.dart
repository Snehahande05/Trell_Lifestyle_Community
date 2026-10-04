import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/post.dart';
import '../models/order.dart';
import '../models/wallet.dart';
import '../models/review_and_verification.dart';
import '../repositories/app_repository.dart';

class AppStateProvider extends ChangeNotifier {
  final AppRepositoryInterface repository;

  AppStateProvider({required this.repository});

  User? _currentUser;
  bool _isLoading = true;
  String _selectedCategory = 'All';

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await repository.init();
    List<User> users = repository.getUsers();
    if (users.isNotEmpty) {
      // Default to Viewer account (Aanya)
      _currentUser = users.firstWhere(
        (u) => u.role == UserRole.viewer,
        orElse: () => users.first,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  void switchDemoUser(String userId) {
    User? u = repository.getUserById(userId);
    if (u != null) {
      _currentUser = u;
      notifyListeners();
    }
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> resetDemoData() async {
    _isLoading = true;
    notifyListeners();
    await repository.resetDemoData();
    await init();
  }

  User? getUserById(String id) => repository.getUserById(id);

  // --- Data Getters ---
  List<User> get allUsers => repository.getUsers();

  List<Product> get allProducts => repository.getProducts();

  List<Post> get feedPosts {
    List<Post> posts = repository.getPosts();
    if (_selectedCategory != 'All') {
      posts = posts.where((p) => p.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }
    return posts;
  }

  List<CartItem> get userCart =>
      _currentUser != null ? repository.getCart(_currentUser!.id) : [];

  int get cartTotalPaise =>
      userCart.fold(0, (sum, item) => sum + item.totalPaise);

  int get cartItemCount =>
      userCart.fold(0, (sum, item) => sum + item.quantity);

  List<Order> get userOrders =>
      _currentUser != null ? repository.getOrdersForUser(_currentUser!.id) : [];

  List<Order> get allOrders => repository.getOrders();

  // --- Actions ---
  Future<void> toggleFollow(String targetUserId) async {
    if (_currentUser == null) return;
    await repository.toggleFollowUser(_currentUser!.id, targetUserId);
    // Refresh current user object if updating self/following
    _currentUser = repository.getUserById(_currentUser!.id);
    notifyListeners();
  }

  bool isFollowing(String targetUserId) {
    if (_currentUser == null) return false;
    return repository.isFollowing(_currentUser!.id, targetUserId);
  }

  Future<void> addPost(Post post) async {
    await repository.addPost(post);
    notifyListeners();
  }

  Future<void> registerPostView(String postId) async {
    if (_currentUser == null) return;
    bool incremented = await repository.incrementPostViews(postId, _currentUser!.id);
    if (incremented) {
      notifyListeners();
    }
  }

  Future<void> togglePostLike(String postId) async {
    if (_currentUser == null) return;
    await repository.togglePostLike(postId, _currentUser!.id);
    notifyListeners();
  }

  Future<void> addComment(String postId, String commentText) async {
    if (_currentUser == null || commentText.trim().isEmpty) return;
    await repository.addPostComment(
      postId,
      _currentUser!.id,
      _currentUser!.name,
      commentText.trim(),
    );
    notifyListeners();
  }

  Future<void> incrementShare(String postId) async {
    await repository.incrementPostShares(postId);
    notifyListeners();
  }

  Future<void> recordProductClick(String postId, String productId) async {
    if (_currentUser == null) return;
    await repository.recordProductClick(postId, productId, _currentUser!.id);
    notifyListeners();
  }

  Future<void> addToCart(Product product, {String? creatorId, String? postId}) async {
    if (_currentUser == null) return;
    await repository.addToCart(_currentUser!.id, product, creatorId, postId);
    notifyListeners();
  }

  Future<void> updateCartQuantity(String productId, String? creatorId, String? postId, int quantity) async {
    if (_currentUser == null) return;
    await repository.updateCartQuantity(_currentUser!.id, productId, creatorId, postId, quantity);
    notifyListeners();
  }

  Future<void> removeFromCart(String productId, String? creatorId, String? postId) async {
    if (_currentUser == null) return;
    await repository.removeFromCart(_currentUser!.id, productId, creatorId, postId);
    notifyListeners();
  }

  Future<Order?> checkout({
    required String shippingAddress,
    required bool simulateSuccess,
  }) async {
    if (_currentUser == null || userCart.isEmpty) return null;
    Order order = await repository.createOrder(
      buyerUserId: _currentUser!.id,
      buyerName: _currentUser!.name,
      items: List.from(userCart),
      shippingAddress: shippingAddress,
      simulateSuccess: simulateSuccess,
    );
    notifyListeners();
    return order;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await repository.updateOrderStatus(orderId, status);
    notifyListeners();
  }

  // Creator Analytics Calculations (Section 8 & 9)
  Map<String, dynamic> getCreatorAnalytics(String creatorId) {
    List<Post> creatorPosts = repository.getPosts().where((p) => p.creatorId == creatorId).toList();
    User? creatorUser = repository.getUserById(creatorId);

    int totalViews = creatorPosts.fold(0, (sum, p) => sum + p.viewsCount);
    int totalLikes = creatorPosts.fold(0, (sum, p) => sum + p.likedUserIds.length);
    int totalComments = creatorPosts.fold(0, (sum, p) => sum + p.comments.length);
    int totalShares = creatorPosts.fold(0, (sum, p) => sum + p.sharesCount);
    int totalClicks = creatorPosts.fold(0, (sum, p) => sum + p.productClicksCount);

    // Attributed orders & conversion calculations
    List<Order> allOrders = repository.getOrders();
    int unitsSold = 0;
    int attributedConversions = 0;
    int salesValuePaise = 0;

    for (var order in allOrders) {
      if (order.status == OrderStatus.paid || order.status == OrderStatus.completed) {
        bool orderHasCreatorItem = false;
        for (var item in order.items) {
          if (item.referrerCreatorId == creatorId) {
            orderHasCreatorItem = true;
            unitsSold += item.quantity;
            salesValuePaise += item.totalPaise;
          }
        }
        if (orderHasCreatorItem) {
          attributedConversions += 1;
        }
      }
    }

    // Engagement Rate = (likes + comments + shares) / views * 100
    double engagementRate = totalViews > 0
        ? ((totalLikes + totalComments + totalShares) / totalViews) * 100
        : 0.0;

    // Conversion Rate = attributed converted referral interactions / total clicks * 100
    double conversionRate = totalClicks > 0
        ? (attributedConversions / totalClicks) * 100
        : 0.0;

    // Financial Ledger Accounting
    List<CommissionTransaction> comms = repository.getCommissionsForCreator(creatorId);
    int pendingCommissionPaise = comms
        .where((c) => c.status == CommissionStatus.pending)
        .fold(0, (sum, c) => sum + c.amountPaise);
    int availableCommissionPaise = comms
        .where((c) => c.status == CommissionStatus.available)
        .fold(0, (sum, c) => sum + c.amountPaise);
    int reservedCommissionPaise = comms
        .where((c) => c.status == CommissionStatus.reserved)
        .fold(0, (sum, c) => sum + c.amountPaise);
    int paidOutCommissionPaise = comms
        .where((c) => c.status == CommissionStatus.paidOut)
        .fold(0, (sum, c) => sum + c.amountPaise);

    int pendingWithdrawalReservations = repository.getWithdrawalRequestsForCreator(creatorId)
        .where((w) => w.status == WithdrawalStatus.pending)
        .fold(0, (sum, w) => sum + w.amountPaise);

    int spendableBalancePaise = availableCommissionPaise - pendingWithdrawalReservations;
    int lifetimeEarningsPaise = availableCommissionPaise + reservedCommissionPaise + paidOutCommissionPaise;

    return {
      'followers': creatorUser?.followerCount ?? 0,
      'publishedPosts': creatorPosts.length,
      'views': totalViews,
      'likes': totalLikes,
      'comments': totalComments,
      'shares': totalShares,
      'clicks': totalClicks,
      'attributedConversions': attributedConversions,
      'unitsSold': unitsSold,
      'salesValuePaise': salesValuePaise,
      'pendingCommissionPaise': pendingCommissionPaise,
      'availableCommissionPaise': availableCommissionPaise,
      'spendableBalancePaise': spendableBalancePaise,
      'paidOutCommissionPaise': paidOutCommissionPaise,
      'lifetimeEarningsPaise': lifetimeEarningsPaise,
      'engagementRate': engagementRate,
      'conversionRate': conversionRate,
    };
  }

  // Wallet
  List<CommissionTransaction> get currentCreatorCommissions =>
      _currentUser != null ? repository.getCommissionsForCreator(_currentUser!.id) : [];

  List<WithdrawalRequest> get currentCreatorWithdrawals =>
      _currentUser != null ? repository.getWithdrawalRequestsForCreator(_currentUser!.id) : [];

  List<WithdrawalRequest> get allWithdrawalRequests => repository.getWithdrawalRequests();

  Future<WithdrawalRequest?> requestWithdrawal(int amountPaise, String upiOrBank) async {
    if (_currentUser == null) return null;
    WithdrawalRequest? req = await repository.requestWithdrawal(
      _currentUser!.id,
      _currentUser!.name,
      amountPaise,
      upiOrBank,
    );
    notifyListeners();
    return req;
  }

  Future<void> processWithdrawal(String requestId, bool approve, {String? reason}) async {
    await repository.processWithdrawal(requestId, approve, reason: reason);
    notifyListeners();
  }

  // Revenue Share
  List<RevenueShareRecord> get currentCreatorRevShares =>
      _currentUser != null ? repository.getRevenueShareRecordsForCreator(_currentUser!.id) : [];

  Future<void> recordRevenueShare(String creatorId, int sourcePaise, double rate, String note) async {
    await repository.recordRevenueShare(creatorId, sourcePaise, rate, note);
    notifyListeners();
  }

  // Promotion
  Future<void> promotePost(String postId, int days) async {
    await repository.promotePost(postId, days);
    notifyListeners();
  }

  // Verification & Reviews
  List<ProductReview> getReviewsForProduct(String productId) =>
      repository.getReviewsForProduct(productId);

  Future<void> addProductReview(String productId, double rating, String comment) async {
    if (_currentUser == null) return;
    await repository.addProductReview(
      productId,
      _currentUser!.id,
      _currentUser!.name,
      _currentUser!.avatarUrl,
      rating,
      comment,
    );
    notifyListeners();
  }

  VerificationApplication? get currentCreatorVerification =>
      _currentUser != null ? repository.getVerificationForCreator(_currentUser!.id) : null;

  List<VerificationApplication> get allVerificationApplications =>
      repository.getVerificationApplications();

  Future<void> submitVerification(String category, String socialLink, String reason) async {
    if (_currentUser == null) return;
    await repository.submitVerification(
      _currentUser!.id,
      _currentUser!.name,
      category,
      socialLink,
      reason,
    );
    notifyListeners();
  }

  Future<void> processVerification(String appId, bool approve) async {
    await repository.processVerification(appId, approve);
    notifyListeners();
  }
}
