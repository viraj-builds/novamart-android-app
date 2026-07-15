import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:clevertap_plugin/clevertap_plugin.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AnalyticsService _analyticsService = AnalyticsService();
  
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
        'MSG-push': true, // Automatically subscribe all users who log in
      };
      CleverTapPlugin.onUserLogin(profile);

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
        'MSG-push': true, // Automatically subscribe new signups
      };
      CleverTapPlugin.onUserLogin(profile);

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
