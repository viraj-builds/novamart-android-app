import 'package:flutter/material.dart';
import 'package:clevertap_plugin/clevertap_plugin.dart';

import '../models/clevertap_models.dart';
import '../routes/app_routes.dart';

/// Single entry point for every CleverTap engagement surface used by the app:
///
///  * In-App Notifications  https://developer.clevertap.com/docs/flutter-in-app
///  * App Inbox             https://developer.clevertap.com/docs/flutter-app-inbox
///  * Native Display        https://docs.clevertap.com/docs/native-display
///
/// Exposed as a [ChangeNotifier] so the inbox badge and the Native Display
/// placements rebuild as soon as CleverTap pushes new data down.
class CleverTapService extends ChangeNotifier {
  CleverTapService._internal();
  static final CleverTapService instance = CleverTapService._internal();
  factory CleverTapService() => instance;

  /// Needed to navigate from CleverTap callbacks, which fire outside the tree.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final CleverTapPlugin _plugin = CleverTapPlugin();

  bool _initialized = false;

  // ── App Inbox state ────────────────────────────────────────────────────────
  bool _inboxInitialized = false;
  int _inboxTotalCount = 0;
  int _inboxUnreadCount = 0;
  List<CtInboxMessage> _inboxMessages = const [];

  bool get isInboxInitialized => _inboxInitialized;
  int get inboxTotalCount => _inboxTotalCount;
  int get inboxUnreadCount => _inboxUnreadCount;
  List<CtInboxMessage> get inboxMessages => _inboxMessages;

  // ── Native Display state ───────────────────────────────────────────────────
  List<CtDisplayUnit> _displayUnits = const [];

  List<CtDisplayUnit> get displayUnits => _displayUnits;

  /// Native Display units tagged for a given screen via the `screen` custom KV.
  List<CtDisplayUnit> unitsForScreen(String screen) =>
      _displayUnits.where((u) => u.targetScreen == screen).toList();

  // ── In-App state ───────────────────────────────────────────────────────────
  bool _inAppSuspended = false;

  bool get isInAppSuspended => _inAppSuspended;

  /// Registers every CleverTap handler and boots the App Inbox.
  ///
  /// Must run before `runApp()` so no callback is missed, and must only run
  /// once — the native side keeps one handler per event type.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _registerInAppHandlers();
    _registerInboxHandlers();
    _registerNativeDisplayHandlers();

    // Boots the inbox and triggers `inboxDidInitialize`. Safe to call on web,
    // where the plugin no-ops.
    await CleverTapPlugin.initializeInbox();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // In-App Notifications
  // ═══════════════════════════════════════════════════════════════════════════

  void _registerInAppHandlers() {
    _plugin.setCleverTapInAppNotificationShowHandler((Map<String, dynamic>? map) {
      debugPrint('CleverTap InApp shown: $map');
    });

    _plugin.setCleverTapInAppNotificationDismissedHandler((Map<String, dynamic>? map) {
      debugPrint('CleverTap InApp dismissed: $map');
      // `extras` / `actionExtras` carry the campaign's custom KV pairs.
      _handleDeepLinkFromKV(map?['extras'] ?? map?['actionExtras']);
    });

    _plugin.setCleverTapInAppNotificationButtonClickedHandler((Map<String, dynamic>? map) {
      debugPrint('CleverTap InApp button clicked: $map');
      // For button taps the KV pairs are the payload itself.
      _handleDeepLinkFromKV(map);
    });
  }

  /// Pulls the latest in-app campaigns from CleverTap on demand.
  /// Useful right after login, when the segment a user belongs to changes.
  Future<bool> fetchInApps() async {
    final fetched = await CleverTapPlugin.fetchInApps();
    debugPrint('CleverTap fetchInApps -> $fetched');
    return fetched ?? false;
  }

  /// Pauses in-apps. Anything triggered meanwhile is queued and shown once
  /// [resumeInAppNotifications] is called. Use around checkout/payment so a
  /// popup can never cover a critical flow.
  Future<void> suspendInAppNotifications() async {
    await CleverTapPlugin.suspendInAppNotifications();
    _inAppSuspended = true;
    notifyListeners();
  }

  /// Drops in-apps entirely — unlike [suspendInAppNotifications] nothing is
  /// replayed on resume.
  Future<void> discardInAppNotifications({bool dismissInAppIfVisible = false}) async {
    await CleverTapPlugin.discardInAppNotifications(
      dismissInAppIfVisible: dismissInAppIfVisible,
    );
    _inAppSuspended = true;
    notifyListeners();
  }

  Future<void> resumeInAppNotifications() async {
    await CleverTapPlugin.resumeInAppNotifications();
    _inAppSuspended = false;
    notifyListeners();
  }

  /// Frees cached in-app media. Pass `false` to clear everything, `true` to
  /// drop only assets whose campaigns have expired.
  Future<void> clearInAppResources({bool expiredOnly = true}) =>
      CleverTapPlugin.clearInAppResources(expiredOnly);

  // ═══════════════════════════════════════════════════════════════════════════
  // App Inbox
  // ═══════════════════════════════════════════════════════════════════════════

  void _registerInboxHandlers() {
    _plugin.setCleverTapInboxDidInitializeHandler(() {
      debugPrint('CleverTap App Inbox initialized');
      _inboxInitialized = true;
      refreshInbox();
    });

    // Fires whenever messages are added, removed or marked read natively.
    _plugin.setCleverTapInboxMessagesDidUpdateHandler(() {
      debugPrint('CleverTap App Inbox messages updated');
      refreshInbox();
    });

    _plugin.setCleverTapInboxNotificationMessageClickedHandler(
        (Map<String, dynamic>? message, int contentPageIndex, int buttonIndex) {
      debugPrint('CleverTap Inbox message clicked '
          '(page $contentPageIndex, button $buttonIndex): $message');
      final parsed = CtInboxMessage.fromJson(message);
      if (parsed != null) _handleDeepLinkFromKV(parsed.customKV);
    });

    // Only fires for buttons configured with custom key-value pairs.
    _plugin.setCleverTapInboxNotificationButtonClickedHandler((Map<String, dynamic>? map) {
      debugPrint('CleverTap Inbox button clicked: $map');
      _handleDeepLinkFromKV(map);
    });
  }

  /// Reloads messages plus the badge counts from the native inbox store.
  Future<void> refreshInbox() async {
    try {
      final results = await Future.wait([
        CleverTapPlugin.getInboxMessageCount(),
        CleverTapPlugin.getInboxMessageUnreadCount(),
        CleverTapPlugin.getAllInboxMessages(),
      ]);

      _inboxTotalCount = (results[0] as int?) ?? 0;
      _inboxUnreadCount = (results[1] as int?) ?? 0;
      _inboxMessages = ((results[2] as List?) ?? const [])
          .map(CtInboxMessage.fromJson)
          .whereType<CtInboxMessage>()
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('CleverTap refreshInbox failed: $e');
    }
  }

  /// Opens CleverTap's own native inbox UI (Android only).
  /// The app also ships a Flutter-rendered inbox — see `AppInboxScreen`.
  Future<void> showNativeInbox({bool isDark = false}) {
    return CleverTapPlugin.showInbox({
      'navBarTitle': 'Notifications',
      'navBarTitleColor': isDark ? '#FFFFFF' : '#333333',
      'navBarColor': isDark ? '#1E1E1E' : '#FFFFFF',
      'inboxBackgroundColor': isDark ? '#121212' : '#F5F5F5',
      'backButtonColor': isDark ? '#FFFFFF' : '#333333',
      'noMessageText': 'No notifications yet',
      'noMessageTextColor': isDark ? '#AAAAAA' : '#888888',
      'tabs': <String>['Offers', 'Orders'],
      'selectedTabColor': '#2196F3',
      'unselectedTabColor': isDark ? '#AAAAAA' : '#888888',
      'tabBackgroundColor': isDark ? '#1E1E1E' : '#FFFFFF',
      'firstTabTitle': 'All',
    });
  }

  /// Records the inbox "viewed" event CleverTap uses for impression reporting.
  Future<void> markInboxMessageViewed(String messageId) =>
      CleverTapPlugin.pushInboxNotificationViewedEventForId(messageId);

  /// Records the inbox "clicked" event, then marks the message read locally.
  Future<void> markInboxMessageClicked(String messageId) async {
    await CleverTapPlugin.pushInboxNotificationClickedEventForId(messageId);
    await markInboxMessageRead(messageId);
  }

  Future<void> markInboxMessageRead(String messageId) async {
    await CleverTapPlugin.markReadInboxMessageForId(messageId);
    await refreshInbox();
  }

  Future<void> markAllInboxMessagesRead() async {
    await CleverTapPlugin.markReadAllInboxMessage();
    await refreshInbox();
  }

  Future<void> deleteInboxMessage(String messageId) async {
    await CleverTapPlugin.deleteInboxMessageForId(messageId);
    await refreshInbox();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Native Display
  // ═══════════════════════════════════════════════════════════════════════════

  void _registerNativeDisplayHandlers() {
    _plugin.setCleverTapDisplayUnitsLoadedHandler((List<dynamic>? units) {
      debugPrint('CleverTap Native Display units loaded: ${units?.length ?? 0}');
      _setDisplayUnits(units);
    });
  }

  /// Pulls whatever units are already cached natively. The loaded-handler covers
  /// live updates; this covers screens built before that callback arrives.
  Future<void> refreshDisplayUnits() async {
    try {
      _setDisplayUnits(await CleverTapPlugin.getAllDisplayUnits());
    } catch (e) {
      debugPrint('CleverTap refreshDisplayUnits failed: $e');
    }
  }

  void _setDisplayUnits(List<dynamic>? units) {
    _displayUnits = (units ?? const [])
        .map(CtDisplayUnit.fromJson)
        .whereType<CtDisplayUnit>()
        .toList();
    notifyListeners();
  }

  /// Raises the Native Display impression event. Call once per unit per render.
  Future<void> recordDisplayUnitViewed(String unitId) =>
      CleverTapPlugin.pushDisplayUnitViewedEvent(unitId);

  /// Raises the Native Display click event and follows the unit's action.
  Future<void> recordDisplayUnitClicked(CtDisplayUnit unit) async {
    await CleverTapPlugin.pushDisplayUnitClickedEvent(unit.unitId);
    _handleDeepLinkFromKV(unit.customKV);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Deep linking
  // ═══════════════════════════════════════════════════════════════════════════

  /// Routes on the custom key-value pairs attached to a CleverTap campaign.
  ///
  /// Dashboard setup: add a KV pair whose key is one of `route` / `screen` /
  /// `deeplink` / `wzrk_dl` and whose value is an app route such as `/cart`.
  void _handleDeepLinkFromKV(dynamic rawKV) {
    if (rawKV is! Map) return;
    final kv = Map<String, dynamic>.from(rawKV);

    final target = (kv['route'] ?? kv['deeplink'] ?? kv['wzrk_dl'] ?? kv['screen'])
        ?.toString();
    if (target == null || target.isEmpty) return;

    // Strip any custom scheme, e.g. novamart://cart -> /cart
    var route = target;
    final schemeIndex = route.indexOf('://');
    if (schemeIndex != -1) route = '/${route.substring(schemeIndex + 3)}';
    if (!route.startsWith('/')) route = '/$route';

    const knownRoutes = {
      AppRoutes.main,
      AppRoutes.home,
      AppRoutes.cart,
      AppRoutes.login,
      AppRoutes.signup,
      AppRoutes.orderHistory,
      AppRoutes.notifications,
      AppRoutes.categories,
    };
    if (!knownRoutes.contains(route)) {
      debugPrint('CleverTap deep link ignored, unknown route: $route');
      return;
    }

    debugPrint('CleverTap deep link -> $route');
    navigatorKey.currentState?.pushNamed(route);
  }
}
