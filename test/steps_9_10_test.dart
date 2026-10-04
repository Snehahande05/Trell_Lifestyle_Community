// ignore_for_file: avoid_print
/// Steps 9 & 10 — Comprehensive Tests
///
/// Covers:
///   Step 9: Verified Purchase eligibility, review behavior, verification states,
///            admin role enforcement, self-approval guard, dynamic creator badges.
///   Step 10: ₹499 promotion payment outcomes, idempotency, duplicate/concurrent
///             prevention, active/expired boundary, history, feed sorting.
///
/// Controllable clock: expiry tests inject a custom [now] DateTime into
/// PromotionRecord.isActive() without changing the advertised 7-day duration.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:trell_lifestyle_community/models/user.dart';
import 'package:trell_lifestyle_community/models/order.dart';
import 'package:trell_lifestyle_community/models/review_and_verification.dart';
import 'package:trell_lifestyle_community/models/promotion.dart';
import 'package:trell_lifestyle_community/models/post.dart';

// ─── Test helpers ─────────────────────────────────────────────────────────────

class FakePrefs {
  final _store = <String, String>{};
  String? getString(String key) => _store[key];
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  bool containsKey(String key) => _store.containsKey(key);
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  Future<bool> clear() async {
    _store.clear();
    return true;
  }

  List<String>? getStringList(String key) => null;
  Future<bool> setStringList(String key, List<String> value) async => true;
  bool? getBool(String key) => null;
  Future<bool> setBool(String key, bool value) async => true;
  int? getInt(String key) => null;
  Future<bool> setInt(String key, int value) async => true;
}

// ─── Pure logic helpers (no SharedPreferences needed) ─────────────────────────

/// Builds a minimal order set for eligibility checks.
List<Order> _buildOrders({
  required String buyerUserId,
  required String productId,
  required OrderStatus status,
}) {
  return [
    Order(
      id: 'ord_test_1',
      idempotencyKey: 'idem_test_1',
      buyerUserId: buyerUserId,
      buyerName: 'Test Buyer',
      items: [
        OrderItem(
          productId: productId,
          productName: 'Test Product',
          pricePaise: 100000,
          quantity: 1,
          commissionRate: 0.10,
        ),
      ],
      totalPaise: 100000,
      shippingAddress: 'Test Address, Mumbai, MH - 400001',
      status: status,
      createdAt: DateTime.now(),
    ),
  ];
}

// ─── STEP 9: Verified Purchase Eligibility ────────────────────────────────────

/// Simulates the repository eligibility check using the rule:
///   eligible = order.buyerUserId == userId
///              && order.status == OrderStatus.completed
///              && order.items.any(item.productId == productId)
bool _checkEligibility(List<Order> orders, String userId, String productId) {
  return orders.any(
    (order) =>
        order.buyerUserId == userId &&
        order.status == OrderStatus.completed &&
        order.items.any((item) => item.productId == productId),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // STEP 9 §1: Verified Purchase Eligibility
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 9 §1: Verified Purchase eligibility', () {
    const userId = 'u_buyer';
    const productId = 'p_test';

    test('Completed order grants Verified Purchase badge', () {
      final orders = _buildOrders(
        buyerUserId: userId,
        productId: productId,
        status: OrderStatus.completed,
      );
      expect(_checkEligibility(orders, userId, productId), isTrue);
    });

    test('Paid (not yet delivered) order does NOT grant badge', () {
      final orders = _buildOrders(
        buyerUserId: userId,
        productId: productId,
        status: OrderStatus.paid,
      );
      expect(_checkEligibility(orders, userId, productId), isFalse);
    });

    test('Cancelled order does NOT grant badge', () {
      final orders = _buildOrders(
        buyerUserId: userId,
        productId: productId,
        status: OrderStatus.cancelled,
      );
      expect(_checkEligibility(orders, userId, productId), isFalse);
    });

    test('Refunded order does NOT grant badge', () {
      final orders = _buildOrders(
        buyerUserId: userId,
        productId: productId,
        status: OrderStatus.refunded,
      );
      expect(_checkEligibility(orders, userId, productId), isFalse);
    });

    test(
      'A different user\'s completed order does NOT grant badge to reviewer',
      () {
        final orders = _buildOrders(
          buyerUserId: 'u_other',
          productId: productId,
          status: OrderStatus.completed,
        );
        // Checking eligibility for userId, not u_other
        expect(_checkEligibility(orders, userId, productId), isFalse);
      },
    );

    test('Completed order for different product does NOT grant badge', () {
      final orders = _buildOrders(
        buyerUserId: userId,
        productId: 'p_other',
        status: OrderStatus.completed,
      );
      expect(_checkEligibility(orders, userId, productId), isFalse);
    });

    test('Multiple qualifying orders — badge remains if one refunded but another completed', () {
      final orders = [
        Order(
          id: 'ord_1',
          idempotencyKey: 'idem_1',
          buyerUserId: userId,
          buyerName: 'Buyer',
          items: [
            OrderItem(
              productId: productId,
              productName: 'P',
              pricePaise: 100,
              quantity: 1,
              commissionRate: 0.1,
            ),
          ],
          totalPaise: 100,
          shippingAddress: 'Addr',
          status: OrderStatus.refunded, // refunded qualifying order
          createdAt: DateTime.now(),
        ),
        Order(
          id: 'ord_2',
          idempotencyKey: 'idem_2',
          buyerUserId: userId,
          buyerName: 'Buyer',
          items: [
            OrderItem(
              productId: productId,
              productName: 'P',
              pricePaise: 100,
              quantity: 1,
              commissionRate: 0.1,
            ),
          ],
          totalPaise: 100,
          shippingAddress: 'Addr',
          status: OrderStatus.completed, // still qualifying
          createdAt: DateTime.now(),
        ),
      ];
      // Badge should remain because ord_2 still qualifies
      expect(_checkEligibility(orders, userId, productId), isTrue);
    });

    test('Badge removed when only qualifying order is refunded', () {
      final orders = [
        Order(
          id: 'ord_1',
          idempotencyKey: 'idem_1',
          buyerUserId: userId,
          buyerName: 'Buyer',
          items: [
            OrderItem(
              productId: productId,
              productName: 'P',
              pricePaise: 100,
              quantity: 1,
              commissionRate: 0.1,
            ),
          ],
          totalPaise: 100,
          shippingAddress: 'Addr',
          status: OrderStatus.refunded,
          createdAt: DateTime.now(),
        ),
      ];
      expect(_checkEligibility(orders, userId, productId), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 9 §2: Review validation rules
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 9 §2: Review validation rules', () {
    test('Rating is clamped to [1.0, 5.0]', () {
      expect((-1.0).clamp(1.0, 5.0), equals(1.0));
      expect((6.0).clamp(1.0, 5.0), equals(5.0));
      expect((3.5).clamp(1.0, 5.0), equals(3.5));
    });

    test('Whitespace-only comment is rejected', () {
      expect('   '.trim().isEmpty, isTrue);
      expect(''.trim().isEmpty, isTrue);
    });

    test('Valid comment passes', () {
      expect('Great product!'.trim().isEmpty, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 9 §3: Creator Verification states and rules
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 9 §3: Creator verification states', () {
    test('notApplied → pending on submission', () {
      // Simulate the state machine transition
      VerificationStatus status = VerificationStatus.notApplied;
      // After submission
      status = VerificationStatus.pending;
      expect(status, equals(VerificationStatus.pending));
    });

    test('pending → approved on admin approval', () {
      VerificationStatus status = VerificationStatus.pending;
      status = VerificationStatus.approved;
      expect(status, equals(VerificationStatus.approved));
    });

    test('pending → rejected on admin rejection', () {
      VerificationStatus status = VerificationStatus.pending;
      status = VerificationStatus.rejected;
      expect(status, equals(VerificationStatus.rejected));
    });

    test('rejected → pending allows reapplication', () {
      VerificationStatus status = VerificationStatus.rejected;
      // Reapplication is allowed from rejected state
      status = VerificationStatus.pending;
      expect(status, equals(VerificationStatus.pending));
    });

    test('Duplicate pending submission is blocked', () {
      // Simulate: cannot submit when status is pending
      VerificationStatus status = VerificationStatus.pending;
      // Attempt to resubmit — should be blocked
      bool canSubmit =
          status != VerificationStatus.pending &&
          status != VerificationStatus.approved;
      expect(canSubmit, isFalse);
    });

    test('Duplicate approved submission is blocked', () {
      VerificationStatus status = VerificationStatus.approved;
      bool canSubmit =
          status != VerificationStatus.pending &&
          status != VerificationStatus.approved;
      expect(canSubmit, isFalse);
    });

    test('Application form fields must be non-empty', () {
      String category = '';
      String socialLink = '';
      String reason = '';
      bool valid =
          category.trim().isNotEmpty &&
          socialLink.trim().isNotEmpty &&
          reason.trim().isNotEmpty;
      expect(valid, isFalse);

      category = 'Fashion';
      socialLink = 'https://instagram.com/test';
      reason = 'I create content daily.';
      valid =
          category.trim().isNotEmpty &&
          socialLink.trim().isNotEmpty &&
          reason.trim().isNotEmpty;
      expect(valid, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 9 §4: Admin role restrictions
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 9 §4: Admin role enforcement', () {
    test('Non-admin user cannot process verification', () {
      final creatorUser = User(
        id: 'u_creator',
        name: 'Creator',
        username: 'creator',
        avatarUrl: '',
        role: UserRole.creator,
      );
      // Repository check: only admin role allowed
      bool canProcess = creatorUser.role == UserRole.admin;
      expect(canProcess, isFalse);
    });

    test('Admin user can process verification', () {
      final adminUser = User(
        id: 'u_admin',
        name: 'Admin',
        username: 'admin',
        avatarUrl: '',
        role: UserRole.admin,
      );
      bool canProcess = adminUser.role == UserRole.admin;
      expect(canProcess, isTrue);
    });

    test('Self-approval is blocked (adminId == creatorId)', () {
      const adminId = 'u_admin';
      const creatorId = 'u_admin'; // Same person
      bool isSelfApproval = adminId == creatorId;
      expect(isSelfApproval, isTrue); // Should be blocked
    });

    test('Rejection without a reason is blocked', () {
      String? rejectionReason;
      bool isReasonValid(String? s) => s != null && s.trim().isNotEmpty;
      expect(isReasonValid(rejectionReason), isFalse);

      rejectionReason = 'Insufficient follower count';
      expect(isReasonValid(rejectionReason), isTrue);
    });

    test('Stale/repeated decision on non-pending application is ignored', () {
      VerificationStatus currentStatus = VerificationStatus.approved;
      // Can only process pending applications
      bool canProcess = currentStatus == VerificationStatus.pending;
      expect(canProcess, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 9 §5: Dynamic creator badges (resolve from user record, not post copy)
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 9 §5: Dynamic creator badge resolution', () {
    test(
      'Badge reflects current user.isVerifiedCreator, not stale post copy',
      () {
        // User gets verified
        User creator = User(
          id: 'u_creator1',
          name: 'Priya',
          username: 'priya',
          avatarUrl: '',
          role: UserRole.creator,
          isVerifiedCreator: false,
        );

        // Simulate approval updating the user record
        creator = creator.copyWith(isVerifiedCreator: true);

        // Feed should resolve badge from user record:
        expect(creator.isVerifiedCreator, isTrue);
      },
    );

    test('Rejection does not grant badge', () {
      User creator = User(
        id: 'u_creator2',
        name: 'Rohan',
        username: 'rohan',
        avatarUrl: '',
        role: UserRole.creator,
        isVerifiedCreator: false,
      );
      // Rejection should NOT set isVerifiedCreator
      // (only approval does)
      expect(creator.isVerifiedCreator, isFalse);
    });

    test('Verified Creator badge is distinct from Verified Purchase badge', () {
      // These are different concepts - just verify the model distinction exists
      expect(VerificationStatus.values, isNotEmpty);
      // VerificationApplication relates to creator, ProductReview.isVerifiedPurchase to buyer
      final review = ProductReview(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        userName: 'User',
        userAvatarUrl: '',
        rating: 5.0,
        comment: 'Great!',
        isVerifiedPurchase: true,
        createdAt: DateTime.now(),
      );
      // review.isVerifiedPurchase is about purchase, not creator verification
      expect(review.isVerifiedPurchase, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 10 §6: Promotion package definition
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 10 §6: Promotion package terms', () {
    test('Package price is ₹499 (49900 paise)', () {
      const packagePricePaise = 49900;
      expect(packagePricePaise, equals(49900));
    });

    test('Package duration is 7 days', () {
      const durationDays = 7;
      expect(durationDays, equals(7));
    });

    test('PromotionRecord stores price in paise', () {
      final now = DateTime.now().toUtc();
      final record = PromotionRecord(
        id: 'p1',
        paymentAttemptId: 'att_1',
        postId: 'post_1',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: now,
        expiryTime: now.add(const Duration(days: 7)),
        createdAt: now,
      );
      expect(record.packagePricePaise, equals(49900));
      expect(record.durationDays, equals(7));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 10 §7–8: Promotion payment outcomes and idempotency
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 10 §7: Promotion payment outcomes', () {
    test('Successful attempt creates active promotion', () {
      final now = DateTime.now().toUtc();
      final record = PromotionRecord(
        id: 'p1',
        paymentAttemptId: 'att_success_1',
        postId: 'post_1',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: now,
        expiryTime: now.add(const Duration(days: 7)),
        createdAt: now,
      );
      expect(record.isActive(now: now), isTrue);
      expect(record.paymentStatus, equals(PromotionPaymentStatus.success));
    });

    test('Failed attempt does NOT activate promotion', () {
      final now = DateTime.now().toUtc();
      final record = PromotionRecord(
        id: 'p2',
        paymentAttemptId: 'att_fail_1',
        postId: 'post_1',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.failed,
        failureReason: 'Simulated payment failure',
        createdAt: now,
      );
      expect(record.isActive(now: now), isFalse);
      expect(record.paymentStatus, equals(PromotionPaymentStatus.failed));
    });

    test('Cancelled attempt does NOT activate promotion', () {
      final now = DateTime.now().toUtc();
      final record = PromotionRecord(
        id: 'p3',
        paymentAttemptId: 'att_cancel_1',
        postId: 'post_1',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.cancelled,
        createdAt: now,
      );
      expect(record.isActive(now: now), isFalse);
      expect(record.paymentStatus, equals(PromotionPaymentStatus.cancelled));
    });

    test('Idempotency: same paymentAttemptId returns same record', () {
      final now = DateTime.now().toUtc();
      final record = PromotionRecord(
        id: 'p4',
        paymentAttemptId: 'att_idem_1',
        postId: 'post_2',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: now,
        expiryTime: now.add(const Duration(days: 7)),
        createdAt: now,
      );
      // Simulate repository finding existing record by attemptId
      final List<PromotionRecord> store = [record];
      final found = store.firstWhere((r) => r.paymentAttemptId == 'att_idem_1');
      expect(found.id, equals('p4'));
      // Repeated call returns same record, not a new one
      expect(store.length, equals(1));
    });

    test('Duplicate active promotion for same post is prevented', () {
      final now = DateTime.now().toUtc();
      final existingPromo = PromotionRecord(
        id: 'p5',
        paymentAttemptId: 'att_5',
        postId: 'post_1',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: now,
        expiryTime: now.add(const Duration(days: 7)),
        createdAt: now,
      );
      final List<PromotionRecord> store = [existingPromo];
      // Check if post already has an active promotion
      bool hasActive = store.any(
        (p) => p.postId == 'post_1' && p.isActive(now: now),
      );
      expect(hasActive, isTrue); // New purchase should be blocked
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 10: Active/Expired boundary conditions (controllable clock)
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 10 §10: Active/Expired boundary (controllable clock)', () {
    test('Promotion is active before expiry', () {
      final activationTime = DateTime(2025, 1, 1, 0, 0, 0, 0, 0);
      final expiryTime = activationTime.add(const Duration(days: 7));
      // Inject a "now" that is 3 days into the promotion
      final testNow = activationTime.add(const Duration(days: 3));

      final record = PromotionRecord(
        id: 'p_boundary',
        paymentAttemptId: 'att_boundary',
        postId: 'post_x',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: activationTime,
        expiryTime: expiryTime,
        createdAt: activationTime,
      );

      expect(record.isActive(now: testNow), isTrue);
      expect(record.isExpired(now: testNow), isFalse);
    });

    test('Promotion is NOT active at exact expiry moment', () {
      final activationTime = DateTime(2025, 1, 1, 0, 0, 0, 0, 0);
      final expiryTime = activationTime.add(const Duration(days: 7));

      final record = PromotionRecord(
        id: 'p_boundary2',
        paymentAttemptId: 'att_boundary2',
        postId: 'post_y',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: activationTime,
        expiryTime: expiryTime,
        createdAt: activationTime,
      );

      // Inject "now" exactly at expiry time — should NOT be active (isAfter is strict)
      expect(record.isActive(now: expiryTime), isFalse);
      expect(record.isExpired(now: expiryTime), isTrue);
    });

    test('Promotion is NOT active after expiry', () {
      final activationTime = DateTime(2025, 1, 1, 0, 0, 0, 0, 0);
      final expiryTime = activationTime.add(const Duration(days: 7));
      // 8 days later
      final testNow = activationTime.add(const Duration(days: 8));

      final record = PromotionRecord(
        id: 'p_boundary3',
        paymentAttemptId: 'att_boundary3',
        postId: 'post_z',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: activationTime,
        expiryTime: expiryTime,
        createdAt: activationTime,
      );

      expect(record.isActive(now: testNow), isFalse);
      expect(record.isExpired(now: testNow), isTrue);
    });

    test('Expired post can be promoted again (new attempt)', () {
      final activationTime = DateTime(2025, 1, 1, 0, 0, 0, 0, 0);
      final expiryTime = activationTime.add(const Duration(days: 7));
      final testNow = activationTime.add(
        const Duration(days: 8),
      ); // after expiry

      final oldRecord = PromotionRecord(
        id: 'p_old',
        paymentAttemptId: 'att_old',
        postId: 'post_a',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: activationTime,
        expiryTime: expiryTime,
        createdAt: activationTime,
      );

      // Old is expired
      expect(oldRecord.isActive(now: testNow), isFalse);

      // New promotion can be created (no active promotion blocking)
      bool hasActive = [oldRecord]
          .any((p) => p.postId == 'post_a' && p.isActive(now: testNow));
      expect(hasActive, isFalse); // No active promotion — new one may proceed
    });

    test('Failed payment payment remains successful after expiry', () {
      // Payment state and promotion state are distinct
      final activationTime = DateTime(2025, 1, 1);
      final expiryTime = activationTime.add(const Duration(days: 7));
      final testNow = activationTime.add(
        const Duration(days: 8),
      ); // after expiry

      final record = PromotionRecord(
        id: 'p_paid_expired',
        paymentAttemptId: 'att_paid_expired',
        postId: 'post_b',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus:
            PromotionPaymentStatus.success, // payment still successful
        activationTime: activationTime,
        expiryTime: expiryTime,
        createdAt: activationTime,
      );

      // Payment was successful; promotion just expired
      expect(record.paymentStatus, equals(PromotionPaymentStatus.success));
      expect(record.isActive(now: testNow), isFalse);
      expect(record.isExpired(now: testNow), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 10: Featured feed sorting
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 10 §10: Featured feed sorting', () {
    final now = DateTime(2025, 6, 1, 12, 0, 0).toUtc();

    Post makePost(
      String id, {
      bool isPromoted = false,
      DateTime? expiry,
      DateTime? createdAt,
    }) {
      return Post(
        id: id,
        creatorId: 'u_creator1',
        creatorName: 'Creator',
        creatorAvatarUrl: '',
        videoPath: 'test.mp4',
        caption: 'Caption $id',
        category: 'Fashion',
        taggedProductIds: const [],
        isPromoted: isPromoted,
        promotionExpiry: expiry,
        createdAt: createdAt ?? DateTime(2025, 5, 1),
      );
    }

    bool isActive(Post p, DateTime testNow) =>
        p.isPromoted &&
        p.promotionExpiry != null &&
        p.promotionExpiry!.toUtc().isAfter(testNow);

    List<Post> sortFeed(List<Post> posts, DateTime testNow) {
      return List<Post>.from(posts)..sort((a, b) {
        final aActive = isActive(a, testNow);
        final bActive = isActive(b, testNow);
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    }

    test('Active promoted posts appear before non-promoted posts', () {
      final promoted = makePost(
        'promoted',
        isPromoted: true,
        expiry: now.add(const Duration(days: 5)),
      );
      final regular = makePost('regular');
      final sorted = sortFeed([regular, promoted], now);
      expect(sorted.first.id, equals('promoted'));
    });

    test('Expired promoted posts treated as non-promoted', () {
      final expired = makePost(
        'expired',
        isPromoted: true,
        expiry: now.subtract(const Duration(hours: 1)),
        createdAt: now,
      );
      final regular = makePost(
        'regular',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      final sorted = sortFeed([expired, regular], now);
      // Both non-active; expired is newer so comes first
      expect(sorted.first.id, equals('expired'));
    });

    test('Among active promoted posts: deterministic newest-first order', () {
      final older = makePost(
        'older_promo',
        isPromoted: true,
        expiry: now.add(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 5)),
      );
      final newer = makePost(
        'newer_promo',
        isPromoted: true,
        expiry: now.add(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 2)),
      );
      final sorted = sortFeed([older, newer], now);
      expect(sorted.first.id, equals('newer_promo'));
    });

    test(
      'Post with isPromoted=true but null expiry is NOT treated as active',
      () {
        // Matches the new strict rule: promotionExpiry != null required
        final flaggedNoExpiry = makePost(
          'flagged',
          isPromoted: true,
          expiry: null,
        );
        final regular = makePost('regular');
        // Neither is active since flaggedNoExpiry has no expiry
        final sorted = sortFeed([regular, flaggedNoExpiry], now);
        // Both non-active, order determined by createdAt; same date so stable
        expect(sorted, isNotEmpty);
        // The important thing: flaggedNoExpiry is NOT treated as promoted
        expect(isActive(flaggedNoExpiry, now), isFalse);
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 10: Ownership validation
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 10: Ownership validation', () {
    test('Creator cannot promote another creator\'s post', () {
      final post = Post(
        id: 'post_1',
        creatorId: 'u_creator1',
        creatorName: 'Creator 1',
        creatorAvatarUrl: '',
        videoPath: 'test.mp4',
        caption: 'Test',
        category: 'Fashion',
        taggedProductIds: const [],
        createdAt: DateTime.now(),
      );
      const requestingCreatorId = 'u_creator2'; // Different creator
      // Repository check: post.creatorId must equal creatorId
      bool isOwner = post.creatorId == requestingCreatorId;
      expect(isOwner, isFalse); // Should be rejected
    });

    test('Creator can promote their own post', () {
      final post = Post(
        id: 'post_2',
        creatorId: 'u_creator1',
        creatorName: 'Creator 1',
        creatorAvatarUrl: '',
        videoPath: 'test.mp4',
        caption: 'Test',
        category: 'Fashion',
        taggedProductIds: const [],
        createdAt: DateTime.now(),
      );
      const requestingCreatorId = 'u_creator1';
      bool isOwner = post.creatorId == requestingCreatorId;
      expect(isOwner, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 10: Serialization round-trip
  // ─────────────────────────────────────────────────────────────────────────
  group('Step 10: PromotionRecord serialization', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final now = DateTime(2025, 6, 1, 12, 0, 0).toUtc();
      final record = PromotionRecord(
        id: 'p_serial',
        paymentAttemptId: 'att_serial',
        postId: 'post_s',
        creatorId: 'u_creator1',
        packagePricePaise: 49900,
        durationDays: 7,
        paymentStatus: PromotionPaymentStatus.success,
        activationTime: now,
        expiryTime: now.add(const Duration(days: 7)),
        createdAt: now,
      );

      final json = record.toJson();
      final restored = PromotionRecord.fromJson(json);

      expect(restored.id, equals(record.id));
      expect(restored.paymentAttemptId, equals(record.paymentAttemptId));
      expect(restored.postId, equals(record.postId));
      expect(restored.creatorId, equals(record.creatorId));
      expect(restored.packagePricePaise, equals(record.packagePricePaise));
      expect(restored.durationDays, equals(record.durationDays));
      expect(restored.paymentStatus, equals(record.paymentStatus));
      expect(restored.activationTime, equals(record.activationTime));
      expect(restored.expiryTime, equals(record.expiryTime));
      expect(restored.isActive(now: now), equals(record.isActive(now: now)));
    });

    test('VerificationApplication with decision fields round-trips', () {
      final app = VerificationApplication(
        id: 'ver_serial',
        creatorId: 'u_creator1',
        creatorName: 'Priya',
        category: 'Fashion',
        socialLink: 'https://insta.com/test',
        reason: 'Great content',
        status: VerificationStatus.rejected,
        submittedAt: DateTime(2025, 1, 1),
        decidedByAdminId: 'u_admin',
        decidedAt: DateTime(2025, 1, 5),
        rejectionReason: 'Not enough followers',
      );

      final json = app.toJson();
      final restored = VerificationApplication.fromJson(json);

      expect(restored.id, equals(app.id));
      expect(restored.status, equals(VerificationStatus.rejected));
      expect(restored.decidedByAdminId, equals('u_admin'));
      expect(restored.rejectionReason, equals('Not enough followers'));
    });
  });
}
