import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../services/clevertap_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// True while a request is in flight: shows a spinner and ignores repeat
  /// taps, which used to fire several sign-in calls at once.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Hold in-apps while the user is logging in or signing up (the sign-up
    // screen is pushed on top of this one). A campaign shown here sits over
    // the form - a footer in-app covers the "Sign Up" link and buttons - and
    // swallows taps. Anything triggered meanwhile is queued and shown once
    // auth succeeds. https://developer.clevertap.com/docs/flutter-in-app
    // After the first frame: the service notifies listeners, which must not
    // happen while the tree is still being built.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => CleverTapService.instance.suspendInAppNotifications());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      setState(() => _submitting = true);
      // Phone goes through login() so it reaches CleverTap inside the single
      // onUserLogin call, rather than as a follow-up profileSet.
      final error = await Provider.of<AuthProvider>(context, listen: false)
          .login(
        _emailController.text,
        _passwordController.text,
        phone: _phoneController.text,
      );

      if (!mounted) return;
      setState(() => _submitting = false);
      if (error == null) {
        CleverTapService.instance.resumeInAppNotifications();
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.sports_basketball, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                Text(
                  'NovaMart',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty || !v.contains('@') || v.contains(' ')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+91 ',
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _submitting ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.pushNamed(context, AppRoutes.signup),
                  child: const Text("Don't have an account? Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
