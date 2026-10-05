import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/analytics_service.dart';

enum SortOption { newest, lowToHigh, highToLow, rating, popularity }

class ProductProvider with ChangeNotifier {
  final ProductService _productService = ProductService();
  final AnalyticsService _analyticsService = AnalyticsService();

  List<Product> _products = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  SortOption _sortOption = SortOption.newest;
  bool _isLoading = false;

  // Derived lists are rebuilt only when their inputs change. They used to be
  // recomputed (filter + sort over ~120 products) on every getter call, and
  // the home screen calls them several times per build.
  List<Product>? _filteredCache;
  List<String> _categories = const ['All'];
  List<Product> _featured = const [];
  List<Product> _popular = const [];

  List<Product> get products => _products;

  String get searchQuery => _searchQuery;

  List<Product> get filteredProducts => _filteredCache ??= _computeFiltered();

  List<Product> _computeFiltered() {
    List<Product> result = List.from(_products);

    if (_selectedCategory != 'All') {
      result = result.where((p) => p.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }

    switch (_sortOption) {
      case SortOption.lowToHigh:
        result.sort((a, b) => a.discountedPrice.compareTo(b.discountedPrice));
        break;
      case SortOption.highToLow:
        result.sort((a, b) => b.discountedPrice.compareTo(a.discountedPrice));
        break;
      case SortOption.rating:
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.popularity:
        // Use stock or rating as a proxy for popularity
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case SortOption.newest:
        result.sort((a, b) => b.id.compareTo(a.id));
        break;
    }

    return result;
  }

  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  SortOption get sortOption => _sortOption;

  void _setProducts(List<Product> products) {
    _products = products;
    _filteredCache = null;
    final uniqueCategories = _products.map((p) => p.category).toSet().toList()
      ..sort();
    _categories = ['All', ...uniqueCategories];
    _featured = _products.where((p) => p.rating >= 4.8).toList();
    _popular = _products.where((p) => p.discount > 10).toList();
  }

  /// Shows the cached (or bundled) catalogue straight away, then refreshes it
  /// from the network. The shimmer is only shown when there is nothing at all
  /// to display yet.
  Future<void> loadProducts() async {
    if (_products.isEmpty) {
      _isLoading = true;
      notifyListeners();
      final cached = await _productService.loadCachedProducts();
      if (cached.isNotEmpty) {
        _setProducts(cached);
        _isLoading = false;
        notifyListeners();
      }
    }

    try {
      _setProducts(await _productService.fetchProducts());
    } catch (e) {
      debugPrint("Error loading products: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _filteredCache = null;
    _analyticsService.viewCategory(category);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _filteredCache = null;
    if (query.isNotEmpty) {
      _analyticsService.search(query);
    }
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    _filteredCache = null;
    notifyListeners();
  }

  Product getProductById(int id) {
    return _products.firstWhere((p) => p.id == id);
  }

  List<Product> getProductsByCategory(String category) {
    if (category == 'All') return _products;
    return _products.where((p) => p.category == category).toList();
  }

  List<Product> get featuredProducts => _featured;
  List<Product> get popularProducts => _popular;
  List<Product> get recommendedProducts =>
      _products.take(10).toList()..shuffle();

  List<String> get categories => _categories;
}
