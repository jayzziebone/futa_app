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
    // Show splash logo for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    try {
      // Restore authenticated Supabase session using the Firebase ID token directly
      final idToken = await user.getIdToken();
      if (idToken != null) {
        Supabase.instance.client.rest.headers['Authorization'] = 'Bearer $idToken';
        try {
          Supabase.instance.client.storage.headers['Authorization'] = 'Bearer $idToken';
        } catch (_) {}
      }

      var response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.uid)
          .maybeSingle();

      String role = 'client';
      String subRole = 'parent';

      if (response != null) {
        role = response['role'] ?? 'client';
        subRole = response['sub_role'] ?? 'parent';
      } else {
        // Check school profiles
        final schoolProfile = await Supabase.instance.client
            .from('school_profiles')
            .select()
            .eq('id', user.uid)
            .maybeSingle();
        if (schoolProfile != null) {
          role = 'admin';
          subRole = 'school';
          response = schoolProfile;
        } else {
          // Check merchant profiles
          final merchantProfile = await Supabase.instance.client
              .from('merchant_profiles')
              .select()
              .eq('id', user.uid)
              .maybeSingle();
          if (merchantProfile != null) {
            role = 'admin';
            subRole = 'merchant';
            response = merchantProfile;
          }
        }
      }

      if (!mounted) return;

      if (response != null) {
        if (subRole == 'merchant') {
          context.go('/merchant');
        } else if (role == 'admin' || subRole == 'school') {
          context.go('/school');
        } else {
          context.go('/parent');
        }
      } else {
        context.go('/register');
      }
    } catch (e) {
      if (mounted) {
        context.go('/login');
      }
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
