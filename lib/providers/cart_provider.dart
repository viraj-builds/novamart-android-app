import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:clevertap_plugin/clevertap_plugin.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';

class CartProvider with ChangeNotifier {
  Map<int, CartItem> _items = {};
  final AnalyticsService _analyticsService = AnalyticsService();

  CartProvider() {
    _loadCart();
  }

  Map<int, CartItem> get items => {..._items};

  int get itemCount {
    int count = 0;
    _items.forEach((key, item) => count += item.quantity);
    return count;
  }

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.product.discountedPrice * cartItem.quantity;
    });
    return total;
  }

  void addItem(Product product, {int quantity = 1}) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + quantity,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => CartItem(
          product: product,
          quantity: quantity,
        ),
      );
    }
    
    // Original Analytics tracking
    _analyticsService.addToCart(product.id.toString(), product.name, product.price, quantity);
    
    // CleverTap Add to Cart tracking
    var eventData = {
      'Product Name': product.name,
      'Category': product.category,
      'Brand': product.brand,
      'Price': product.price,
      'Discount Percent': product.discount,
      'Quantity': quantity,
    };
    CleverTapPlugin.recordEvent("Add to Cart", eventData);

    _saveCart();
    notifyListeners();
  }

  void removeItem(int productId) {
    if (_items.containsKey(productId)) {
      final item = _items[productId]!;
      _analyticsService.removeFromCart(productId.toString(), item.product.name);
      _items.remove(productId);
      _saveCart();
      notifyListeners();
    }
  }

  void removeSingleItem(int productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }

  void checkout() {
    _analyticsService.beginCheckout(totalAmount, itemCount);
    _analyticsService.purchase(
      DateTime.now().millisecondsSinceEpoch.toString(),
      totalAmount,
      _items.keys.map((k) => k.toString()).toList(),
    );
    clearCart();
  }

  void _saveCart() {
    final cartData = _items.map((key, item) => MapEntry(key.toString(), {
      'product': {
        'id': item.product.id,
        'name': item.product.name,
        'category': item.product.category,
        'brand': item.product.brand,
        'description': item.product.description,
        'price': item.product.price,
        'discount': item.product.discount,
        'rating': item.product.rating,
        'stock': item.product.stock,
        'image': item.product.image,
        'images': item.product.images,
        'colors': item.product.colors,
        'sizes': item.product.sizes,
      },
      'quantity': item.quantity,
    }));
    StorageService.setString('cart_data', json.encode(cartData));
  }

  void _loadCart() {
    final cartString = StorageService.getString('cart_data');
    if (cartString != null) {
      try {
        final Map<String, dynamic> cartData = json.decode(cartString);
        _items = cartData.map((key, value) => MapEntry(int.parse(key), CartItem(
          product: Product.fromJson(value['product']),
          quantity: value['quantity'],
        )));
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading cart: $e");
        StorageService.remove('cart_data');
      }
    }
  }
}
