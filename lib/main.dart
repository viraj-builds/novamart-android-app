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
import 'package:permission_handler/permission_handler.dart';

Future<void> requestNotificationPermission(BuildContext? context) async {
  final status = await Permission.notification.status;

  if (status.isGranted) {
    // Already allowed — nothing to do
    return;
  }

  if (status.isPermanentlyDenied) {
    // Android remembers "Don't ask again" — must open Settings manually
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Enable Notifications'),
          content: const Text(
            'Notifications are permanently blocked. '
            'Please go to App Settings and enable them manually.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings(); // Opens Android App Settings page
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
    return;
  }

  // Status is denied or not yet asked — request the dialog
  await Permission.notification.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Explicitly ensure the user profile is opted-in to push notifications
  CleverTapPlugin.setOptOut(false);
  CleverTapPlugin.setDebugLevel(3);

  // Request Android 13+ runtime notification permission on first launch
  await requestNotificationPermission(null);

  // Also request via Firebase (needed for iOS and FCM token generation)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // NOTE: Do NOT manually call CleverTapPlugin.setPushToken() here.
  // The app uses android:name="com.clevertap.android.sdk.Application" in
  // AndroidManifest.xml, which means CleverTap already auto-registers the
  // FCM token internally. Calling setPushToken() again causes duplicate
  // registration events and can conflict with the auto-registration flow.
  //
  // We only listen for token *refreshes* to keep CleverTap in sync.
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    CleverTapPlugin.setPushToken(newToken);
  });

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
