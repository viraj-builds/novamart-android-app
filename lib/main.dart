import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/storage_service.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:clevertap_plugin/clevertap_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Explicitly ensure the user profile is opted-in to push notifications
  CleverTapPlugin.setOptOut(false);
  CleverTapPlugin.setDebugLevel(3);
  
  await FirebaseMessaging.instance.requestPermission();
  
  // Get the FCM token and register it with CleverTap
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken != null) {
    CleverTapPlugin.setPushToken(fcmToken);
  }

  // Force the profile to be subscribed to Push every time the app opens
  CleverTapPlugin.profileSet({'MSG-push': true});

  // Create the notification channel for CleverTap
  CleverTapPlugin.createNotificationChannel(
      "sportsshop_channel", "Sports Shop Offers", "Updates and offers from Sports Shop", 5, true);

  runApp(const NovaMartApp());
}

class NovaMartApp extends StatelessWidget {
  const NovaMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()..loadProducts()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'NovaMart',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.generateRoute,
          );
        },
      ),
    );
  }
}
