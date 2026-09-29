import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clevertap_plugin/clevertap_plugin.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/clevertap_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AnalyticsService _analyticsService = AnalyticsService();
  final CleverTapService _cleverTap = CleverTapService.instance;
  
  bool _isAuthenticated = false;
  String? _email;

  bool get isAuthenticated => _isAuthenticated;
  String? get email => _email;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _isAuthenticated = true;
        _email = user.email;
        StorageService.setString('user_email', user.email!);

        // Re-apply channel opt-ins every time the auth session is restored
        // (covers app restarts where the user is already logged in).
        //
        // Only non-identity properties belong here. Identity fields (Email,
        // Identity, Phone) must NEVER be pushed with profileSet:
        //
        //   "If you push multiple identities on the same device without using
        //    the OnUserLogin API, CleverTap will merge profiles for all of
        //    these users."
        //   https://developer.clevertap.com/docs/concepts-user-profiles
        //
        // profileSet writes to whichever profile is currently active, it does
        // not switch profiles. This listener fires on sign-in before
        // onUserLogin has run, so pushing 'Email' here stamped the incoming
        // user's address onto the previous user's profile and merged the two.
        // Identity is established solely by onUserLogin in login()/signup().
        CleverTapPlugin.profileSet({
          'MSG-email': true,            // Opt-in to email channel
          'MSG-push': true,             // Opt-in to push channel
        });
      } else {
        _isAuthenticated = false;
        _email = null;
        StorageService.remove('user_email');
      }
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password, {String? phone}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Identify with CleverTap BEFORE recording anything. Events raised before
      // onUserLogin are attributed to whichever profile is still active — on a
      // shared device that is the previous user.
      CleverTapPlugin.onUserLogin(_buildProfile(email, phone));

      _analyticsService.login(credential.user!.uid, email);

      // onUserLogin switches to a different CleverTap profile, so the in-app
      // campaigns and inbox messages for the new user have to be re-pulled.
      await _cleverTap.fetchInApps();
      await _cleverTap.refreshInbox();

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An unknown authentication error occurred.';
    } catch (e) {
      return 'Failed to log in: $e';
    }
  }

  Future<String?> signup(String email, String password, {String? phone}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Identify first, for the same reason as in login().
      CleverTapPlugin.onUserLogin(_buildProfile(email, phone));

      _analyticsService.login(credential.user!.uid, email);

      // Same as login: a new profile means new in-app / inbox targeting.
      await _cleverTap.fetchInApps();
      await _cleverTap.refreshInbox();

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An unknown error occurred during sign up.';
    } catch (e) {
      return 'Failed to sign up: $e';
    }
  }

  /// Builds the identification payload for [CleverTapPlugin.onUserLogin].
  ///
  /// Every identity field the app knows about must be passed here in one call.
  /// Identity fields sent separately via profileSet land on whatever profile is
  /// currently active and merge that user with this one — which is why Phone is
  /// included here rather than pushed from the login screen afterwards.
  Map<String, dynamic> _buildProfile(String email, String? phone) {
    final profile = <String, dynamic>{
      'Identity': email,
      'Email': email,
      'Name': email.split('@')[0],
      'MSG-push': true,  // Opt-in to push notifications
      'MSG-email': true, // Opt-in to email channel (required for CleverTap email delivery)
    };

    if (phone != null && phone.trim().isNotEmpty) {
      var normalized = phone.trim();
      // CleverTap requires E.164, i.e. a leading country code.
      if (!normalized.startsWith('+')) normalized = '+91$normalized';
      profile['Phone'] = normalized;
      profile['MSG-sms'] = true;
    }

    return profile;
  }

  Future<void> logout() async {
    // Record the event while the profile is still identified, so it is
    // attributed to the user who actually logged out rather than to whatever
    // profile is active afterwards.
    _analyticsService.logout();

    // Sign out of Firebase — this clears the local persisted session,
    // so the next cold-start will correctly route to the login screen.
    await _auth.signOut();

    // Clear the Identity key so that any subsequent anonymous events are not
    // attributed to the signed-out user's profile.
    //
    // NOTE: this mutates the stored profile rather than un-identifying the
    // device, and CleverTap exposes no SDK-side logout. If it takes effect it
    // deletes Identity from that user's real profile; if identity fields are
    // protected it is a no-op and anonymous events still land on them. Either
    // way the next onUserLogin is what actually switches profiles. Verify on
    // the dashboard before relying on this.
    CleverTapPlugin.profileRemoveValueForKey('Identity');
  }
}
