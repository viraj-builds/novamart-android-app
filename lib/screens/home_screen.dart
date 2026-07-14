import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:async';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/shimmer_card.dart';
import '../services/analytics_service.dart';
import '../routes/app_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    AnalyticsService().viewHome();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query, ProductProvider provider) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      provider.setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Check if we are showing filtered results (either search or category active)
    final bool isFiltering = productProvider.searchQuery.isNotEmpty || 
                           (productProvider.selectedCategory != 'All' && productProvider.selectedCategory.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NovaMart', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications'); // We'll add this route later
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: productProvider.isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: () => productProvider.loadProducts(),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => _onSearchChanged(value, productProvider),
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Search by Name, Brand, Category...',
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: isDark ? Colors.white70 : Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    productProvider.setSearchQuery('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),

                    // Horizontal Categories
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: productProvider.categories.length,
                        itemBuilder: (context, index) {
                          final category = productProvider.categories[index];
                          return CategoryChip(
                            label: category,
                            isSelected: productProvider.selectedCategory == category,
                            onTap: () {
                              productProvider.setCategory(category);
                            },
                          );
                        },
                      ),
                    ),

                    if (isFiltering) ...[
                      // Filtered Results Grid
                      _buildSectionTitle('Search Results', productProvider.filteredProducts.length, context, isCategory: true),
                      productProvider.filteredProducts.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text('No products found.'),
                              ),
                            )
                          : _buildProductGrid(productProvider.filteredProducts),
                    ] else ...[
                      // Hero Banner
                      const SizedBox(height: 16),
                      _buildHeroBanner(),

                      // Featured Products
                      _buildSectionTitle('Featured Products', productProvider.featuredProducts.length, context),
                      _buildHorizontalProductList(productProvider.featuredProducts),

                      // Popular Products
                      _buildSectionTitle('Popular Products (Hot Deals)', productProvider.popularProducts.length, context),
                      _buildHorizontalProductList(productProvider.popularProducts),

                      // All Products Grid
                      _buildSectionTitle('Our Collection', productProvider.products.length, context),
                      _buildProductGrid(productProvider.products),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = size.width > 1200 ? 5 : (size.width > 800 ? 3 : 2);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 50, color: Colors.transparent),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => const ShimmerCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count, BuildContext context, {bool isCategory = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title + (isCategory ? ' ($count)' : ''),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (!isCategory)
            TextButton(
              onPressed: () {
                // Navigate to category screen to see all
                Navigator.pushNamed(context, AppRoutes.categories);
              },
              child: const Text('See All'),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    final banners = [
      {
        'title': 'CRICKET SEASON IS HERE',
        'subtitle': 'Up to 30% Off on Pro Bats',
        'image': 'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=800'
      },
      {
        'title': 'LEVEL UP YOUR GAME',
        'subtitle': 'New Arrival in Football Gear',
        'image': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800'
      },
      {
        'title': 'YOGA & WELLNESS',
        'subtitle': 'Premium Mats for Every Pose',
        'image': 'https://images.unsplash.com/photo-1592433051499-464332308b02?w=800'
      },
    ];

    return CarouselSlider(
      options: CarouselOptions(
        height: 180,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.9,
      ),
      items: banners.map((banner) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            image: DecorationImage(
              image: NetworkImage(banner['image']!),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner['title']!,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  banner['subtitle']!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text('Shop Now'),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHorizontalProductList(List<Product> products) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 16),
            child: ProductCard(product: products[index]),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = size.width > 1200 ? 5 : (size.width > 800 ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65, // Must match what ProductCard needs
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(product: products[index]);
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const FilterBottomSheet(),
    );
  }
}

class FilterBottomSheet extends StatelessWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sort By', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSortOption(context, 'Newest', SortOption.newest, productProvider),
          _buildSortOption(context, 'Price: Low to High', SortOption.lowToHigh, productProvider),
          _buildSortOption(context, 'Price: High to Low', SortOption.highToLow, productProvider),
          _buildSortOption(context, 'Customer Rating', SortOption.rating, productProvider),
          _buildSortOption(context, 'Popularity', SortOption.popularity, productProvider),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, String title, SortOption option, ProductProvider provider) {
    return RadioListTile<SortOption>(
      title: Text(title),
      value: option,
      groupValue: provider.sortOption,
      onChanged: (value) {
        if (value != null) provider.setSortOption(value);
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}
