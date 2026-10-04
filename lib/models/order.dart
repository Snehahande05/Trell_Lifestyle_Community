import 'product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final String? referrerCreatorId;
  final String? referrerPostId;

  CartItem({
    required this.product,
    required this.quantity,
    this.referrerCreatorId,
    this.referrerPostId,
  });

  int get totalPaise => product.pricePaise * quantity;
  String get cartItemId => '${product.id}_${referrerCreatorId ?? "none"}_${referrerPostId ?? "none"}';

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
        'referrerCreatorId': referrerCreatorId,
        'referrerPostId': referrerPostId,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product.fromJson(json['product']),
        quantity: json['quantity'],
        referrerCreatorId: json['referrerCreatorId'],
        referrerPostId: json['referrerPostId'],
      );

  CartItem copyWith({int? quantity}) => CartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        referrerCreatorId: referrerCreatorId,
        referrerPostId: referrerPostId,
      );
}

enum OrderStatus { pending, paid, completed, cancelled, refunded }

class OrderItem {
  final String productId;
  final String productName;
  final int pricePaise;
  final int quantity;
  final String? referrerCreatorId;
  final String? referrerPostId;
  final double commissionRate;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.pricePaise,
    required this.quantity,
    this.referrerCreatorId,
    this.referrerPostId,
    required this.commissionRate,
  });

  int get totalPaise => pricePaise * quantity;
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
        productId: json['productId'],
        productName: json['productName'],
        pricePaise: json['pricePaise'],
        quantity: json['quantity'],
        referrerCreatorId: json['referrerCreatorId'],
        referrerPostId: json['referrerPostId'],
        commissionRate: (json['commissionRate'] as num).toDouble(),
      );
}

class Order {
  final String id;
  final String buyerUserId;
  final String buyerName;
  final List<OrderItem> items;
  final int totalPaise;
  final String shippingAddress;
  final OrderStatus status;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.buyerUserId,
    required this.buyerName,
    required this.items,
    required this.totalPaise,
    required this.shippingAddress,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'buyerUserId': buyerUserId,
        'buyerName': buyerName,
        'items': items.map((i) => i.toJson()).toList(),
        'totalPaise': totalPaise,
        'shippingAddress': shippingAddress,
        'status': status.index,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'],
        buyerUserId: json['buyerUserId'],
        buyerName: json['buyerName'],
        items: (json['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
        totalPaise: json['totalPaise'],
        shippingAddress: json['shippingAddress'],
        status: OrderStatus.values[json['status']],
        createdAt: DateTime.parse(json['createdAt']),
      );

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        buyerUserId: buyerUserId,
        buyerName: buyerName,
        items: items,
        totalPaise: totalPaise,
        shippingAddress: shippingAddress,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
