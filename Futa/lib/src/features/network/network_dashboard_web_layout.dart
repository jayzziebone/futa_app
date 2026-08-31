import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import '../school/school_dashboard_shared_widgets.dart';

class NetworkDashboardWebLayout extends StatelessWidget {
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

  const NetworkDashboardWebLayout({
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
    final currencyFormat = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // 1. Sidebar Navigation
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Network Logo Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FutaTheme.blueIndigo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.hub_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              networkCode.isNotEmpty ? networkCode : 'FUTA',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                            const Text(
                              'Coordination Réseau',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1E293B), height: 1),
                const SizedBox(height: 16),

                // Nav Items
                _buildSidebarItem(0, Icons.dashboard_rounded, 'Vue Consolidée'),
                _buildSidebarItem(1, Icons.school_rounded, 'Écoles sous Juridiction'),
                _buildSidebarItem(2, Icons.domain_verification_rounded, 'Profil & Identifiants'),

                const Spacer(),

                // User Capsule
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: FutaTheme.blueIndigo,
                          child: Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                adminName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text('Coordinateur', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Color(0xFF94A3B8), size: 18),
                          onPressed: onLogout,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        networkName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: FutaTheme.textDark,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: FutaTheme.textLight),
                            onPressed: onRefresh,
                          ),
                          const SizedBox(width: 12),
                          if (networkCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDBEAFE)),
                              ),
                              child: Text(
                                'Code Réseau : $networkCode',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: FutaTheme.blueDark),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Body Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bento Metrics Grid
                        Row(
                          children: [
                            Expanded(child: _buildWebBentoCard('ÉCOLES DU RÉSEAU', '$totalSchoolsCount', 'Établissements membres', Icons.school_rounded, FutaTheme.blueDark, const Color(0xFFEFF6FF))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildWebBentoCard('EFFECTIF GLOBAL', '$totalStudentsCount', 'Élèves inscrits', Icons.people_rounded, const Color(0xFF0D9488), const Color(0xFFF0FDFA))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildWebBentoCard('REVENUS PERÇUS', '${currencyFormat.format(totalAmountCollected)} FC', 'Frais recouvrés', Icons.payments_rounded, FutaTheme.success, const Color(0xFFF0FDF4))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildWebBentoCard('TAUX RECOUVREMENT', '${recoveryRate.toStringAsFixed(1)}%', 'Performance globale', Icons.pie_chart_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF))),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Schools Table & Drill-Down
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Établissements sous Juridiction & Performance',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: FutaTheme.textDark),
                                  ),
                                  SizedBox(
                                    width: 320,
                                    child: TextField(
                                      controller: searchController,
                                      decoration: InputDecoration(
                                        hintText: 'Rechercher une école...',
                                        prefixIcon: const Icon(Icons.search, size: 18),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              if (filteredSchools.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(
                                    child: Text(
                                      'Aucun établissement trouvé.',
                                      style: TextStyle(color: FutaTheme.textLight),
                                    ),
                                  ),
                                )
                              else
                                Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2.5),
                                    1: FlexColumnWidth(1.2),
                                    2: FlexColumnWidth(1.2),
                                    3: FlexColumnWidth(1.8),
                                    4: FlexColumnWidth(1.4),
                                    5: FlexColumnWidth(1.5),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                      ),
                                      children: [
                                        _buildTableHeader('ÉCOLE'),
                                        _buildTableHeader('CODE INVITATION'),
                                        _buildTableHeader('EFFECTIF'),
                                        _buildTableHeader('FRAIS PERÇUS'),
                                        _buildTableHeader('RECOUVREMENT'),
                                        _buildTableHeader('ACTION'),
                                      ],
                                    ),
                                    ...filteredSchools.map((school) {
                                      final sId = school['school_id'] ?? school['id'] ?? '';
                                      final sName = school['school_name'] ?? 'Établissement';
                                      final sCode = school['invite_code'] ?? '-';
                                      final sCount = (school['students_count'] as num?)?.toInt() ?? 0;
                                      final sCol = (school['amount_collected'] as num?)?.toDouble() ?? 0.0;
                                      final sRec = (school['recovery_rate'] as num?)?.toDouble() ?? 0.0;

                                      return TableRow(
                                        decoration: const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FutaTheme.textDark)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text(sCode, style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text('$sCount élèves', style: const TextStyle(fontSize: 13, color: FutaTheme.textLight)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text('${currencyFormat.format(sCol)} FC', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FutaTheme.textDark)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text('${sRec.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: sRec >= 75 ? FutaTheme.success : const Color(0xFFD97706))),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: FutaTheme.blueDark,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  elevation: 0,
                                                ),
                                                onPressed: () => onInspectSchool(sId, sName),
                                                icon: const Icon(Icons.remove_red_eye, size: 14),
                                                label: const Text('Inspecter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = currentTab == index;
    return InkWell(
      onTap: () => onTabChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? FutaTheme.emeraldGreen : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebBentoCard(String title, String value, String subtitle, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FutaTheme.textLight, letterSpacing: 0.8)),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: FutaTheme.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: FutaTheme.textLight)),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FutaTheme.textLight, letterSpacing: 0.8),
      ),
    );
  }
}
