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

  /// Set to true by login()/signup() BEFORE triggering signIn so the auth
  /// listener knows the session event is from an active login action — not a
  /// cold-start restore — and skips the re-identification call (login/signup
  /// call onUserLogin themselves immediately after).
  bool _isLoggingIn = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get email => _email;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        _isAuthenticated = true;
        _email = user.email;
        StorageService.setString('user_email', user.email!);

        if (_isLoggingIn) {
          // Active login/signup flow: login()/signup() call onUserLogin
          // themselves right after signIn completes, so we skip it here to
          // avoid a double identification call on the same event loop tick.
          _isLoggingIn = false;
        } else {
          // ── App-start / update re-identification ─────────────────────────
          // Audit fix: CleverTap docs require onUserLogin to run whenever a
          // previously-logged-in user opens the app (including after an update)
          // so the SDK re-associates the device with the correct profile.
          //
          // We only have Email at this point (Firebase persists it); Phone was
          // not stored separately, so we omit it here — the profile on the
          // CleverTap side already has it from the original login call.
          //
          // https://developer.clevertap.com/docs/concepts-user-profiles
          CleverTapPlugin.onUserLogin({
            'Identity': user.email!,
            'Email':    user.email!,
            'Name':     user.email!.split('@')[0],
            'MSG-push':  true,
            'MSG-email': true,
          });

          // Re-fetch in-app campaigns and inbox for this profile (same as
          // login/signup — the SDK may have rotated to an anonymous profile
          // between sessions if the app was cleared from memory).
          await _cleverTap.fetchInApps();
          await _cleverTap.refreshInbox();
        }

        // Always re-assert channel opt-ins (safe with profileSet since these
        // are not identity fields and cannot trigger profile merges).
        CleverTapPlugin.profileSet({
          'MSG-email': true,
          'MSG-push':  true,
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
      // Guard the auth listener so it skips the re-identification path —
      // we call onUserLogin ourselves below after the credential resolves.
      _isLoggingIn = true;
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
      _isLoggingIn = false; // login failed — reset so next app-start re-identifies
      return e.message ?? 'An unknown authentication error occurred.';
    } catch (e) {
      _isLoggingIn = false;
      return 'Failed to log in: $e';
    }
  }

  Future<String?> signup(String email, String password, {String? phone}) async {
    try {
      // Same guard as login() — prevents a double onUserLogin call.
      _isLoggingIn = true;
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
      _isLoggingIn = false; // signup failed — reset so next app-start re-identifies
      return e.message ?? 'An unknown error occurred during sign up.';
    } catch (e) {
      _isLoggingIn = false;
      return 'Failed to sign up: $e';
    }
  }

  /// Builds the identification payload for [CleverTapPlugin.onUserLogin].
  ///
  /// Every identity field the app knows about must be passed here in one call.
  /// Identity fields sent separately via profileSet land on whatever profile is
  /// currently active and merge that user with this one, so every identity field
  /// must be passed in this single call.
  ///
  /// Phone is included here for ordering rather than merge safety: it is not
  /// configured as an identity field in this CleverTap project, so pushing it
  /// separately was not merging profiles. Sending it with the identification
  /// call still avoids a second round trip and a window where the profile has an
  /// email but no number. Promote it in the dashboard and it is already correct.
  Map<String, dynamic> _buildProfile(String email, String? phone) {
    final profile = <String, dynamic>{
      'Identity': email,
      'Email': email,
      'Name': email.split('@')[0],
      'MSG-push': true,  // Opt-in to push notifications
      'MSG-email': true, // Opt-in to email channel (required for CleverTap email delivery)
    };

    if (phone != null && phone.trim().isNotEmpty) {
      final normalized = _toE164India(phone.trim());
      if (normalized != null) {
        profile['Phone'] = normalized;
        profile['MSG-sms'] = true;
      }
    }

    return profile;
  }

  /// Normalises a raw phone string to E.164 for India (+91XXXXXXXXXX).
  ///
  /// Handles the three common input formats:
  ///   - 10 digits            : 9876543210   → +919876543210  ✓
  ///   - 91 + 10 digits       : 919876543210 → +919876543210  ✓  (was broken: produced +91919…)
  ///   - Already E.164        : +919876543210 → +919876543210 ✓
  ///
  /// Returns null if the result is not a valid 13-char E.164 Indian number,
  /// so the caller can skip pushing a bad phone value to CleverTap.
  String? _toE164India(String raw) {
    // Strip all non-digit characters except a leading +
    final digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');

    String e164;
    if (raw.startsWith('+')) {
      // Already has a + — trust whatever follows; just re-attach the +
      e164 = '+$digitsOnly';
    } else if (digitsOnly.startsWith('91') && digitsOnly.length == 12) {
      // Country code present but no + (e.g. 919876543210)
      e164 = '+$digitsOnly';
    } else if (digitsOnly.length == 10) {
      // Local 10-digit number — prepend India country code
      e164 = '+91$digitsOnly';
    } else {
      // Unrecognised format — skip rather than push garbage
      return null;
    }

    // Final sanity check: E.164 Indian number must be exactly +91XXXXXXXXXX (13 chars)
    if (!RegExp(r'^\+91[6-9]\d{9}$').hasMatch(e164)) return null;
    return e164;
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
