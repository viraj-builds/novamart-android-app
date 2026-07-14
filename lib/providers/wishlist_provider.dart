import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';

class WishlistProvider with ChangeNotifier {
  List<Product> _wishlistItems = [];
  final AnalyticsService _analyticsService = AnalyticsService();

  WishlistProvider() {
    _loadWishlist();
  }

  List<Product> get wishlistItems => [..._wishlistItems];

  void toggleWishlist(Product product) {
    final index = _wishlistItems.indexWhere((p) => p.id == product.id);
    bool added = false;
    if (index >= 0) {
      _wishlistItems.removeAt(index);
      added = false;
    } else {
      _wishlistItems.add(product);
      added = true;
    }
    _analyticsService.wishlist(product.id.toString(), product.name, added);
    _saveWishlist();
    notifyListeners();
  }

  bool isFavorite(Product product) {
    return _wishlistItems.any((p) => p.id == product.id);
  }

  void _saveWishlist() {
    final wishlistData = _wishlistItems.map((product) => {
      'id': product.id,
      'name': product.name,
      'category': product.category,
      'brand': product.brand,
      'description': product.description,
      'price': product.price,
      'discount': product.discount,
      'rating': product.rating,
      'stock': product.stock,
      'image': product.image,
      'images': product.images,
      'colors': product.colors,
      'sizes': product.sizes,
    }).toList();
    StorageService.setString('wishlist_data', json.encode(wishlistData));
  }

  void _loadWishlist() {
    final wishlistString = StorageService.getString('wishlist_data');
    if (wishlistString != null) {
      try {
        final List<dynamic> wishlistData = json.decode(wishlistString);
        _wishlistItems = wishlistData
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading wishlist: $e");
        StorageService.remove('wishlist_data');
      }
    }
  }
}
