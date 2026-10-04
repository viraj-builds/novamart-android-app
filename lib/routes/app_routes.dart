import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/product_details_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/main_screen.dart';
import '../screens/order_history_screen.dart';
import '../screens/order_tracking_screen.dart';
import '../screens/app_inbox_screen.dart';
import '../screens/category_screen.dart';
import '../models/product_model.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String main = '/main';
  static const String home = '/home';
  static const String productDetails = '/product-details';
  static const String cart = '/cart';
  static const String orderHistory = '/order-history';
  static const String orderTracking = '/order-tracking';
  static const String notifications = '/notifications';
  static const String categories = '/categories';

  static const _linkable = {main, home, cart, orderHistory, notifications, categories, login, signup};

  /// "novamart://cart" / "novamart://app/cart" / "/cart" → "/cart" when it's a
  /// screen a link may open; null otherwise.
  static String? fromLink(String? link) {
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    final parts = uri.scheme == 'novamart' ? [uri.host, ...uri.pathSegments] : uri.pathSegments;
    final segs = parts.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return uri.scheme == 'novamart' ? main : null;
    final route = '/${segs.last}';
    return _linkable.contains(route) ? route : null;
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case main:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case productDetails:
        final product = settings.arguments as Product;
        return MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: product),
        );
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen());
      case orderHistory:
        return MaterialPageRoute(builder: (_) => const OrderHistoryScreen());
      case orderTracking:
        final orderId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: orderId));
      case notifications:
        // Backed by the CleverTap App Inbox.
        return MaterialPageRoute(builder: (_) => const AppInboxScreen());
      case categories:
        return MaterialPageRoute(builder: (_) => const CategoryScreen());
      default:
        // A link such as "novamart://cart" or an unknown name must never end
        // on a blank "No route defined" page: map it to a screen if we can,
        // otherwise start from the splash (it sends the user home or to login).
        final mapped = fromLink(settings.name);
        if (mapped != null && mapped != settings.name) {
          return generateRoute(RouteSettings(name: mapped, arguments: settings.arguments));
        }
        debugPrint('Unknown route ${settings.name} → splash');
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
