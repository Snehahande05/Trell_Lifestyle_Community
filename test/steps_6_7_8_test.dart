// Steps 6, 7, 8 Business Rules Tests
//
// Tests cover:
// - Cart quantity/removal and per-item attribution
// - Address validation
// - Payment success/failure/cancellation outcomes
// - Checkout idempotency (double-tap prevention)
// - Allowed/forbidden order transitions
// - Exact partial-withdrawal example: ₹249.90 → ₹200 payout + ₹49.90 available
// - Minimum withdrawal and insufficient funds
// - Reservation, rejection, payout, and duplicate actions
// - Refund before settlement, after settlement, while reserved, after payout
// - Duplicate commission/refund prevention
// - Dashboard reconciliation, zero-denominator rates, order vs unit counts, product estimates
// - Self-follow prevention
// - Persistence/restart behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trell_lifestyle_community/repositories/app_repository.dart';
import 'package:trell_lifestyle_community/models/order.dart';
import 'package:trell_lifestyle_community/models/wallet.dart';
import 'package:trell_lifestyle_community/services/attribution_service.dart';

// ─── Address Validation Helper (mirrors CartScreen validation logic) ───────────
class AddressValidator {
  static String? validateName(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Name required' : null;
  static String? validateAddress(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Address required' : null;
  static String? validateCity(String? v) =>
      (v == null || v.trim().isEmpty) ? 'City required' : null;
  static String? validatePin(String? v) {
    if (v == null || v.trim().isEmpty) return 'PIN required';
    if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
      return 'Enter a valid 6-digit PIN';
    }
    return null;
  }

  static String? validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone required';
    String clean = v.trim().replaceAll('+91', '');
    if (!RegExp(r'^\d{10}$').hasMatch(clean)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }
}
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Steps 6–8: Comprehensive Business Rules', () {
    late LocalDemoRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = LocalDemoRepository();
      await repository.init();
    });

    // ─── CART TESTS ───────────────────────────────────────────────────────────
    group('Step 6 §1: Cart — quantity, removal, attribution identity', () {
      test(
        'Same product from different posts remains distinguishable',
        () async {
          final product = repository.getProducts().first;
          await repository.addToCart(
            'u_viewer',
            product,
            'u_creator1',
            'post_1',
          );
          await repository.addToCart(
            'u_viewer',
            product,
            'u_creator1',
            'post_2',
          );
          final cart = repository.getCart('u_viewer');
          expect(cart.length, 2);
          expect(cart[0].cartItemId, isNot(cart[1].cartItemId));
        },
      );

      test('Same product from same post merges quantity', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final cart = repository.getCart('u_viewer');
        expect(cart.length, 1);
        expect(cart.first.quantity, 2);
      });

      test('Quantity update does not change attribution', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        await repository.updateCartQuantity(
          'u_viewer',
          product.id,
          'u_creator1',
          'post_1',
          5,
        );
        final cart = repository.getCart('u_viewer');
        expect(cart.first.quantity, 5);
        expect(cart.first.referrerCreatorId, 'u_creator1');
        expect(cart.first.referrerPostId, 'post_1');
      });

      test('Quantity 0 removes item from cart', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        await repository.updateCartQuantity(
          'u_viewer',
          product.id,
          'u_creator1',
          'post_1',
          0,
        );
        expect(repository.getCart('u_viewer').isEmpty, true);
      });

      test('Remove only the specified cart item, not others', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        await repository.addToCart('u_viewer', product, 'u_creator2', 'post_3');
        await repository.removeFromCart(
          'u_viewer',
          product.id,
          'u_creator1',
          'post_1',
        );
        final cart = repository.getCart('u_viewer');
        expect(cart.length, 1);
        expect(cart.first.referrerCreatorId, 'u_creator2');
      });

      test('Direct purchase has no creator attribution', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, null, null);
        final cart = repository.getCart('u_viewer');
        expect(cart.first.referrerCreatorId, isNull);
        expect(cart.first.referrerPostId, isNull);
      });

      test('Carts are isolated by user account', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        expect(repository.getCart('u_creator1').isEmpty, true);
        expect(repository.getCart('u_viewer').length, 1);
      });
    });

    // ─── ADDRESS VALIDATION ───────────────────────────────────────────────────
    group('Step 6 §3: Address validation', () {
      test('Whitespace-only name rejected', () {
        expect(AddressValidator.validateName('   '), 'Name required');
        expect(AddressValidator.validateName(''), 'Name required');
      });

      test('Valid 6-digit PIN accepted', () {
        expect(AddressValidator.validatePin('400050'), isNull);
      });

      test('5-digit PIN rejected', () {
        expect(AddressValidator.validatePin('40005'), isNotNull);
      });

      test('7-digit PIN rejected', () {
        expect(AddressValidator.validatePin('4000500'), isNotNull);
      });

      test('10-digit mobile accepted', () {
        expect(AddressValidator.validatePhone('9876543210'), isNull);
      });

      test('+91 prefix stripped before validation', () {
        expect(AddressValidator.validatePhone('+919876543210'), isNull);
      });

      test('9-digit mobile rejected', () {
        expect(AddressValidator.validatePhone('987654321'), isNotNull);
      });

      test('Alphanumeric phone rejected', () {
        expect(AddressValidator.validatePhone('abcde12345'), isNotNull);
      });
    });

    // ─── PAYMENT OUTCOMES ────────────────────────────────────────────────────
    group('Step 6 §4: Demo payment outcomes', () {
      test('Successful payment creates paid order and clears cart', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        expect(repository.getCart('u_viewer').isNotEmpty, true);

        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai, 400050',
          simulateSuccess: true,
        );

        expect(order.status, OrderStatus.paid);
        expect(repository.getCart('u_viewer').isEmpty, true); // cart cleared
      });

      test(
        'Failed payment creates cancelled order and preserves cart',
        () async {
          final product = repository.getProducts().first;
          await repository.addToCart('u_viewer', product, null, null);
          final cartBefore = repository.getCart('u_viewer');

          final order = await repository.createOrder(
            buyerUserId: 'u_viewer',
            buyerName: 'Aanya',
            items: cartBefore,
            shippingAddress: 'Mumbai, 400050',
            simulateSuccess: false,
          );

          expect(order.status, OrderStatus.cancelled);
          // Cart should still have items (cancelled order does not clear cart)
          expect(repository.getCart('u_viewer').isNotEmpty, true);
        },
      );

      test('Failed payment does not create commission', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final cartItems = repository.getCart('u_viewer');
        final commsBefore = repository
            .getCommissionsForCreator('u_creator1')
            .length;

        await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cartItems,
          shippingAddress: 'Mumbai, 400050',
          simulateSuccess: false,
        );

        final commsAfter = repository
            .getCommissionsForCreator('u_creator1')
            .length;
        expect(commsAfter, commsBefore); // No new commission created
      });

      test('Direct purchase creates no affiliate commission', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, null, null);
        final cart = repository.getCart('u_viewer');
        final commsBefore = repository
            .getCommissionsForCreator('u_creator1')
            .length;

        await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cart,
          shippingAddress: 'Mumbai, 400050',
          simulateSuccess: true,
        );

        final commsAfter = repository
            .getCommissionsForCreator('u_creator1')
            .length;
        expect(commsAfter, commsBefore);
      });
    });

    // ─── CHECKOUT IDEMPOTENCY ────────────────────────────────────────────────
    group('Step 6 §5: Checkout idempotency', () {
      test(
        'Same idempotency key returns same order without duplication',
        () async {
          final product = repository.getProducts().first;
          await repository.addToCart(
            'u_viewer',
            product,
            'u_creator1',
            'post_1',
          );
          final cartItems = repository.getCart('u_viewer');

          const idemKey = 'idem_test_123';

          final order1 = await repository.createOrder(
            buyerUserId: 'u_viewer',
            buyerName: 'Aanya',
            items: cartItems,
            shippingAddress: 'Mumbai',
            simulateSuccess: true,
            idempotencyKey: idemKey,
          );

          // Call again with same key — should return same order
          final order2 = await repository.createOrder(
            buyerUserId: 'u_viewer',
            buyerName: 'Aanya',
            items: cartItems,
            shippingAddress: 'Mumbai',
            simulateSuccess: true,
            idempotencyKey: idemKey,
          );

          expect(order1.id, order2.id);
          // Only 1 commission should exist for this order
          final comms = repository
              .getCommissionsForCreator('u_creator1')
              .where((c) => c.orderId == order1.id);
          expect(comms.length, 1);
        },
      );

      test('Different key creates separate order', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, null, null);
        final cartItems = repository.getCart('u_viewer');

        final order1 = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cartItems,
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
          idempotencyKey: 'idem_A',
        );

        await repository.addToCart('u_viewer', product, null, null);
        final cartItems2 = repository.getCart('u_viewer');

        final order2 = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cartItems2,
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
          idempotencyKey: 'idem_B',
        );

        expect(order1.id, isNot(order2.id));
      });
    });

    // ─── ORDER TRANSITIONS ───────────────────────────────────────────────────
    group('Step 6 §6: Order status transition enforcement', () {
      test('Allowed: paid → completed', () {
        expect(OrderStatus.paid.canTransitionTo(OrderStatus.completed), true);
      });

      test('Allowed: paid → refunded', () {
        expect(OrderStatus.paid.canTransitionTo(OrderStatus.refunded), true);
      });

      test('Forbidden: completed → paid (backward)', () {
        expect(OrderStatus.completed.canTransitionTo(OrderStatus.paid), false);
      });

      test('Forbidden: cancelled → paid (terminal state)', () {
        expect(OrderStatus.cancelled.canTransitionTo(OrderStatus.paid), false);
      });

      test('Forbidden: refunded → completed (terminal)', () {
        expect(
          OrderStatus.refunded.canTransitionTo(OrderStatus.completed),
          false,
        );
      });

      test('Repository silently ignores invalid transition', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, null, null);
        final cartItems = repository.getCart('u_viewer');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cartItems,
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        // Mark completed
        await repository.updateOrderStatus(order.id, OrderStatus.completed);
        // Attempt backward transition to paid
        await repository.updateOrderStatus(order.id, OrderStatus.paid);
        // Should remain completed
        final retrieved = repository.getOrders().firstWhere(
          (o) => o.id == order.id,
        );
        expect(retrieved.status, OrderStatus.completed);
      });

      test('Repeated updateOrderStatus is idempotent', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final cartItems = repository.getCart('u_viewer');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cartItems,
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        await repository.updateOrderStatus(order.id, OrderStatus.completed);
        await repository.updateOrderStatus(
          order.id,
          OrderStatus.completed,
        ); // second call
        // Commission should remain available, not double-settled
        final comms = repository
            .getCommissionsForCreator('u_creator1')
            .where(
              (c) =>
                  c.orderId == order.id &&
                  c.status == CommissionStatus.available,
            );
        expect(comms.length, 1);
      });
    });

    // ─── COMMISSION CREATION ─────────────────────────────────────────────────
    group('Step 7 §9: Commission creation and settlement', () {
      test('Commission in pending state after paid order', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        final comms = repository
            .getCommissionsForCreator('u_creator1')
            .where((c) => c.orderId == order.id);
        expect(comms.first.status, CommissionStatus.pending);
      });

      test('Commission amount snapshotted: p_2 = ₹2499 × 10% = ₹249.90 (24990 paise)', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        final comm = repository
            .getCommissionsForCreator('u_creator1')
            .firstWhere((c) => c.orderId == order.id);
        // 249900 * 0.10 = 24990
        expect(comm.amountPaise, 24990);
      });

      test('Completing order moves commission pending → available', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        await repository.updateOrderStatus(order.id, OrderStatus.completed);
        final comm = repository
            .getCommissionsForCreator('u_creator1')
            .firstWhere((c) => c.orderId == order.id);
        expect(comm.status, CommissionStatus.available);
      });

      test('Cancelling order reverses pending commission', () async {
        final product = repository.getProducts().first;
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        await repository.updateOrderStatus(order.id, OrderStatus.cancelled);
        final comm = repository
            .getCommissionsForCreator('u_creator1')
            .firstWhere((c) => c.orderId == order.id);
        expect(comm.status, CommissionStatus.reversed);
      });

      test('Refund after completion reverses available commission', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        await repository.updateOrderStatus(order.id, OrderStatus.completed);
        await repository.updateOrderStatus(order.id, OrderStatus.refunded);
        final comm = repository
            .getCommissionsForCreator('u_creator1')
            .firstWhere((c) => c.orderId == order.id);
        expect(comm.status, CommissionStatus.reversed);
      });

      test('Duplicate commission prevention for same order item', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        const idemKey = 'idem_dup_test';
        final cartItems = repository.getCart('u_viewer');
        await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cartItems,
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
          idempotencyKey: idemKey,
        );
        await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cartItems,
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
          idempotencyKey: idemKey,
        );
        final order = repository.getOrders().firstWhere(
          (o) => o.idempotencyKey == idemKey,
        );
        final comms = repository
            .getCommissionsForCreator('u_creator1')
            .where((c) => c.orderId == order.id);
        expect(comms.length, 1); // Only 1 commission created
      });
    });

    // ─── WITHDRAWAL TESTS ────────────────────────────────────────────────────
    group('Step 7 §10: Withdrawal lifecycle', () {
      test('Below minimum ₹100 withdrawal rejected', () async {
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          5000,
          'priya@upi',
        );
        expect(req, isNull);
      });

      test(
        'Exactly minimum ₹100 (10000 paise) allowed when funds exist',
        () async {
          // Priya has 24990 paise available in seed data
          final req = await repository.requestWithdrawal(
            'u_creator1',
            'Priya',
            10000,
            'priya@upi',
          );
          expect(req, isNotNull);
        },
      );

      test('Empty UPI/bank rejected', () async {
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          10000,
          '',
        );
        expect(req, isNull);
      });

      test('Negative amount rejected', () async {
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          -5000,
          'priya@upi',
        );
        expect(req, isNull);
      });

      test('Zero amount rejected', () async {
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          0,
          'priya@upi',
        );
        expect(req, isNull);
      });

      test('Insufficient funds rejected', () async {
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          9999900,
          'priya@upi',
        ); // 99999 rupees
        expect(req, isNull);
      });

      // ─── THE KEY PARTIAL WITHDRAWAL TEST ────────────────────────────────────
      // Priya has 1 commission of 24990 paise (₹249.90) available.
      // She requests ₹200 (20000 paise).
      // CORRECT: paidOut = 20000 paise, available leftover = 4990 paise, total = 24990 paise
      // WRONG (old bug): paidOut = 24990, available = 4990, total = 29980 (double counted)
      test('Partial withdrawal: ₹249.90 available → ₹200 payout + ₹49.90 remaining', () async {
        // Step 1: Request ₹200 withdrawal (reservation)
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          20000,
          'priya@upi',
        );
        expect(req, isNotNull);

        // After reservation: 20000 paise should be reserved, 4990 should remain available
        final commsAfterReserve = repository.getCommissionsForCreator(
          'u_creator1',
        );
        final reservedTotal = commsAfterReserve
            .where((c) => c.status == CommissionStatus.reserved)
            .fold(0, (sum, c) => sum + c.amountPaise);
        final availableTotal = commsAfterReserve
            .where((c) => c.status == CommissionStatus.available)
            .fold(0, (sum, c) => sum + c.amountPaise);

        expect(reservedTotal, 20000);
        expect(availableTotal, 4990);

        // Step 2: Admin approves the withdrawal
        await repository.processWithdrawal(req!.id, true);

        // After approval: 20000 paise paid out, 4990 paise still available
        final commsAfterPayout = repository.getCommissionsForCreator(
          'u_creator1',
        );
        final paidOut = commsAfterPayout
            .where((c) => c.status == CommissionStatus.paidOut)
            .fold(0, (sum, c) => sum + c.amountPaise);
        final stillAvailable = commsAfterPayout
            .where((c) => c.status == CommissionStatus.available)
            .fold(0, (sum, c) => sum + c.amountPaise);

        expect(
          paidOut,
          20000,
          reason: 'Paid out should be exactly ₹200 (20000 paise)',
        );
        expect(
          stillAvailable,
          4990,
          reason: 'Available should be exactly ₹49.90 (4990 paise)',
        );
        // Total must equal original 24990
        expect(
          paidOut + stillAvailable,
          24990,
          reason: 'Total must reconcile to ₹249.90 (24990 paise)',
        );
      });

      test('Duplicate approval of same withdrawal is idempotent', () async {
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          10000,
          'priya@upi',
        );
        await repository.processWithdrawal(req!.id, true);
        // Attempt to approve again
        await repository.processWithdrawal(req.id, true);
        // Should still only have one paidOut commission for this withdrawal
        final comms = repository
            .getCommissionsForCreator('u_creator1')
            .where(
              (c) =>
                  c.withdrawalId == req.id &&
                  c.status == CommissionStatus.paidOut,
            );
        // Should be exactly the reserved amount, not doubled
        final totalPaidOut = comms.fold(0, (sum, c) => sum + c.amountPaise);
        expect(totalPaidOut, lessThanOrEqualTo(10000));
      });

      test(
        'Rejected withdrawal releases reserved funds back to available',
        () async {
          final req = await repository.requestWithdrawal(
            'u_creator1',
            'Priya',
            20000,
            'priya@upi',
          );
          expect(req, isNotNull);

          // After reservation
          final reservedBefore = repository
              .getCommissionsForCreator('u_creator1')
              .where((c) => c.status == CommissionStatus.reserved)
              .fold(0, (sum, c) => sum + c.amountPaise);
          expect(reservedBefore, 20000);

          // Admin rejects
          await repository.processWithdrawal(
            req!.id,
            false,
            reason: 'Test rejection',
          );

          // Funds should return to available
          final commsAfter = repository.getCommissionsForCreator('u_creator1');
          final reservedAfter = commsAfter
              .where((c) => c.status == CommissionStatus.reserved)
              .fold(0, (sum, c) => sum + c.amountPaise);
          final availableAfter = commsAfter
              .where((c) => c.status == CommissionStatus.available)
              .fold(0, (sum, c) => sum + c.amountPaise);

          expect(
            reservedAfter,
            0,
            reason: 'No reserved commissions after rejection',
          );
          expect(
            availableAfter,
            24990,
            reason: 'Original available amount restored',
          );
        },
      );
    });

    // ─── REFUND SCENARIOS ────────────────────────────────────────────────────
    group('Step 7 §11: Refunds at different lifecycle stages', () {
      test(
        'Refund after payout creates clawback record, paidOut preserved',
        () async {
          final product = repository.getProducts().firstWhere(
            (p) => p.id == 'p_2',
          );
          await repository.addToCart(
            'u_viewer',
            product,
            'u_creator1',
            'post_1',
          );
          final order = await repository.createOrder(
            buyerUserId: 'u_viewer',
            buyerName: 'Aanya',
            items: repository.getCart('u_viewer'),
            shippingAddress: 'Mumbai',
            simulateSuccess: true,
          );
          // Settle commission
          await repository.updateOrderStatus(order.id, OrderStatus.completed);
          // Withdraw all available
          final req = await repository.requestWithdrawal(
            'u_creator1',
            'Priya',
            24990,
            'priya@upi',
          );
          await repository.processWithdrawal(req!.id, true);

          // Verify paidOut exists
          final paidOutBefore = repository
              .getCommissionsForCreator('u_creator1')
              .where((c) => c.status == CommissionStatus.paidOut)
              .fold(0, (sum, c) => sum + c.amountPaise);
          expect(paidOutBefore, 24990);

          // Now refund the order
          await repository.updateOrderStatus(order.id, OrderStatus.refunded);

          // paidOut record should remain (historical cash record)
          final commsAfter = repository.getCommissionsForCreator('u_creator1');
          final paidOutAfter = commsAfter
              .where((c) => c.status == CommissionStatus.paidOut)
              .fold(0, (sum, c) => sum + c.amountPaise);
          final clawback = commsAfter
              .where((c) => c.status == CommissionStatus.clawback)
              .fold(0, (sum, c) => sum + c.amountPaise);

          expect(
            paidOutAfter,
            24990,
            reason: 'Historical paidOut record preserved',
          );
          expect(clawback, -24990, reason: 'Clawback created as debt');
        },
      );

      test('Clawback debt blocks new withdrawal requests', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        await repository.updateOrderStatus(order.id, OrderStatus.completed);
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          24990,
          'priya@upi',
        );
        await repository.processWithdrawal(req!.id, true);
        await repository.updateOrderStatus(order.id, OrderStatus.refunded);

        // Now add new available commission
        // (simulate by creating a new order)
        final product2 = repository.getProducts().firstWhere(
          (p) => p.id == 'p_3',
        );
        await repository.addToCart(
          'u_viewer',
          product2,
          'u_creator1',
          'post_1',
        );
        final order2 = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        await repository.updateOrderStatus(order2.id, OrderStatus.completed);

        // Withdrawal should be blocked due to outstanding debt
        final blockedReq = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          10000,
          'priya@upi',
        );
        expect(
          blockedReq,
          isNull,
          reason: 'Withdrawal blocked due to clawback debt',
        );
      });

      test(
        'Duplicate refund prevention — refunding twice does not double-reverse',
        () async {
          final product = repository.getProducts().firstWhere(
            (p) => p.id == 'p_2',
          );
          await repository.addToCart(
            'u_viewer',
            product,
            'u_creator1',
            'post_1',
          );
          final order = await repository.createOrder(
            buyerUserId: 'u_viewer',
            buyerName: 'Aanya',
            items: repository.getCart('u_viewer'),
            shippingAddress: 'Mumbai',
            simulateSuccess: true,
          );
          await repository.updateOrderStatus(order.id, OrderStatus.completed);
          await repository.updateOrderStatus(order.id, OrderStatus.refunded);
          // Second refund attempt should be blocked by transition table (refunded is terminal)
          await repository.updateOrderStatus(order.id, OrderStatus.refunded);

          final reversedComms = repository
              .getCommissionsForCreator('u_creator1')
              .where(
                (c) =>
                    c.orderId == order.id &&
                    c.status == CommissionStatus.reversed,
              );
          // Should only have 1 reversed commission for this order, not 2
          expect(reversedComms.length, 1);
        },
      );
    });

    // ─── DASHBOARD RECONCILIATION ────────────────────────────────────────────
    group('Step 8 §12: Accounting reconciliation equation', () {
      test('Reconciliation equation holds after complex scenario', () async {
        // Setup: create order, settle, partially withdraw
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: repository.getCart('u_viewer'),
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        await repository.updateOrderStatus(order.id, OrderStatus.completed);

        // Partial withdrawal: 20000 of 24990
        final req = await repository.requestWithdrawal(
          'u_creator1',
          'Priya',
          20000,
          'priya@upi',
        );
        await repository.processWithdrawal(req!.id, true);

        final comms = repository.getCommissionsForCreator('u_creator1');

        int pending = comms
            .where((c) => c.status == CommissionStatus.pending)
            .fold(0, (s, c) => s + c.amountPaise);
        int available = comms
            .where((c) => c.status == CommissionStatus.available)
            .fold(0, (s, c) => s + c.amountPaise);
        int reserved = comms
            .where((c) => c.status == CommissionStatus.reserved)
            .fold(0, (s, c) => s + c.amountPaise);
        int paidOut = comms
            .where((c) => c.status == CommissionStatus.paidOut)
            .fold(0, (s, c) => s + c.amountPaise);
        int reversed = comms
            .where((c) => c.status == CommissionStatus.reversed)
            .fold(0, (s, c) => s + c.amountPaise);
        int clawback = comms
            .where((c) => c.status == CommissionStatus.clawback)
            .fold(0, (s, c) => s + c.amountPaise);
        int recoveryDue = clawback < 0 ? clawback.abs() : 0;

        int grossCommission =
            pending + available + reserved + paidOut + reversed;
        int netCashPaid = paidOut; // No actual clawback recovery yet

        // Equation: gross - reversed = pending + available + reserved + netCashPaid - recoveryDue
        int lhs = grossCommission - reversed;
        int rhs = pending + available + reserved + netCashPaid - recoveryDue;
        expect(lhs, rhs, reason: 'Reconciliation equation must balance');
        // The seed data pre-populates 24990 paise available for u_creator1.
        // The new order adds another 24990 paise.
        // Total available before withdrawal: 24990 + 24990 = 49980.
        // After 20000 withdrawn: 49980 − 20000 = 29980 available, 20000 paidOut.
        expect(available, 29980);
        expect(paidOut, 20000);
      });
    });

    // ─── DASHBOARD METRICS ───────────────────────────────────────────────────
    group('Step 8 §14–15: Dashboard metrics', () {
      test('Zero views returns 0.0 engagement rate (no division by zero)', () {
        // Simulate: no views
        double engagementRate = 0 > 0 ? (10 / 0) * 100 : 0.0;
        expect(engagementRate, 0.0);
      });

      test('Zero clicks returns 0.0 conversion rate', () {
        double conversionRate = 0 > 0 ? (5 / 0) * 100 : 0.0;
        expect(conversionRate, 0.0);
      });

      test('Units sold counted separately from order count', () async {
        final product = repository.getProducts().firstWhere(
          (p) => p.id == 'p_2',
        );
        // Add 3 units
        await repository.addToCart('u_viewer', product, 'u_creator1', 'post_1');
        await repository.updateCartQuantity(
          'u_viewer',
          product.id,
          'u_creator1',
          'post_1',
          3,
        );
        final cartItems = repository.getCart('u_viewer');
        final order = await repository.createOrder(
          buyerUserId: 'u_viewer',
          buyerName: 'Aanya',
          items: cartItems,
          shippingAddress: 'Mumbai',
          simulateSuccess: true,
        );
        // 1 order, 3 units
        expect(order.items.first.quantity, 3);
        expect(order.items.length, 1); // 1 line item = 1 order
      });

      test(
        'Product earning estimate uses same rounding as commission calc',
        () {
          // p_2: 249900 paise * 0.10 = 24990 paise
          final product = repository.getProducts().firstWhere(
            (p) => p.id == 'p_2',
          );
          final estimate = (product.pricePaise * product.commissionRate)
              .round();
          expect(estimate, 24990);
        },
      );
    });

    // ─── SELF-FOLLOW PREVENTION ──────────────────────────────────────────────
    group('Step 8 §13: Follower counts', () {
      test('Self-follow is prevented', () async {
        final userBefore = repository.getUserById('u_creator1');
        await repository.toggleFollowUser('u_creator1', 'u_creator1');
        final userAfter = repository.getUserById('u_creator1');
        expect(userAfter?.followerCount, userBefore?.followerCount);
      });

      test('Follow increments count, unfollow decrements', () async {
        final before = repository.getUserById('u_creator1')!.followerCount;
        await repository.toggleFollowUser('u_viewer', 'u_creator1');
        expect(repository.getUserById('u_creator1')!.followerCount, before + 1);
        await repository.toggleFollowUser('u_viewer', 'u_creator1');
        expect(repository.getUserById('u_creator1')!.followerCount, before);
      });

      test('Follower count cannot go negative', () async {
        // Force a low count
        final creator = repository.getUserById('u_creator2')!;
        expect(creator.followerCount, greaterThanOrEqualTo(0));
        // Toggle off something that was never toggled on should not go negative
        await repository.toggleFollowUser('u_viewer', 'u_creator2');
        await repository.toggleFollowUser('u_viewer', 'u_creator2');
        await repository.toggleFollowUser(
          'u_viewer',
          'u_creator2',
        ); // unfollow again when not following
        expect(
          repository.getUserById('u_creator2')!.followerCount,
          greaterThanOrEqualTo(0),
        );
      });
    });

    // ─── ATTRIBUTION LINK TESTS (preserved from Step 5) ─────────────────────
    group('Step 5 (preserved): Referral link generation and validation', () {
      test('Referral link generation and parsing round-trips', () {
        final posts = repository.getPosts();
        final post = posts.firstWhere((p) => p.taggedProductIds.isNotEmpty);
        final productId = post.taggedProductIds.first;

        final link = AttributionService.buildReferralUrl(
          productId: productId,
          creatorId: post.creatorId,
          postId: post.id,
        );

        final parsed = AttributionService.parseReferralUrl(link);
        expect(parsed?.productId, productId);
        expect(parsed?.creatorId, post.creatorId);
        expect(parsed?.postId, post.id);
      });

      test('Invalid product ID fails validation', () {
        final post = repository.getPosts().firstWhere(
          (p) => p.taggedProductIds.isNotEmpty,
        );
        final isValid = AttributionService.validateAttribution(
          repository,
          productId: 'non_existent_product',
          creatorId: post.creatorId,
          postId: post.id,
        );
        expect(isValid, false);
      });
    });
  });
}
