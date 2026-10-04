import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trell_lifestyle_community/repositories/app_repository.dart';
import 'package:trell_lifestyle_community/models/order.dart';
import 'package:trell_lifestyle_community/models/wallet.dart';
import 'package:trell_lifestyle_community/services/attribution_service.dart';
import 'package:trell_lifestyle_community/models/post.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trell Lifestyle Community - Comprehensive Business Rules Verification Tests', () {
    late LocalDemoRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = LocalDemoRepository();
      await repository.init();
    });

    test('Requirement 5: Affiliate Link Generation, Parsing, and Validation', () {
      final posts = repository.getPosts();
      final post = posts.firstWhere((p) => p.taggedProductIds.isNotEmpty);
      final productId = post.taggedProductIds.first;
      final creatorId = post.creatorId;

      // 1. Generate referral link
      final link = AttributionService.buildReferralUrl(
        productId: productId,
        creatorId: creatorId,
        postId: post.id,
      );

      expect(link.contains('productId=$productId'), true);
      expect(link.contains('creatorId=$creatorId'), true);
      expect(link.contains('postId=${post.id}'), true);

      // 2. Parse referral link
      final parsed = AttributionService.parseReferralUrl(link);
      expect(parsed, isNotNull);
      expect(parsed!.productId, productId);
      expect(parsed.creatorId, creatorId);
      expect(parsed.postId, post.id);

      // 3. Validate valid referral link
      final isValid = AttributionService.validateAttribution(
        repository,
        productId: productId,
        creatorId: creatorId,
        postId: post.id,
      );
      expect(isValid, true);

      // 4. Validate invalid referral link (non-existent product)
      final isInvalid = AttributionService.validateAttribution(
        repository,
        productId: 'non_existent_product',
        creatorId: creatorId,
        postId: post.id,
      );
      expect(isInvalid, false);
    });

    test('Requirement 6: Cart Item Identity matches Product ID + Creator ID + Post ID', () async {
      final products = repository.getProducts();
      final product = products.first;

      // Add same product twice from different posts
      await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
      await repository.addToCart('u_viewer', product, 'u_creator1', 'post_2');

      final cart = repository.getCart('u_viewer');
      expect(cart.length, 2);
      expect(cart[0].cartItemId != cart[1].cartItemId, true);

      // Update quantity of post_1 item
      await repository.updateCartQuantity('u_viewer', product.id, 'u_creator1', 'post_1', 3);
      final updatedCart = repository.getCart('u_viewer');
      expect(updatedCart.firstWhere((i) => i.referrerPostId == 'post_1').quantity, 3);
      expect(updatedCart.firstWhere((i) => i.referrerPostId == 'post_2').quantity, 1);

      // Remove post_1 item only
      await repository.removeFromCart('u_viewer', product.id, 'u_creator1', 'post_1');
      final finalCart = repository.getCart('u_viewer');
      expect(finalCart.length, 1);
      expect(finalCart.first.referrerPostId, 'post_2');
    });

    test('Requirement 5 & 7: Commission Accounting Ledger & Organic Exclusions', () async {
      final products = repository.getProducts();
      final product = products.firstWhere((p) => p.id == 'p_2'); // ₹2499, 10% commission

      // 1. Organic purchase (no referrer creator)
      await repository.addToCart('u_viewer', product, null, null);
      final organicCart = repository.getCart('u_viewer');
      final organicOrder = await repository.createOrder(
        buyerUserId: 'u_viewer',
        buyerName: 'Aanya',
        items: organicCart,
        shippingAddress: 'Mumbai Address',
        simulateSuccess: true,
      );

      // Organic orders generate NO commission
      final commsAfterOrganic = repository.getCommissionsForCreator('u_creator1');
      final organicComm = commsAfterOrganic.where((c) => c.orderId == organicOrder.id);
      expect(organicComm.isEmpty, true);

      // 2. Attributed purchase
      await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
      final attrCart = repository.getCart('u_viewer');
      final attrOrder = await repository.createOrder(
        buyerUserId: 'u_viewer',
        buyerName: 'Aanya',
        items: attrCart,
        shippingAddress: 'Mumbai Address',
        simulateSuccess: true,
      );

      // Commission status is pending
      final commsAfterAttr = repository.getCommissionsForCreator('u_creator1');
      final attrComm = commsAfterAttr.firstWhere((c) => c.orderId == attrOrder.id);
      expect(attrComm.status, CommissionStatus.pending);
      expect(attrComm.amountPaise, 24990); // 10% of ₹2499 = ₹249.90

      // 3. Admin Order Completion moves pending to available
      await repository.updateOrderStatus(attrOrder.id, OrderStatus.completed);
      final commsCompleted = repository.getCommissionsForCreator('u_creator1');
      final completedComm = commsCompleted.firstWhere((c) => c.orderId == attrOrder.id);
      expect(completedComm.status, CommissionStatus.available);

      // 4. Admin Order Refund reverses eligible earnings
      await repository.updateOrderStatus(attrOrder.id, OrderStatus.refunded);
      final commsRefunded = repository.getCommissionsForCreator('u_creator1');
      final refundedComm = commsRefunded.firstWhere((c) => c.orderId == attrOrder.id);
      expect(refundedComm.status, CommissionStatus.reversed);
    });

    test('Requirement 8: Withdrawal Minimum Limit (₹100) & Balance Reservation', () async {
      // 1. Below minimum withdrawal attempt (< 10000 paise / ₹100)
      final lowReq = await repository.requestWithdrawal(
        'u_creator1',
        'Priya',
        5000, // ₹50
        'priya@upi',
      );
      expect(lowReq, isNull);

      // 2. Valid withdrawal attempt (Priya initial seed available balance is ₹249.90 = 24990 paise)
      final validReq = await repository.requestWithdrawal(
        'u_creator1',
        'Priya',
        15000, // ₹150
        'priya@upi',
      );
      expect(validReq, isNotNull);
      expect(validReq!.status, WithdrawalStatus.pending);

      // 3. Admin Process Payout sets consumed commissions to paidOut
      await repository.processWithdrawal(validReq.id, true);
      final comms = repository.getCommissionsForCreator('u_creator1');
      final paidComms = comms.where((c) => c.status == CommissionStatus.paidOut);
      expect(paidComms.isNotEmpty, true);
    });

    test('Requirement 10: Promotion 7-Day Package Expiry Logic', () async {
      final posts = repository.getPosts();
      final post = posts.first;

      await repository.promotePost(post.id, 7);

      final updatedPost = repository.getPosts().firstWhere((p) => p.id == post.id);
      expect(updatedPost.isPromoted, true);
      expect(updatedPost.promotionExpiry, isNotNull);
      expect(updatedPost.promotionExpiry!.isAfter(DateTime.now()), true);
    });

    test('Requirement 11 & 12: Verified Creator Revenue Share Capped at 30%', () async {
      // 1. Apply platform revenue share allocation (clamped to 30% max)
      await repository.recordRevenueShare(
        'u_creator1',
        100000, // ₹1000 source
        0.25, // 25%
        'Q3 Brand Sponsorship Platform Allocation',
      );

      final recs = repository.getRevenueShareRecordsForCreator('u_creator1');
      expect(recs.first.calculatedSharePaise, 25000); // ₹250

      // 2. Attempt invalid revenue share rate (> 30%) - verify clamping
      await repository.recordRevenueShare(
        'u_creator1',
        100000,
        0.35, // 35% -> clamped to 30%
        'Excessive Share Allocation',
      );

      final recsClamped = repository.getRevenueShareRecordsForCreator('u_creator1');
      expect(recsClamped.first.shareRate, 0.30); // Max 30% cap enforced
      expect(recsClamped.first.calculatedSharePaise, 30000);
    });

    test('Step 2: Video Trimming Validation Rules', () {
      double sourceDuration = 15.0;
      double trimStart = 2.0;
      double trimEnd = 8.0;

      // Validate 0 <= start < end <= source duration
      expect(trimStart >= 0, true);
      expect(trimStart < trimEnd, true);
      expect(trimEnd <= sourceDuration, true);

      double exportedDuration = trimEnd - trimStart;
      expect(exportedDuration, 6.0);
    });

    test('Step 2: Audio Settings & Royalty-Free Track Selection', () {
      final musicOptions = [
        'None',
        'Lo-Fi Chill Beats',
        'Upbeat Pop Vibes',
        'Acoustic Travel',
        'Bossa Nova Cafe'
      ];
      expect(musicOptions.contains('Lo-Fi Chill Beats'), true);

      double origAudioVol = 0.0; // Mute original audio
      double musicVol = 0.75; // 75% music volume

      expect(origAudioVol, 0.0);
      expect(musicVol, 0.75);
    });

    test('Step 2: Post Model Editing Metadata & Storage Persistence Compatibility', () async {
      final post = Post(
        id: 'post_edited_test',
        creatorId: 'u_creator1',
        creatorName: 'Priya Fashionista',
        creatorAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        videoPath: '/data/user/0/com.trell.lifestyle/app_flutter/trell_export_123.mp4',
        caption: 'Edited Video Post #Trell',
        category: 'Fashion',
        taggedProductIds: ['p_1'],
        filterName: 'Vintage Warm',
        musicTitle: 'Lo-Fi Chill Beats',
        musicVolume: 0.5,
        trimStartSeconds: 2.0,
        trimEndSeconds: 8.0,
        createdAt: DateTime.now(),
      );

      await repository.addPost(post);

      final retrieved = repository.getPostById('post_edited_test');
      expect(retrieved, isNotNull);
      expect(retrieved!.filterName, 'Vintage Warm');
      expect(retrieved.musicTitle, 'Lo-Fi Chill Beats');
      expect(retrieved.trimStartSeconds, 2.0);
      expect(retrieved.trimEndSeconds, 8.0);
      expect(retrieved.videoPath.contains('trell_export_'), true);
    });
  });
}
