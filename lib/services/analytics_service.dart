import 'dart:developer' as developer;

import 'package:clevertap_plugin/clevertap_plugin.dart';

/// Raises the CleverTap events the dashboard campaigns trigger on.
///
/// In-App Notifications, App Inbox and Native Display campaigns are all
/// targeted by event name plus event properties, so the names below must match
/// the triggers configured in the CleverTap dashboard.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  void _record(String event, [Map<String, dynamic>? properties]) {
    developer.log('CleverTap event: $event ${properties ?? ''}');
    CleverTapPlugin.recordEvent(event, properties ?? <String, dynamic>{});
  }

  void login(String userId, String email) =>
      _record('Login', {'Identity': userId, 'Email': email});

  void logout() => _record('Logout');

  void viewHome() => _record('Home Viewed');

  void viewCategory(String categoryName) =>
      _record('Category Viewed', {'Category': categoryName});

  void viewProduct(String productId, String productName, double price) =>
      _record('Product Viewed', {
        'Product ID': productId,
        'Product Name': productName,
        'Price': price,
      });

  void search(String query) => _record('Product Searched', {'Query': query});

  void wishlist(String productId, String productName, bool added) =>
      _record(added ? 'Added To Wishlist' : 'Removed From Wishlist', {
        'Product ID': productId,
        'Product Name': productName,
      });

  void addToCart(String productId, String productName, double price, int quantity) =>
      _record('Add to Cart', {
        'Product ID': productId,
        'Product Name': productName,
        'Price': price,
        'Quantity': quantity,
      });

  void removeFromCart(String productId, String productName) =>
      _record('Removed From Cart', {
        'Product ID': productId,
        'Product Name': productName,
      });

  void beginCheckout(double totalAmount, int itemCount) =>
      _record('Checkout Started', {
        'Amount': totalAmount,
        'Item Count': itemCount,
      });

  /// Purchases are reported through `recordChargedEvent` in `CartProvider`,
  /// which is what CleverTap's revenue reporting reads. This is the lightweight
  /// companion event used for campaign triggering.
  void purchase(String transactionId, double totalAmount, List<String> itemIds) =>
      _record('Purchase Completed', {
        'Transaction ID': transactionId,
        'Amount': totalAmount,
        'Item Count': itemIds.length,
      });

  void notificationClicked(String notificationId, String title) =>
      _record('Notification Clicked', {
        'Notification ID': notificationId,
        'Title': title,
      });
}
