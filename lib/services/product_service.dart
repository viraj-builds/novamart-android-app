import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';

class ProductService {
  Future<List<Product>> fetchProducts() async {
    try {
      final List<Product> products = [];
      
      // 1. Fetch from FakeStore API
      try {
        final response = await http.get(Uri.parse('https://fakestoreapi.com/products')).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          products.addAll(data.map((json) => Product.fromJson(json)));
        }
      } catch (e) {
        debugPrint('Failed to load FakeStore products: $e');
      }

      // 2. Fetch from DummyJSON API
      try {
        final response = await http.get(Uri.parse('https://dummyjson.com/products?limit=100')).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> productsData = data['products'];
          
          for (var pData in productsData) {
            final product = Product.fromJson(pData);
            // Ensure unique IDs by adding an offset to DummyJSON IDs
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
        }
      } catch (e) {
        debugPrint('Failed to load DummyJSON products: $e');
      }

      // Mix the products
      products.shuffle();
      return products;
    } catch (e) {
      throw Exception('Failed to load products: $e');
    }
  }
}
