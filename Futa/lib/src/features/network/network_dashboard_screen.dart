import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart' as dio;
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/theme.dart';
import '../../core/config.dart';
import '../../core/widgets/skeleton_shimmer.dart';
import '../../core/auth_token_manager.dart';
import './network_dashboard_mobile_layout.dart';
import './network_dashboard_web_layout.dart';

class NetworkDashboardScreen extends StatefulWidget {
  const NetworkDashboardScreen({super.key});

  @override
  State<NetworkDashboardScreen> createState() => _NetworkDashboardScreenState();
}

class _NetworkDashboardScreenState extends State<NetworkDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Network Identity
  String _networkId = '';
  String _networkName = 'Réseau Scolaire';
  String _networkCode = '';
  String _adminName = 'Coordinateur Principal';
  String _adminPhone = '';
  String _address = '';

  // Network Aggregated Metrics
  int _totalSchoolsCount = 0;
  int _totalStudentsCount = 0;
  double _totalAmountCollected = 0.0;
  double _totalAmountToPerceive = 0.0;
  double _recoveryRate = 0.0;

  // Member Schools Breakdown
  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _filteredSchools = [];
  Map<String, double> _monthlyRevenues = {};

  final _searchController = TextEditingController();
  int _currentTab = 0;

  final _dio = dio.Dio(dio.BaseOptions(
    baseUrl: Config.backendUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  void initState() {
    super.initState();
    _loadNetworkData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSchools = List.from(_schools);
      } else {
        _filteredSchools = _schools.where((s) {
          final name = (s['school_name'] ?? '').toString().toLowerCase();
          final code = (s['invite_code'] ?? '').toString().toLowerCase();
          final address = (s['address'] ?? '').toString().toLowerCase();
          return name.contains(query) || code.contains(query) || address.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadNetworkData({bool showFullScreenLoading = true}) async {
    if (showFullScreenLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Aucune session active trouvée. Veuillez vous reconnecter.");
      }
      final uid = user.uid;

      // 1. Ensure valid Supabase session
      await AuthTokenManager.applySupabaseHeaders();

      // 2. Try fetching full consolidated network overview from FastAPI backend
      bool backendSucceeded = false;
      try {
        final token = await user.getIdToken();
        final response = await _dio.get(
          '/api/v1/network/overview',
          options: dio.Options(
            headers: {'Authorization': 'Bearer $token'},
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final net = data['network'] as Map<String, dynamic>? ?? {};
          final sum = data['summary'] as Map<String, dynamic>? ?? {};
          final schoolsList = List<Map<String, dynamic>>.from(data['schools'] ?? []);
          final monthlyRaw = data['monthly_revenues'] as Map<String, dynamic>? ?? {};

          _networkId = net['id'] ?? uid;
          _networkName = net['name'] ?? 'Réseau Scolaire';
          _networkCode = net['network_code'] ?? '';
          _adminName = net['admin_name'] ?? (user.displayName ?? 'Coordinateur');
          _adminPhone = net['phone_number'] ?? (user.phoneNumber ?? '');
          _address = net['address'] ?? '';

          _totalSchoolsCount = (sum['total_schools_count'] as num?)?.toInt() ?? schoolsList.length;
          _totalStudentsCount = (sum['total_students_count'] as num?)?.toInt() ?? 0;
          _totalAmountCollected = (sum['total_amount_collected'] as num?)?.toDouble() ?? 0.0;
          _totalAmountToPerceive = (sum['total_amount_to_perceive'] as num?)?.toDouble() ?? 0.0;
          _recoveryRate = (sum['recovery_rate'] as num?)?.toDouble() ?? 0.0;

          _schools = schoolsList;
          _filteredSchools = List.from(_schools);

          _monthlyRevenues = monthlyRaw.map((k, v) => MapEntry(k, (v as num).toDouble()));
          backendSucceeded = true;
        }
      } catch (backendErr) {
        debugPrint('Network overview API fallback to Supabase: $backendErr');
      }

      // 3. Fallback direct to Supabase if backend was unreachable
      if (!backendSucceeded) {
        final netRes = await Supabase.instance.client
            .from('school_networks')
            .select('*')
            .eq('id', uid)
            .maybeSingle();

        if (netRes != null) {
          _networkId = netRes['id'] ?? uid;
          _networkName = netRes['name'] ?? 'Réseau Scolaire';
          _networkCode = netRes['network_code'] ?? '';
          _adminName = netRes['admin_name'] ?? (user.displayName ?? 'Coordinateur');
          _adminPhone = netRes['phone_number'] ?? (user.phoneNumber ?? '');
          _address = netRes['address'] ?? '';

          // Fetch member schools
          final schoolsRes = await Supabase.instance.client
              .from('school_profiles')
              .select('id, school_name, address, phone_number, invite_code')
              .eq('network_id', _networkId);

          final memberSchools = List<Map<String, dynamic>>.from(schoolsRes);
          _totalSchoolsCount = memberSchools.length;
          _schools = memberSchools;
          _filteredSchools = List.from(_schools);
        }
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('Firebase sign out failed: $e');
    }
    if (mounted) {
      context.go('/login');
    }
  }

  void _inspectSchool(String schoolId, String schoolName) {
    // Navigate to School Dashboard with schoolId override
    context.push('/school?networkSchoolId=$schoolId&networkSchoolName=${Uri.encodeComponent(schoolName)}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final isWeb = MediaQuery.of(context).size.width >= 900;
      return Scaffold(
        backgroundColor: FutaTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const SkeletonBox(width: 180, height: 20),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonDashboardMetrics(count: 4, isWeb: isWeb),
              const SizedBox(height: 28),
              const SkeletonBox(width: 180, height: 20),
              const SizedBox(height: 14),
              const SkeletonTableRows(rowCount: 5),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: FutaTheme.backgroundLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: FutaTheme.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: FutaTheme.textDark, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadNetworkData,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return NetworkDashboardWebLayout(
            networkId: _networkId,
            networkName: _networkName,
            networkCode: _networkCode,
            adminName: _adminName,
            adminPhone: _adminPhone,
            address: _address,
            totalSchoolsCount: _totalSchoolsCount,
            totalStudentsCount: _totalStudentsCount,
            totalAmountCollected: _totalAmountCollected,
            totalAmountToPerceive: _totalAmountToPerceive,
            recoveryRate: _recoveryRate,
            schools: _schools,
            filteredSchools: _filteredSchools,
            monthlyRevenues: _monthlyRevenues,
            searchController: _searchController,
            currentTab: _currentTab,
            onTabChanged: (index) => setState(() => _currentTab = index),
            onRefresh: () => _loadNetworkData(showFullScreenLoading: false),
            onInspectSchool: _inspectSchool,
            onLogout: _logout,
          );
        } else {
          return NetworkDashboardMobileLayout(
            networkId: _networkId,
            networkName: _networkName,
            networkCode: _networkCode,
            adminName: _adminName,
            adminPhone: _adminPhone,
            address: _address,
            totalSchoolsCount: _totalSchoolsCount,
            totalStudentsCount: _totalStudentsCount,
            totalAmountCollected: _totalAmountCollected,
            totalAmountToPerceive: _totalAmountToPerceive,
            recoveryRate: _recoveryRate,
            schools: _schools,
            filteredSchools: _filteredSchools,
            monthlyRevenues: _monthlyRevenues,
            searchController: _searchController,
            currentTab: _currentTab,
            onTabChanged: (index) => setState(() => _currentTab = index),
            onRefresh: () => _loadNetworkData(showFullScreenLoading: false),
            onInspectSchool: _inspectSchool,
            onLogout: _logout,
          );
        }
      },
    );
  }
}
