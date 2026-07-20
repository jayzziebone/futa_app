import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/registration_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/parent/parent_dashboard_screen.dart';
import '../features/school/school_dashboard_screen.dart';
import '../features/student/student_detail_screen.dart';
import '../features/merchant/merchant_dashboard_screen.dart';
import '../features/merchant/create_contract_screen.dart';
import '../features/contract/contract_detail_screen.dart';
import '../features/parent/archive_payments_screen.dart';

// Riverpod provider for the GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/parent',
        name: 'parent',
        builder: (context, state) => const ParentDashboardScreen(),
      ),
      GoRoute(
        path: '/school',
        name: 'school',
        builder: (context, state) => const SchoolDashboardScreen(),
      ),
      GoRoute(
        path: '/merchant',
        name: 'merchant',
        builder: (context, state) => const MerchantDashboardScreen(),
      ),
      GoRoute(
        path: '/create-contract',
        name: 'create_contract',
        builder: (context, state) => const CreateContractScreen(),
      ),
      GoRoute(
        path: '/student-detail/:studentId',
        name: 'student_detail',
        builder: (context, state) {
          final studentId = state.pathParameters['studentId'] ?? '';
          return StudentDetailScreen(studentId: studentId);
        },
      ),
      GoRoute(
        path: '/contract-detail/:contractId',
        name: 'contract_detail',
        builder: (context, state) {
          final contractId = state.pathParameters['contractId'] ?? '';
          final isMerchant = state.uri.queryParameters['isMerchant'] == 'true';
          return ContractDetailScreen(contractId: contractId, isMerchant: isMerchant);
        },
      ),
      GoRoute(
        path: '/archive-payments',
        name: 'archive_payments',
        builder: (context, state) => const ArchivePaymentsScreen(),
      ),
    ],
    onException: (context, state, router) {
      final location = state.uri.toString();
      if (location.contains('firebaseauth')) {
        // Redirige vers l'écran de login et ignore l'exception.
        // La vérification Firebase Auth se poursuit en tâche de fond côté natif.
        router.go('/login');
      } else {
        router.go('/');
      }
    },
    // Optional redirection logic based on auth session
    redirect: (context, state) {
      // Pour l'évaluation locale et le mode démo, on retourne null 
      // pour permettre la navigation sans session Supabase SMS réelle.
      return null;
    },
  );
});

