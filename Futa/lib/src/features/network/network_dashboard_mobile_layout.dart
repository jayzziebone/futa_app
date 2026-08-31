import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import '../school/school_dashboard_shared_widgets.dart';

class NetworkDashboardMobileLayout extends StatelessWidget {
  final String networkId;
  final String networkName;
  final String networkCode;
  final String adminName;
  final String adminPhone;
  final String address;

  final int totalSchoolsCount;
  final int totalStudentsCount;
  final double totalAmountCollected;
  final double totalAmountToPerceive;
  final double recoveryRate;

  final List<Map<String, dynamic>> schools;
  final List<Map<String, dynamic>> filteredSchools;
  final Map<String, double> monthlyRevenues;

  final TextEditingController searchController;
  final int currentTab;
  final ValueChanged<int> onTabChanged;
  final Future<void> Function() onRefresh;
  final Function(String schoolId, String schoolName) onInspectSchool;
  final VoidCallback onLogout;

  const NetworkDashboardMobileLayout({
    super.key,
    required this.networkId,
    required this.networkName,
    required this.networkCode,
    required this.adminName,
    required this.adminPhone,
    required this.address,
    required this.totalSchoolsCount,
    required this.totalStudentsCount,
    required this.totalAmountCollected,
    required this.totalAmountToPerceive,
    required this.recoveryRate,
    required this.schools,
    required this.filteredSchools,
    required this.monthlyRevenues,
    required this.searchController,
    required this.currentTab,
    required this.onTabChanged,
    required this.onRefresh,
    required this.onInspectSchool,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FutaTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: FutaTheme.blueDark,
          child: _buildTabContent(context),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentTab,
          onTap: onTabChanged,
          backgroundColor: Colors.white,
          selectedItemColor: FutaTheme.blueDark,
          unselectedItemColor: FutaTheme.textLight,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Vue Réseau',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_tree_outlined),
              activeIcon: Icon(Icons.account_tree_rounded),
              label: 'Écoles',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.domain_verification_outlined),
              activeIcon: Icon(Icons.domain_verification_rounded),
              label: 'Profil Réseau',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    switch (currentTab) {
      case 0:
        return _buildOverviewTab(context);
      case 1:
        return _buildSchoolsTab(context);
      case 2:
        return _buildProfileTab(context);
      default:
        return _buildOverviewTab(context);
    }
  }

  // TAB 0: VUE D'ENSEMBLE
  Widget _buildOverviewTab(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'fr_FR');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        // 1. Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Coordination Réseau',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: FutaTheme.textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Supervision académique & financière',
                  style: TextStyle(
                    fontSize: 12,
                    color: FutaTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (networkCode.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hub_rounded, size: 13, color: FutaTheme.blueDark),
                    const SizedBox(width: 5),
                    Text(
                      networkCode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: FutaTheme.blueDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Hero Card Réseau
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1B4B),
                FutaTheme.blueDark,
                Color(0xFF2E38A8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: FutaTheme.blueDark.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                networkName.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: FutaTheme.emeraldGreen, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Coordination Nationale & Faîtière',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Mini Metric Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildHeroMetric('$totalSchoolsCount', 'Écoles Membres'),
                    Container(height: 24, width: 1, color: Colors.white24),
                    _buildHeroMetric('$totalStudentsCount', 'Élèves Inscrits'),
                    Container(height: 24, width: 1, color: Colors.white24),
                    _buildHeroMetric('${recoveryRate.toStringAsFixed(1)}%', 'Recouvrement'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Bento Grid Stats
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                title: 'ÉCOLES GÉRÉES',
                value: '$totalSchoolsCount',
                subtitle: 'Établissements actifs',
                icon: Icons.school_rounded,
                accentColor: FutaTheme.blueDark,
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoCard(
                title: 'EFFECTIF GLOBAL',
                value: '$totalStudentsCount',
                subtitle: 'Élèves sous réseau',
                icon: Icons.people_alt_rounded,
                accentColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFF0FDFA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                title: 'REVENUS PERÇUS',
                value: '${currencyFormat.format(totalAmountCollected)} FC',
                subtitle: 'Frais perçus réseau',
                icon: Icons.payments_rounded,
                accentColor: FutaTheme.success,
                bgColor: const Color(0xFFF0FDF4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoCard(
                title: 'RECOUVREMENT',
                value: '${recoveryRate.toStringAsFixed(1)}%',
                subtitle: 'Taux consolidé',
                icon: Icons.pie_chart_rounded,
                accentColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Quick Schools List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Établissements sous Juridiction',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: FutaTheme.textDark,
              ),
            ),
            TextButton(
              onPressed: () => onTabChanged(1),
              child: const Text('Tout afficher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 5. Quick Top Schools List
        if (schools.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: const Center(
              child: Text(
                'Aucune école rattachée pour le moment.\nLes écoles utilisant votre code réseau apparaîtront ici automatiquement.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FutaTheme.textLight, fontSize: 12, height: 1.5),
              ),
            ),
          )
        else
          ...schools.take(4).map((school) => _buildSchoolCard(context, school, currencyFormat)),

        const SizedBox(height: 24),
      ],
    );
  }

  // TAB 1: ÉCOLES DU RÉSEAU (DIRECTORY & DRILL-DOWN)
  Widget _buildSchoolsTab(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'fr_FR');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Répertoire des Écoles',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: FutaTheme.textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${schools.length} établissements rattachés au réseau',
                  style: TextStyle(
                    fontSize: 12,
                    color: FutaTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Search Bar
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher une école, un code ou une ville...',
            prefixIcon: const Icon(Icons.search, size: 20, color: FutaTheme.textLight),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (filteredSchools.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: const Center(
              child: Text(
                'Aucun établissement ne correspond à votre recherche.',
                style: TextStyle(color: FutaTheme.textLight, fontSize: 13),
              ),
            ),
          )
        else
          ...filteredSchools.map((school) => _buildSchoolCard(context, school, currencyFormat)),

        const SizedBox(height: 24),
      ],
    );
  }

  // TAB 2: PROFIL RÉSEAU
  Widget _buildProfileTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      children: [
        const Text(
          'Profil Réseau & Coordination',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: FutaTheme.textDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Identifiants d\'agrégation & contact officiel',
          style: TextStyle(fontSize: 12, color: FutaTheme.textLight),
        ),
        const SizedBox(height: 18),

        // Network Profile Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), FutaTheme.blueDark],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.hub_rounded, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          networkName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: FutaTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Compte Agrégateur Homologué',
                          style: TextStyle(fontSize: 11, color: FutaTheme.textLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 16),

              // Code Réseau with Copy
              const Text(
                'CODE RÉSEAU (POUR RATTACHEMENT DES ÉCOLES)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: FutaTheme.textLight,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      networkCode.isNotEmpty ? networkCode : 'NON DÉFINI',
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: FutaTheme.blueDark,
                        letterSpacing: 1.5,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: networkCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Code réseau copié : $networkCode')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: FutaTheme.blueDark),
                            SizedBox(width: 4),
                            Text('Copier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FutaTheme.blueDark)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info rows
              _buildDetailItem(Icons.person_outline, 'Coordinateur / Responsable', adminName),
              const SizedBox(height: 12),
              _buildDetailItem(Icons.phone_iphone_rounded, 'Téléphone de contact', adminPhone),
              const SizedBox(height: 12),
              _buildDetailItem(Icons.location_on_outlined, 'Siège administratif', address.isNotEmpty ? address : 'Kinshasa, RD Congo'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Logout Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFEE2E2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.logout_rounded, color: FutaTheme.error, size: 20),
                  SizedBox(width: 12),
                  Text('Déconnexion de la session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FutaTheme.textDark)),
                ],
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onLogout,
                child: const Text('Quitter', style: TextStyle(color: FutaTheme.error, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // WIDGET HELPERS
  Widget _buildHeroMetric(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: FutaTheme.textLight,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: FutaTheme.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: FutaTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolCard(BuildContext context, Map<String, dynamic> school, NumberFormat currencyFormat) {
    final schoolId = school['school_id'] ?? school['id'] ?? '';
    final schoolName = school['school_name'] ?? 'Établissement';
    final inviteCode = school['invite_code'] ?? '';
    final studentsCount = (school['students_count'] as num?)?.toInt() ?? 0;
    final collected = (school['amount_collected'] as num?)?.toDouble() ?? 0.0;
    final recovery = (school['recovery_rate'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: FutaTheme.blueDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: FutaTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (inviteCode.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              inviteCode,
                              style: const TextStyle(fontFamily: 'Courier', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '$studentsCount élèves',
                          style: const TextStyle(fontSize: 11, color: FutaTheme.textLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Recovery Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: recovery >= 75 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${recovery.toStringAsFixed(0)}% recouvré',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: recovery >= 75 ? const Color(0xFF166534) : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frais Scolaires Perçus', style: TextStyle(fontSize: 10, color: FutaTheme.textLight)),
                  const SizedBox(height: 2),
                  Text(
                    '${currencyFormat.format(collected)} FC',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: FutaTheme.textDark),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FutaTheme.blueDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => onInspectSchool(schoolId, schoolName),
                icon: const Icon(Icons.remove_red_eye_rounded, size: 14),
                label: const Text(
                  'Inspecter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: FutaTheme.textLight),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: FutaTheme.textLight, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: FutaTheme.textDark),
        ),
      ],
    );
  }
}
