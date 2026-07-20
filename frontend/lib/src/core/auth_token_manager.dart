import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import './config.dart';

class AuthTokenManager {
  static String? _cachedToken;
  static DateTime? _expiry;

  static Future<String?> getSupabaseToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cachedToken = null;
      _expiry = null;
      return null;
    }

    // If we have a cached token that is valid for at least 5 more minutes, return it
    if (_cachedToken != null &&
        _expiry != null &&
        _expiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return _cachedToken;
    }

    try {
      debugPrint('FUTA AuthManager: Fetching Firebase ID token...');
      final idToken = await user.getIdToken(true); // Force refresh to be safe
      if (idToken == null) return null;

      debugPrint('FUTA AuthManager: Exchanging Firebase token for Supabase JWT...');
      final dioClient = Dio(BaseOptions(baseUrl: Config.backendUrl));
      final authRes = await dioClient.post(
        '/api/v1/auth/token-exchange',
        data: {'firebase_token': idToken},
      );
      final supabaseToken = authRes.data['supabase_token'] as String;

      _cachedToken = supabaseToken;
      // Tokens are valid for 24 hours (86400 seconds)
      _expiry = DateTime.now().add(const Duration(hours: 23));
      debugPrint('FUTA AuthManager: Token exchange success. Caching token.');

      return supabaseToken;
    } catch (e) {
      debugPrint('FUTA AuthManager ERROR: Failed to exchange token: $e');
      return _cachedToken; // Fallback to last known token if offline/error
    }
  }

  static void clear() {
    _cachedToken = null;
    _expiry = null;
    debugPrint('FUTA AuthManager: Cached session cleared.');
  }
}
