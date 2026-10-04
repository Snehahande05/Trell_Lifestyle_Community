class Product {
  final String id;
  final String name;
  final String imageUrl;
  final String description;
  final String category;
  final int pricePaise; // Price in integer paise
  final bool isAvailable;
  final double commissionRate; // e.g., 0.10 for 10% (between 0.05 and 0.15)

  Product({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.description,
    required this.category,
    required this.pricePaise,
    this.isAvailable = true,
    required this.commissionRate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'description': description,
        'category': category,
        'pricePaise': pricePaise,
        'isAvailable': isAvailable,
        'commissionRate': commissionRate,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        name: json['name'],
        imageUrl: json['imageUrl'],
        description: json['description'],
        category: json['category'],
        pricePaise: json['pricePaise'],
        isAvailable: json['isAvailable'] ?? true,
        commissionRate: (json['commissionRate'] as num).toDouble(),
      );
}
