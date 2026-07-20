import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'src/core/theme.dart';
import 'src/core/router.dart';
import 'src/core/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Core for production user authentication
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBTXRv3aBvzQq5Xq_qczTmoghzOrOQjCEQ',
        authDomain: 'futa-1c8d8.firebaseapp.com',
        projectId: 'futa-1c8d8',
        storageBucket: 'futa-1c8d8.firebasestorage.app',
        messagingSenderId: '43008970087',
        appId: '1:43008970087:web:ea428d0985c5bb749333c2', // Web App ID from Firebase Console
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Initialize Supabase Client with credentials loaded from Config
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: FutaApp(),
    ),
  );
}

class FutaApp extends ConsumerWidget {
  const FutaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FUTA',
      debugShowCheckedModeBanner: false,
      theme: FutaTheme.lightTheme,
      routerConfig: router,
    );
  }
}
