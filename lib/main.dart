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
import 'services/clevertap_service.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:clevertap_plugin/clevertap_plugin.dart';
import 'package:flutter/services.dart';
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

Future<void> requestLocationPermission(BuildContext? context) async {
  final status = await Permission.locationWhenInUse.status;

  if (status.isGranted) {
    return;
  }

  if (status.isPermanentlyDenied) {
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Enable Location'),
          content: const Text(
            'Foreground location permission is required for CleverTap geofence features. '
            'Please open App Settings and allow location access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
    return;
  }

  await Permission.locationWhenInUse.request();
}

Future<void> requestBackgroundLocationPermission(BuildContext? context) async {
  final status = await Permission.locationAlways.status;

  if (status.isGranted) {
    return;
  }

  if (status.isPermanentlyDenied) {
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Enable Background Location'),
          content: const Text(
            'Background location access is required for CleverTap geofence tracking. '
            'Please open App Settings and allow it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
    return;
  }

  await Permission.locationAlways.request();
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

  // Request location permission for CleverTap geofence support.
  await requestLocationPermission(null);
  await requestBackgroundLocationPermission(null);

  // Also request via Firebase (needed for iOS and FCM token generation)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // FCM token registration is handled natively in MyFcmMessageListenerService
  // so we do not manually call CleverTapPlugin.setPushToken() here.

  // Create the notification channel for CleverTap
  CleverTapPlugin.createNotificationChannel(
      "sportsshop_channel", "Sports Shop Offers", "Updates and offers from Sports Shop", 5, true);

  // Registers the In-App, App Inbox and Native Display handlers and boots the
  // inbox. Must happen before runApp() so no CleverTap callback is missed.
  await CleverTapService.instance.init();

  runApp(const NovaMartApp());

  // Trigger a geofence location update once the Flutter UI is mounted.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _triggerGeofenceLocation();
  });
}

Future<void> _triggerGeofenceLocation() async {
  const channel = MethodChannel('com.example.sportsphere/clevertap_geofence');
  try {
    final result = await channel.invokeMethod<bool>('triggerGeofenceLocation');
    debugPrint('Geofence triggerLocation result: $result');
  } catch (e) {
    debugPrint('Geofence triggerLocation failed: $e');
  }
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
        // Drives the App Inbox badge/list and the Native Display placements.
        ChangeNotifierProvider.value(value: CleverTapService.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'NovaMart',
            // Lets CleverTap callbacks (in-app buttons, inbox taps, display
            // units) deep link without a BuildContext.
            navigatorKey: CleverTapService.navigatorKey,
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
