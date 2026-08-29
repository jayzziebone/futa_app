import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../../core/config.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      // 1. Fast-path: Check cached role if available
      final cachedRole = AuthTokenManager.cachedRole;
      final cachedSubRole = AuthTokenManager.cachedSubRole;
      if (cachedRole != null && mounted) {
        _navigateByRole(cachedRole, cachedSubRole ?? 'parent');
        return;
      }

      // 2. Fetch session and role via token exchange in a single call
      final session = await AuthTokenManager.getSessionInfo();
      if (!mounted) return;

      if (session != null) {
        // Set Supabase headers
        Supabase.instance.client.rest.headers['Authorization'] = 'Bearer ${session.supabaseToken}';
        try {
          Supabase.instance.client.storage.headers['Authorization'] = 'Bearer ${session.supabaseToken}';
        } catch (_) {}

        _navigateByRole(session.role, session.subRole);
      } else {
        context.go('/login');
      }
    } catch (e) {
      debugPrint('FUTA Splash Auth check failed: $e');
      if (mounted) context.go('/login');
    }
  }

  void _navigateByRole(String role, String subRole) {
    if (subRole == 'merchant') {
      context.go('/merchant');
    } else if (role == 'admin' || subRole == 'school') {
      context.go('/school');
    } else {
      context.go('/parent');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Hero(
              tag: 'brand-logo',
              child: Image.asset(
                'assets/futa_new_logo.png',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  // Graceful fallback to colored circle if assets fail to render
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      color: FutaTheme.blueDark,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          'FUTA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: FutaTheme.blueDark,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
