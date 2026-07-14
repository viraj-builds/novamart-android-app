import 'dart:developer' as developer;

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  void login(String userId, String email) {
    developer.log('Analytics: Login - ID: $userId, Email: $email');
  }

  void logout() {
    developer.log('Analytics: Logout');
  }

  void viewHome() {
    developer.log('Analytics: View Home');
  }

  void viewCategory(String categoryName) {
    developer.log('Analytics: View Category - Category: $categoryName');
  }

  void viewProduct(String productId, String productName, double price) {
    developer.log('Analytics: View Product - ID: $productId, Name: $productName, Price: $price');
  }

  void search(String query) {
    developer.log('Analytics: Search - Query: $query');
  }

  void wishlist(String productId, String productName, bool added) {
    developer.log('Analytics: Wishlist ${added ? 'Added' : 'Removed'} - ID: $productId, Name: $productName');
  }

  void addToCart(String productId, String productName, double price, int quantity) {
    developer.log('Analytics: Add to Cart - ID: $productId, Name: $productName, Price: $price, Qty: $quantity');
  }

  void removeFromCart(String productId, String productName) {
    developer.log('Analytics: Remove from Cart - ID: $productId, Name: $productName');
  }

  void beginCheckout(double totalAmount, int itemCount) {
    developer.log('Analytics: Begin Checkout - Total: $totalAmount, Items: $itemCount');
  }

  void purchase(String transactionId, double totalAmount, List<String> itemIds) {
    developer.log('Analytics: Purchase - TxID: $transactionId, Total: $totalAmount, Items: ${itemIds.join(', ')}');
  }

  void notificationClicked(String notificationId, String title) {
    developer.log('Analytics: Notification Clicked - ID: $notificationId, Title: $title');
  }
}
