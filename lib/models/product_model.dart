class Product {
  final int id;
  final String name;
  final String category;
  final String brand;
  final String description;
  final double price;
  final double discount;
  final double rating;
  final int stock;
  final String image;
  final List<String> images;
  final List<String> colors;
  final List<String> sizes;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.description,
    required this.price,
    required this.discount,
    required this.rating,
    required this.stock,
    required this.image,
    required this.images,
    required this.colors,
    required this.sizes,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return double.tryParse(value.toString()) ?? 0.0;
    }

    double parsedRating = 0.0;
    if (json['rating'] is Map) {
      parsedRating = parseDouble(json['rating']['rate']);
    } else {
      parsedRating = parseDouble(json['rating']);
    }

    return Product(
      id: json['id'] ?? 0,
      name: json['title'] ?? json['name'] ?? 'Unknown Product',
      category: json['category'] ?? 'uncategorized',
      brand: json['brand'] ?? 'Generic',
      description: json['description'] ?? '',
      price: parseDouble(json['price']),
      discount: parseDouble(json['discountPercentage'] ?? json['discount']),
      rating: parsedRating,
      stock: json['stock'] ?? 10,
      image: json['image'] ?? json['thumbnail'] ?? '',
      images: json['images'] != null 
          ? List<String>.from(json['images']) 
          : [json['image'] ?? json['thumbnail'] ?? ''],
      colors: json['colors'] != null ? List<String>.from(json['colors']) : ['Standard'],
      sizes: json['sizes'] != null ? List<String>.from(json['sizes']) : ['Default'],
    );
  }

  double get discountedPrice => price - (price * (discount / 100));
}
