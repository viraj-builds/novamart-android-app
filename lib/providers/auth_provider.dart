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
        // This ensures MSG-email is always set on the NAMED profile, not an
        // anonymous one (which has no Email address and cannot receive emails).
        CleverTapPlugin.profileSet({
          'Email': user.email!,         // Ensure email is always on the profile
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

  Future<String?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _analyticsService.login(credential.user!.uid, email);
      
      var profile = {
        'Identity': email,
        'Email': email,
        'Name': email.split('@')[0],
        'MSG-push': true,  // Opt-in to push notifications
        'MSG-email': true, // Opt-in to email channel (required for CleverTap email delivery)
      };
      CleverTapPlugin.onUserLogin(profile);
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

  Future<String?> signup(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _analyticsService.login(credential.user!.uid, email);

      var profile = {
        'Identity': email,
        'Email': email,
        'Name': email.split('@')[0],
        'MSG-push': true,  // Opt-in to push notifications
        'MSG-email': true, // Opt-in to email channel (required for CleverTap email delivery)
      };
      CleverTapPlugin.onUserLogin(profile);
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

  Future<void> logout() async {
    await _auth.signOut();
    _analyticsService.logout();
  }
}
