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

  List<Product> get products => _products;

  String get searchQuery => _searchQuery;

  List<Product> get filteredProducts {
    List<Product> result = List.from(_products);

    if (_selectedCategory != 'All') {
      result = result.where((p) => p.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((p) =>
        p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        p.category.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
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

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await _productService.fetchProducts();
    } catch (e) {
      debugPrint("Error loading products: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _analyticsService.viewCategory(category);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    if (query.isNotEmpty) {
      _analyticsService.search(query);
    }
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  Product getProductById(int id) {
    return _products.firstWhere((p) => p.id == id);
  }

  List<Product> getProductsByCategory(String category) {
    if (category == 'All') return _products;
    return _products.where((p) => p.category == category).toList();
  }

  List<Product> get featuredProducts => _products.where((p) => p.rating >= 4.8).toList();
  List<Product> get popularProducts => _products.where((p) => p.discount > 10).toList();
  List<Product> get recommendedProducts => _products.take(10).toList()..shuffle();

  List<String> get categories {
    final uniqueCategories = _products.map((p) => p.category).toSet().toList();
    uniqueCategories.sort();
    return ['All', ...uniqueCategories];
  }
}
