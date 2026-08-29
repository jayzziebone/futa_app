import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import './config.dart';

class SessionInfo {
  final String supabaseToken;
  final String uid;
  final String phoneNumber;
  final String role;
  final String subRole;

  SessionInfo({
    required this.supabaseToken,
    required this.uid,
    required this.phoneNumber,
    required this.role,
    required this.subRole,
  });
}

class AuthTokenManager {
  static String? _cachedToken;
  static String? _cachedRole;
  static String? _cachedSubRole;
  static String? _cachedUid;
  static DateTime? _expiry;

  static String? get cachedRole => _cachedRole;
  static String? get cachedSubRole => _cachedSubRole;
  static String? get cachedUid => _cachedUid;

  static Future<SessionInfo?> getSessionInfo({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      clear();
      return null;
    }

    if (!forceRefresh &&
        _cachedToken != null &&
        _cachedRole != null &&
        _expiry != null &&
        _expiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return SessionInfo(
        supabaseToken: _cachedToken!,
        uid: _cachedUid ?? user.uid,
        phoneNumber: user.phoneNumber ?? '',
        role: _cachedRole!,
        subRole: _cachedSubRole ?? 'parent',
      );
    }

    try {
      final idToken = await user.getIdToken(forceRefresh);
      if (idToken == null) return null;

      final dioClient = Dio(BaseOptions(
        baseUrl: Config.backendUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));

      final authRes = await dioClient.post(
        '/api/v1/auth/token-exchange',
        data: {'firebase_token': idToken},
      );

      final data = authRes.data as Map<String, dynamic>;
      _cachedToken = data['supabase_token'] as String;
      _cachedRole = data['role'] as String? ?? 'client';
      _cachedSubRole = data['sub_role'] as String? ?? 'parent';
      _cachedUid = data['uid'] as String? ?? user.uid;
      _expiry = DateTime.now().add(const Duration(hours: 23));

      return SessionInfo(
        supabaseToken: _cachedToken!,
        uid: _cachedUid!,
        phoneNumber: data['phone_number'] as String? ?? user.phoneNumber ?? '',
        role: _cachedRole!,
        subRole: _cachedSubRole!,
      );
    } catch (e) {
      debugPrint('FUTA AuthManager: Token exchange fallback: $e');
      if (_cachedToken != null && _cachedRole != null) {
        return SessionInfo(
          supabaseToken: _cachedToken!,
          uid: _cachedUid ?? user.uid,
          phoneNumber: user.phoneNumber ?? '',
          role: _cachedRole!,
          subRole: _cachedSubRole ?? 'parent',
        );
      }
      return null;
    }
  }

  static Future<String?> getSupabaseToken() async {
    final session = await getSessionInfo();
    return session?.supabaseToken;
  }

  static void cacheRole(String role, String subRole, {String? uid}) {
    _cachedRole = role;
    _cachedSubRole = subRole;
    if (uid != null) _cachedUid = uid;
  }

  static void clear() {
    _cachedToken = null;
    _cachedRole = null;
    _cachedSubRole = null;
    _cachedUid = null;
    _expiry = null;
    debugPrint('FUTA AuthManager: Cached session cleared.');
  }
}

