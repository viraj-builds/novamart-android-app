import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Show splash for at least 2 seconds, AND wait for Firebase to restore
    // the persisted auth session from disk. Both must complete before we route.
    // Using authStateChanges().first is the correct way — it resolves as soon
    // as Firebase emits the first event (null = no session, User = has session),
    // which avoids the race condition of a fixed delay.
    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      FirebaseAuth.instance.authStateChanges().first,
    ]);

    if (!mounted) return;

    final user = results[1] as User?;
    if (user != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_basketball, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              'NovaMart',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
