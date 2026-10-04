// lib/models/order.dart
//
// Defines CartItem, OrderItem, OrderStatus and Order.
// All monetary values are stored as integer paise (minor units) to avoid
// floating-point drift.  The rounding rule used throughout the project is
// Dart's built-in .round() (round-half-to-even / "banker's rounding"), applied
// once at commission-creation time: (pricePaise * commissionRate).round().
//
// ORDER STATUS TRANSITION TABLE (enforced by canTransitionTo):
//   pending   → paid | cancelled
//   paid      → completed | refunded | cancelled
//   completed → refunded            (admin can still issue refund)
//   cancelled → (terminal)
//   refunded  → (terminal)

import 'dart:convert';
import 'product.dart';

// ─── CartItem ────────────────────────────────────────────────────────────────
// Represents one logical line in a user's cart.  The full cart identity is:
//   (product.id, referrerCreatorId, referrerPostId)
// Items with the same product but different creator/post are SEPARATE lines.

class CartItem {
  final String cartItemId;   // Unique within the cart for stable identity
  final Product product;     // Snapshot of product at add-time
  final int quantity;        // Positive integer
  final String? referrerCreatorId;
  final String? referrerPostId;

  CartItem({
    required this.cartItemId,
    required this.product,
    required this.quantity,
    this.referrerCreatorId,
    this.referrerPostId,
  });

  /// Subtotal in paise for this line
  int get totalPaise => product.pricePaise * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        cartItemId: cartItemId,
        product: product,
        quantity: quantity ?? this.quantity,
        referrerCreatorId: referrerCreatorId,
        referrerPostId: referrerPostId,
      );

  Map<String, dynamic> toJson() => {
        'cartItemId': cartItemId,
        'product': product.toJson(),
        'quantity': quantity,
        'referrerCreatorId': referrerCreatorId,
        'referrerPostId': referrerPostId,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        cartItemId: json['cartItemId'] as String,
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        quantity: json['quantity'] as int,
        referrerCreatorId: json['referrerCreatorId'] as String?,
        referrerPostId: json['referrerPostId'] as String?,
      );
}

// ─── OrderItem ───────────────────────────────────────────────────────────────
// Immutable snapshot of a cart line at the moment the order was placed.
// Later product-price or commission-rate changes do NOT affect this record.

class OrderItem {
  final String productId;
  final String productName;
  final int pricePaise;          // Snapshot of price at purchase time
  final int quantity;
  final String? referrerCreatorId;
  final String? referrerPostId;
  final double commissionRate;   // Clamped to 0.05–0.15 at order creation

  OrderItem({
    required this.productId,
    required this.productName,
    required this.pricePaise,
    required this.quantity,
    this.referrerCreatorId,
    this.referrerPostId,
    required this.commissionRate,
  });

  /// Subtotal for this line
  int get totalPaise => pricePaise * quantity;

  /// Commission owed to the creator for this line.
  /// Uses .round() (round-half-to-even) — consistent with all other commission calc.
  int get calculatedCommissionPaise => (totalPaise * commissionRate).round();

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'pricePaise': pricePaise,
        'quantity': quantity,
        'referrerCreatorId': referrerCreatorId,
        'referrerPostId': referrerPostId,
        'commissionRate': commissionRate,
      };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['productId'] as String,
        productName: json['productName'] as String,
        pricePaise: json['pricePaise'] as int,
        quantity: json['quantity'] as int,
        referrerCreatorId: json['referrerCreatorId'] as String?,
        referrerPostId: json['referrerPostId'] as String?,
        commissionRate: (json['commissionRate'] as num).toDouble(),
      );
}

// ─── OrderStatus ─────────────────────────────────────────────────────────────

enum OrderStatus {
  pending,   // Order created but not yet paid
  paid,      // Demo payment succeeded; awaiting fulfilment
  completed, // Admin marked as delivered / fulfilled
  cancelled, // Payment failed or explicitly cancelled (terminal)
  refunded,  // Whole-order refund issued (terminal)
}

extension OrderStatusExtension on OrderStatus {
  /// Allowed transition table.
  /// Only admin may drive most transitions.
  /// Enforced here AND in [LocalDemoRepository.updateOrderStatus].
  bool canTransitionTo(OrderStatus next) {
    switch (this) {
      case OrderStatus.pending:
        return next == OrderStatus.paid || next == OrderStatus.cancelled;
      case OrderStatus.paid:
        return next == OrderStatus.completed ||
            next == OrderStatus.cancelled ||
            next == OrderStatus.refunded;
      case OrderStatus.completed:
        return next == OrderStatus.refunded;
      case OrderStatus.cancelled:
        return false; // terminal
      case OrderStatus.refunded:
        return false; // terminal
    }
  }

  static OrderStatus fromString(String s) =>
      OrderStatus.values.firstWhere((e) => e.name == s,
          orElse: () => OrderStatus.pending);
}

// ─── Order ───────────────────────────────────────────────────────────────────
// Immutable after creation.

class Order {
  final String id;
  final String idempotencyKey;  // Stable key preventing duplicate orders
  final String buyerUserId;
  final String buyerName;
  final List<OrderItem> items;
  final int totalPaise;          // Sum of item totals at purchase time
  final String shippingAddress;  // Plain formatted string (no PII logged)
  final OrderStatus status;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.idempotencyKey,
    required this.buyerUserId,
    required this.buyerName,
    required this.items,
    required this.totalPaise,
    required this.shippingAddress,
    required this.status,
    required this.createdAt,
  });

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        idempotencyKey: idempotencyKey,
        buyerUserId: buyerUserId,
        buyerName: buyerName,
        items: items,
        totalPaise: totalPaise,
        shippingAddress: shippingAddress,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'idempotencyKey': idempotencyKey,
        'buyerUserId': buyerUserId,
        'buyerName': buyerName,
        'items': items.map((i) => i.toJson()).toList(),
        'totalPaise': totalPaise,
        'shippingAddress': shippingAddress,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        idempotencyKey: json['idempotencyKey'] as String,
        buyerUserId: json['buyerUserId'] as String,
        buyerName: json['buyerName'] as String,
        items: (json['items'] as List)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPaise: json['totalPaise'] as int,
        shippingAddress: json['shippingAddress'] as String,
        status: OrderStatusExtension.fromString(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
