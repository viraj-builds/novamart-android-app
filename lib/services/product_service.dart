import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import 'storage_service.dart';

class ProductService {
  static const _cacheKey = 'products_cache_v1';
  static const _timeout = Duration(seconds: 8);

  /// Products from the last successful network load, or the bundled catalogue
  /// on a first launch with no cache. Returns immediately so the home screen
  /// never sits on a shimmer while the network is slow.
  Future<List<Product>> loadCachedProducts() async {
    final cached = StorageService.getString(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        return await compute(_decodeCache, cached);
      } catch (e) {
        debugPrint('Product cache unreadable, falling back to bundle: $e');
      }
    }
    try {
      final raw =
          await rootBundle.loadString('assets/data/sports_products.json');
      return await compute(_decodeList, raw);
    } catch (e) {
      debugPrint('Failed to load bundled products: $e');
      return [];
    }
  }

  Future<List<Product>> fetchProducts() async {
    // Both APIs are requested at the same time — they used to run one after
    // the other with a 15s timeout each, so a slow host held the home screen
    // for up to 30s.
    final results = await Future.wait([
      _get('https://fakestoreapi.com/products'),
      _get('https://dummyjson.com/products?limit=100'),
    ]);

    // JSON decoding of ~120 products is done off the UI isolate so it can't
    // drop frames on the home screen.
    final products = await compute(_parseResponses, results);
    if (products.isEmpty) {
      throw Exception('Failed to load products from both sources');
    }

    StorageService.setString(_cacheKey, await compute(_encodeCache, products));
    return products;
  }

  Future<String?> _get(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode == 200) return response.body;
      debugPrint('GET $url -> ${response.statusCode}');
    } catch (e) {
      debugPrint('GET $url failed: $e');
    }
    return null;
  }
}

// ── Isolate entry points (must be top-level) ──────────────────────────────────

List<Product> _parseResponses(List<String?> bodies) {
  final List<Product> products = [];

  // 1. FakeStore API
  final fakeStore = bodies[0];
  if (fakeStore != null) {
    try {
      final List<dynamic> data = json.decode(fakeStore);
      products.addAll(data.map((j) => Product.fromJson(j)));
    } catch (_) {}
  }

  // 2. DummyJSON API — IDs are offset to keep them unique across sources.
  final dummyJson = bodies[1];
  if (dummyJson != null) {
    try {
      final List<dynamic> data = json.decode(dummyJson)['products'];
      for (final pData in data) {
        final product = Product.fromJson(pData);
        products.add(Product(
          id: product.id + 1000,
          name: product.name,
          category: product.category,
          brand: product.brand,
          description: product.description,
          price: product.price,
          discount: product.discount,
          rating: product.rating,
          stock: product.stock,
          image: product.image,
          images: product.images,
          colors: product.colors,
          sizes: product.sizes,
        ));
      }
    } catch (_) {}
  }

  // Mix the products
  products.shuffle();
  return products;
}

List<Product> _decodeList(String raw) {
  final List<dynamic> data = json.decode(raw);
  return data
      .map((j) => Product.fromJson(Map<String, dynamic>.from(j)))
      .toList();
}

List<Product> _decodeCache(String raw) => _decodeList(raw);

String _encodeCache(List<Product> products) =>
    json.encode(products.map((p) => p.toJson()).toList());
