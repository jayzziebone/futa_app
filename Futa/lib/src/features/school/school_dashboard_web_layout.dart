import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import './school_dashboard_shared_widgets.dart';

class SchoolDashboardWebLayout extends StatelessWidget {
  final String schoolName;
  final bool isUploading;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> filteredStudents;
  final Map<String, dynamic>? selectedStudent;
  final List<Map<String, dynamic>> allInstallments;
  final String selectedPaymentFilter;
  final String selectedClassFilter;
  final int currentTab;
  final int totalStudentsCount;
  final int totalParentsCount;
  final int totalTeachersCount;
  final double totalAmountCollected;
  final double recoveryRate;

  final TextEditingController searchController;
  final TextEditingController cashAmountController;

  final VoidCallback onUploadRoster;
  final VoidCallback onApplyCashAdjustment;
  final VoidCallback onLogout;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<Map<String, dynamic>?> onSelectedStudentChanged;
  final ValueChanged<String> onSelectedPaymentFilterChanged;
  final ValueChanged<String> onSelectedClassFilterChanged;

  const SchoolDashboardWebLayout({
    super.key,
    required this.schoolName,
    required this.isUploading,
    required this.students,
    required this.filteredStudents,
    required this.selectedStudent,
    required this.allInstallments,
    required this.selectedPaymentFilter,
    required this.selectedClassFilter,
    required this.currentTab,
    required this.totalStudentsCount,
    required this.totalParentsCount,
    required this.totalTeachersCount,
    required this.totalAmountCollected,
    required this.recoveryRate,
    required this.searchController,
    required this.cashAmountController,
    required this.onUploadRoster,
    required this.onApplyCashAdjustment,
    required this.onLogout,
    required this.onTabChanged,
    required this.onSelectedStudentChanged,
    required this.onSelectedPaymentFilterChanged,
    required this.onSelectedClassFilterChanged,
  });

  List<String> _getPast6MonthsLabels() {
    final monthsFr = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    final now = DateTime.now();
    List<String> labels = [];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      labels.add(monthsFr[d.month - 1]);
    }
    return labels;
  }

  List<double> _getPast6MonthsRevenues() {
    final now = DateTime.now();
    List<double> values = List.filled(6, 0.0);
    for (int i = 5; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final targetYear = targetDate.year;
      final targetMonth = targetDate.month;

      double monthlySum = 0.0;
      for (var inst in allInstallments) {
        final double amountPaid = ((inst['amount_paid'] ?? inst['paid_amount'] ?? 0.0) as num).toDouble();
        final String? fallbackDate = amountPaid > 0 
            ? (inst['created_at'] ?? inst['due_date']) as String? 
            : inst['due_date'] as String?;
        final paidAtStr = (inst['paid_at'] ?? fallbackDate) as String?;
        if (paidAtStr == null) continue;
        try {
          final paidAt = DateTime.parse(paidAtStr);
          if (paidAt.year == targetYear && paidAt.month == targetMonth) {
            monthlySum += amountPaid;
          }
        } catch (_) {}
      }
      values[5 - i] = monthlySum;
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100 background
      body: Row(
        children: [
          _buildWebSidebar(context),
          Expanded(
            child: Column(
              children: [
                _buildWebTopHeader(),
                Expanded(child: _buildWebTabContent(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebar(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 74, 93, 139), // Slate 900
            Color(0xFF1E1B4B), // Indigo 950
            Color.fromARGB(255, 34, 47, 79), // Slate 900
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: FutaTheme.emeraldGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      schoolName.isNotEmpty ? schoolName.toUpperCase() : 'FUTA SCHOOL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Menu items
            _buildSidebarItem(context, 'Acceuil', Icons.dashboard_outlined, 0),
            _buildSidebarItem(context, 'Élèves', Icons.school, 1),
            _buildSidebarItem(context, 'Paiements', Icons.payment_outlined, 2),
            _buildSidebarItem(context, 'Enseignants', Icons.badge_outlined, 99),
            _buildSidebarItem(
              context,
              'Présences',
              Icons.calendar_today_outlined,
              99,
            ),
            _buildSidebarItem(context, 'Cours', Icons.book_outlined, 99),
            _buildSidebarItem(
              context,
              'Examens',
              Icons.assignment_outlined,
              99,
            ),

            const Spacer(),
            const Divider(color: Colors.white10),

            // Bottom items
            _buildSidebarItem(
              context,
              'Paramètres',
              Icons.settings_outlined,
              99,
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: onLogout,
                  leading: const Icon(
                    Icons.logout,
                    color: Colors.white70,
                    size: 20,
                  ),
                  title: const Text(
                    'Se déconnecter',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  dense: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    String title,
    IconData icon,
    int tabIndex,
  ) {
    final isSelected = currentTab == tabIndex;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          onTap: () {
            if (tabIndex == 99) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Ce module est en cours d'intégration dans la version de production FUTA.",
                  ),
                ),
              );
              return;
            }
            onTabChanged(tabIndex);
          },
          leading: Icon(
            icon,
            color: isSelected ? FutaTheme.blueDark : Colors.white70,
            size: 20,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? FutaTheme.blueDark : Colors.white70,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          dense: true,
        ),
      ),
    );
  }

  Widget _buildWebTopHeader() {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Search box
          // SizedBox(
          //   width: 320,
          //   height: 40,
          //   child: TextField(
          //     decoration: InputDecoration(
          //       prefixIcon: const Icon(Icons.search, size: 18, color: FutaTheme.textLight),
          //       hintText: 'Rechercher des élèves, enseignants, documents...',
          //       hintStyle: const TextStyle(fontSize: 13, color: FutaTheme.textLight),
          //       contentPadding: const EdgeInsets.symmetric(vertical: 0),
          //       filled: true,
          //       fillColor: const Color(0xFFF8FAFC),
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(8),
          //         borderSide: BorderSide.none,
          //       ),
          //     ),
          //   ),
          // ),

          // User Profile row
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none,
                  color: FutaTheme.textLight,
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Admin',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: FutaTheme.textDark,
                    ),
                  ),
                  Text(
                    'Super Administrateur',
                    style: TextStyle(fontSize: 11, color: FutaTheme.textLight),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                radius: 18,
                backgroundColor: FutaTheme.blueIndigo,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebTabContent(BuildContext context) {
    switch (currentTab) {
      case 0:
        return _buildWebDashboardTab();
      case 1:
        return _buildWebStudentsTab(context);
      case 2:
        return _buildWebPaymentsTab();
      default:
        return _buildWebDashboardTab();
    }
  }

  Widget _buildWebDashboardTab() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const Text(
          'Tableau de bord',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: FutaTheme.textDark,
          ),
        ),
        const SizedBox(height: 20),

        // Web Metrics Row
        Row(
          children: [
            Expanded(
              child: _buildWebMetricCard(
                'Élèves',
                '$totalStudentsCount',
                Icons.school,
                Colors.blue.shade50,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildWebMetricCard(
                'Enseignants',
                '$totalTeachersCount',
                Icons.badge,
                Colors.teal.shade50,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildWebMetricCard(
                'Parents',
                '$totalParentsCount',
                Icons.people,
                Colors.purple.shade50,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildWebMetricCard(
                'Collecté',
                '${NumberFormat.compact(locale: 'fr').format(totalAmountCollected)} FC',
                Icons.payments,
                Colors.red.shade50,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Charts & Events Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left main chart
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Revenus Mensuels',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: FutaTheme.textDark,
                                ),
                              ),
                              Row(
                                children: const [
                                  CircleAvatar(
                                    radius: 4,
                                    backgroundColor: FutaTheme.blueDark,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Revenus encaissés',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: FutaTheme.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${DateTime.now().year}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 240,
                        child: RevenusTotauxBarChart(
                          months: _getPast6MonthsLabels(),
                          revenues: _getPast6MonthsRevenues(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Right calendar
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Events Calendar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: FutaTheme.textDark,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.more_horiz,
                              color: FutaTheme.textLight,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildEventItem('08 Jan, 2023', 'School Annual Function'),
                      _buildEventItem('27 Jan, 2023', 'Sport Competition'),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'January 2023',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: FutaTheme.textDark,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_right,
                              color: FutaTheme.textLight,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Roster upload prompt if empty
        if (students.isEmpty) ...[
          const SizedBox(height: 24),
          _buildQuickUploadPrompt(),
        ],
      ],
    );
  }

  Widget _buildWebMetricCard(
    String label,
    String value,
    IconData icon,
    Color bg,
    Color iconColor,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: bg,
              radius: 22,
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: FutaTheme.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventItem(String date, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 10,
                    color: FutaTheme.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: FutaTheme.textLight, size: 18),
        ],
      ),
    );
  }

  Widget _buildWebStudentsTab(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Student list roster
        Expanded(
          flex: 4,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Élèves',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: FutaTheme.textDark,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Gérer les inscriptions et dossiers des élèves',
                          style: TextStyle(
                            color: FutaTheme.textLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FutaTheme.emeraldGreen,
                        ),
                        icon: const Icon(
                          Icons.upload_file,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Importer Roster',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        onPressed: onUploadRoster,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildFiltersCard(),
              const SizedBox(height: 16),
              _buildWebStudentTable(context),
            ],
          ),
        ),

        // Right Column: Student detailed view (Trisha Berge prototype mockup)
        if (selectedStudent != null)
          _buildWebStudentDetailPanel()
        else
          Container(
            width: 480,
            color: Colors.white,
            child: const Center(
              child: Text('Sélectionnez un élève pour voir ses détails.'),
            ),
          ),
      ],
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.search,
                    color: FutaTheme.textLight,
                    size: 20,
                  ),
                  hintText: 'Rechercher un élève, matricule...',
                  hintStyle: TextStyle(fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: selectedClassFilter,
              onChanged: (val) {
                if (val != null) {
                  onSelectedClassFilterChanged(val);
                }
              },
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: 'Toutes',
                  child: Text('Toutes', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: '3ème A',
                  child: Text('3ème A', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: '4ème B',
                  child: Text('4ème B', style: TextStyle(fontSize: 13)),
                ),
                DropdownMenuItem(
                  value: '6ème C',
                  child: Text('6ème C', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebStudentTable(BuildContext context) {
    if (filteredStudents.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('Aucun élève ne correspond aux filtres.')),
        ),
      );
    }

    final Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>
    grouped = {};

    for (var student in filteredStudents) {
      final rawClassroom = student['classroom']?.toString() ?? 'Non spécifié';
      final parsed = parseClassroom(rawClassroom);

      grouped.putIfAbsent(parsed.level, () => {});
      grouped[parsed.level]!.putIfAbsent(parsed.grade, () => {});
      grouped[parsed.level]![parsed.grade]!.putIfAbsent(
        parsed.section,
        () => [],
      );
      grouped[parsed.level]![parsed.grade]![parsed.section]!.add(student);
    }

    final orderedLevels = ['Maternelle', 'Primaire', 'Secondaire', 'Autres'];
    final levelsToShow = orderedLevels
        .where((lvl) => grouped.containsKey(lvl))
        .toList();
    for (var lvl in grouped.keys) {
      if (!levelsToShow.contains(lvl)) {
        levelsToShow.add(lvl);
      }
    }

    return Column(
      children: levelsToShow.map((level) {
        final gradesMap = grouped[level]!;
        final levelGradesCount = gradesMap.keys.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey<String>('level_$level'),
              leading: Icon(
                level == 'Maternelle'
                    ? Icons.child_care
                    : level == 'Primaire'
                    ? Icons.school_outlined
                    : level == 'Secondaire'
                    ? Icons.menu_book
                    : Icons.folder_open,
                color: FutaTheme.blueDark,
              ),
              title: Text(
                '$level ($levelGradesCount)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: FutaTheme.textDark,
                ),
              ),
              children: gradesMap.keys.map((grade) {
                final sectionsMap = gradesMap[grade]!;
                final sectionLetters = sectionsMap.keys.toList()..sort();
                final sectionsStr = sectionLetters.join(', ');

                return Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: PageStorageKey<String>('grade_$grade'),
                      title: Text(
                        '$grade ($sectionsStr)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: FutaTheme.blueDark,
                        ),
                      ),
                      children: sectionLetters.map((section) {
                        final studentsInSection = sectionsMap[section]!;
                        final studentCount = studentsInSection.length;

                        return Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: PageStorageKey<String>(
                                'section_${grade}_$section',
                              ),
                              title: Text(
                                '$section ($studentCount)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: FutaTheme.blueDark.withOpacity(0.8),
                                ),
                              ),
                              children: studentsInSection.map((student) {
                                final studentInsts = allInstallments
                                    .where(
                                      (i) => i['student_id'] == student['id'],
                                    )
                                    .toList();
                                double totalDue = 0.0;
                                double totalPaid = 0.0;
                                bool hasOverdue = false;
                                final todayStr = DateFormat(
                                  'yyyy-MM-dd',
                                ).format(DateTime.now());

                                for (var i in studentInsts) {
                                  final due =
                                      ((i['amount'] ?? i['amount_due'] ?? 0.0)
                                              as num)
                                          .toDouble();
                                  final paid =
                                      ((i['amount_paid'] ?? 0.0) as num)
                                          .toDouble();
                                  totalDue += due;
                                  totalPaid += paid;

                                  final dueDateStr =
                                      i['due_date']?.toString() ?? '';
                                  final isPaid = i['status'] == 'PAID';
                                  if (!isPaid &&
                                      dueDateStr.isNotEmpty &&
                                      dueDateStr.compareTo(todayStr) < 0) {
                                    hasOverdue = true;
                                  }
                                }

                                Color statusColor = FutaTheme.textLight;
                                Color statusBg = const Color(0xFFF1F5F9);
                                String statusText = 'À venir';

                                if (totalDue > 0 && totalPaid >= totalDue) {
                                  statusColor = FutaTheme.success;
                                  statusBg = FutaTheme.emeraldLight;
                                  statusText = 'Payé';
                                } else if (hasOverdue) {
                                  statusColor = FutaTheme.error;
                                  statusBg = const Color(0xFFFEE2E2);
                                  statusText = 'En Retard';
                                } else if (totalPaid > 0.0) {
                                  statusColor = const Color(0xFFD97706);
                                  statusBg = const Color(0xFFFEF3C7);
                                  statusText = 'Partiel';
                                } else {
                                  statusColor = FutaTheme.blueIndigo;
                                  statusBg = const Color(0xFFEFF6FF);
                                  statusText = 'À venir';
                                }

                                final fullName =
                                    '${student['first_name']} ${student['last_name']}';
                                final isSelected =
                                    selectedStudent != null &&
                                    selectedStudent!['id'] == student['id'];

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? FutaTheme.blueIndigo.withOpacity(
                                              0.3,
                                            )
                                          : Colors.grey.shade100,
                                    ),
                                  ),
                                  child: Material(
                                    color: isSelected
                                        ? const Color(0xFFF8FAFC)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    child: ListTile(
                                      onTap: () {
                                        onSelectedStudentChanged(student);
                                      },
                                      leading: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: FutaTheme.blueIndigo
                                            .withOpacity(0.08),
                                        child: Text(
                                          student['first_name']?[0] ?? '',
                                          style: const TextStyle(
                                            color: FutaTheme.blueIndigo,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: FutaTheme.textDark,
                                          fontSize: 13,
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWebStudentDetailPanel() {
    final student = selectedStudent!;
    final fullName = '${student['first_name']} ${student['last_name']}';
    final parentProfile = student['profiles'] as Map<String, dynamic>?;
    final parentPhone = parentProfile?['phone_number'] ?? '+243 000 000 000';
    final parentName = parentProfile != null
        ? '${parentProfile['first_name']} ${parentProfile['last_name']}'
        : 'Richard Berge';

    final currencyFormat = NumberFormat.decimalPattern('fr');

    // Filter installments for this student
    final studentInsts = allInstallments
        .where((i) => i['student_id'] == student['id'])
        .toList();
    studentInsts.sort(
      (a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String),
    );

    double amountDue = 0.0;
    double amountPaid = 0.0;
    for (var i in studentInsts) {
      amountDue += ((i['amount_due'] ?? i['amount'] ?? 0.0) as num).toDouble();
      amountPaid += ((i['amount_paid'] ?? i['paid_amount'] ?? 0.0) as num)
          .toDouble();
    }
    if (studentInsts.isEmpty) {
      final inst = student['installment'] as Map<String, dynamic>?;
      amountDue = (inst?['amount_due'] as num?)?.toDouble() ?? 500000.0;
      amountPaid = (inst?['amount_paid'] as num?)?.toDouble() ?? 0.0;
    }
    final double debt = amountDue - amountPaid;

    return Container(
      width: 480,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner card header matching Image 1
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 74, 93, 139), // Slate 900
                  Color(0xFF1E1B4B), // Indigo 950
                  Color.fromARGB(255, 34, 47, 79), // Slate 900
                ],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: FutaTheme.emeraldLight,
                    child: Text(
                      student['first_name']?[0] ?? '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: FutaTheme.emeraldGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${student['classroom'] ?? 'Classe'} | ID Élève: F-${student['id'].toString().substring(0, 4).toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                // Informations Générales
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Informations Générales',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: FutaTheme.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Details Grid
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _buildDetailGridItem('Genre', 'Féminin'),
                    _buildDetailGridItem('Date de naissance', '29-04-2004'),
                    _buildDetailGridItem(
                      'Adresse',
                      '1962 Harrison Street San Francisco, CA 94103',
                    ),
                    _buildDetailGridItem('Père', '$parentName ($parentPhone)'),
                    _buildDetailGridItem(
                      'Mère',
                      'Maren Berge (+1606-687-7027)',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),

                // Statut des Paiements
                const Text(
                  'STATUT DES PAIEMENTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: FutaTheme.textLight,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPanelStatRow(
                  Icons.monetization_on_outlined,
                  'Total Scolarité',
                  '${currencyFormat.format(amountDue)} FC',
                ),
                const SizedBox(height: 8),
                _buildPanelStatRow(
                  Icons.check_circle_outline,
                  'Total Payé',
                  '${currencyFormat.format(amountPaid)} FC',
                  color: FutaTheme.success,
                ),
                const SizedBox(height: 8),
                _buildPanelStatRow(
                  Icons.error_outline,
                  'Reste à Payer',
                  '${currencyFormat.format(debt)} FC',
                  color: FutaTheme.error,
                ),

                // Section manual cash payment
                if (debt > 0) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'ENREGISTRER ENCAISSEMENT ESPÈCES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: FutaTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cashAmountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Montant en FC',
                      prefixIcon: Icon(Icons.monetization_on, size: 16),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onApplyCashAdjustment,
                      child: const Text(
                        'Enregistrer un versement',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),

                // Transactions Récentes
                const Text(
                  'Transactions Récentes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.blueDark,
                  ),
                ),
                const SizedBox(height: 12),
                if (studentInsts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Aucune transaction enregistrée.',
                        style: TextStyle(
                          color: FutaTheme.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(studentInsts.length, (index) {
                    final inst = studentInsts[index];
                    final status = inst['status'] ?? 'PENDING';
                    final double amountDue =
                        ((inst['amount_due'] ?? inst['amount'] ?? 0.0) as num)
                            .toDouble();
                    final double amountPaid =
                        ((inst['amount_paid'] ?? 0.0) as num).toDouble();
                    final double remaining = amountDue - amountPaid;
                    final dueDateStr = inst['due_date']?.toString() ?? '';
                    final todayStr = DateFormat(
                      'yyyy-MM-dd',
                    ).format(DateTime.now());

                    final isPaid = status == 'PAID';
                    final isLate =
                        status != 'PAID' &&
                        dueDateStr.isNotEmpty &&
                        dueDateStr.compareTo(todayStr) < 0;

                    Color iconBgColor = const Color(0xFFEFF6FF);
                    Color iconColor = FutaTheme.blueIndigo;
                    IconData iconData = Icons.monetization_on_outlined;

                    if (isPaid) {
                      iconBgColor = FutaTheme.emeraldLight;
                      iconColor = FutaTheme.success;
                      iconData = Icons.check_circle_outline;
                    } else if (isLate) {
                      iconBgColor = const Color(0xFFFEE2E2);
                      iconColor = FutaTheme.error;
                      iconData = Icons.error_outline;
                    } else if (status == 'PARTIAL') {
                      iconBgColor = const Color(0xFFFEF3C7);
                      iconColor = const Color(0xFFD97706);
                      iconData = Icons.pending_outlined;
                    }

                    Color statusBgColor = const Color(0xFFEFF6FF);
                    Color statusTextColor = FutaTheme.blueIndigo;
                    String statusText = 'À venir';

                    if (isPaid) {
                      statusBgColor = FutaTheme.emeraldLight;
                      statusTextColor = FutaTheme.success;
                      statusText = 'Réglé';
                    } else if (isLate) {
                      statusBgColor = const Color(0xFFFEE2E2);
                      statusTextColor = FutaTheme.error;
                      statusText = 'En Retard';
                    } else if (status == 'PARTIAL') {
                      statusBgColor = const Color(0xFFFEF3C7);
                      statusTextColor = const Color(0xFFD97706);
                      statusText = 'Partiel';
                    }

                    final dateVal =
                        inst['paid_at'] ?? inst['due_date'] ?? 'Aujourd\'hui';
                    String formattedDate = 'Aujourd\'hui';
                    if (dateVal != 'Aujourd\'hui') {
                      try {
                        final parsed = DateTime.parse(dateVal as String);
                        formattedDate =
                            '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
                      } catch (_) {
                        formattedDate = dateVal.toString();
                      }
                    }

                    return Card(
                      elevation: 0.5,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade100, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: iconBgColor,
                              radius: 20,
                              child: Icon(iconData, color: iconColor, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tranche ${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: FutaTheme.blueDark,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isPaid
                                        ? 'Payé le: $formattedDate'
                                        : 'Échéance: $formattedDate',
                                    style: TextStyle(
                                      color: isLate
                                          ? FutaTheme.error
                                          : FutaTheme.textLight,
                                      fontSize: 11,
                                      fontWeight: isLate
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${currencyFormat.format(isPaid ? amountPaid : remaining)} FC',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isPaid
                                        ? FutaTheme.success
                                        : (isLate
                                              ? FutaTheme.error
                                              : (status == 'PARTIAL'
                                                    ? const Color(0xFFD97706)
                                                    : FutaTheme.blueDark)),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusTextColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                const Divider(),

                // Dynamic Progress line chart matching Image 1
                const SizedBox(height: 16),
                const Text(
                  'Progrès',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),

                // Chart filters tags
                Row(
                  children: [
                    _buildChartFilterTag('Tout', true),
                    _buildChartFilterTag('Maths', false),
                    _buildChartFilterTag('Sciences', false),
                    _buildChartFilterTag('Anglais', false),
                    _buildChartFilterTag('Histoire', false),
                  ],
                ),
                const SizedBox(height: 24),
                const StudentProgressLineChart(),
                const SizedBox(height: 12),

                // Checkpoints x-axis labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Test 1',
                      style: TextStyle(
                        fontSize: 10,
                        color: FutaTheme.textLight,
                      ),
                    ),
                    Text(
                      'Test 2',
                      style: TextStyle(
                        fontSize: 10,
                        color: FutaTheme.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Test 3',
                      style: TextStyle(
                        fontSize: 10,
                        color: FutaTheme.textLight,
                      ),
                    ),
                    Text(
                      'Test 4',
                      style: TextStyle(
                        fontSize: 10,
                        color: FutaTheme.textLight,
                      ),
                    ),
                    Text(
                      'Test 5',
                      style: TextStyle(
                        fontSize: 10,
                        color: FutaTheme.textLight,
                      ),
                    ),
                    Text(
                      'Test 6',
                      style: TextStyle(
                        fontSize: 10,
                        color: FutaTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailGridItem(String label, String value) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: FutaTheme.textLight,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: FutaTheme.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelStatRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: FutaTheme.textLight),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: FutaTheme.textLight, fontSize: 12),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color ?? FutaTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildChartFilterTag(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? FutaTheme.emeraldLight : Colors.transparent,
        border: Border.all(
          color: isSelected ? FutaTheme.emeraldGreen : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSelected ? FutaTheme.emeraldGreen : FutaTheme.textLight,
        ),
      ),
    );
  }

  Widget _buildWebPaymentsTab() {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    // 1. Group installments
    final soldesInsts = allInstallments
        .where((inst) => inst['status'] == 'PAID')
        .toList();

    final avenirInsts = allInstallments.where((inst) {
      if (inst['status'] == 'PAID') return false;
      final dueDate = inst['due_date']?.toString() ?? '';
      return dueDate.isEmpty || dueDate.compareTo(todayStr) >= 0;
    }).toList();

    final retardInsts = allInstallments.where((inst) {
      if (inst['status'] == 'PAID') return false;
      final dueDate = inst['due_date']?.toString() ?? '';
      return dueDate.isNotEmpty && dueDate.compareTo(todayStr) < 0;
    }).toList();

    final int partialCount = allInstallments.where((inst) {
      final double paid = ((inst['amount_paid'] ?? inst['paid_amount'] ?? 0.0) as num).toDouble();
      final double due = ((inst['amount_due'] ?? inst['amount'] ?? 0.0) as num).toDouble();
      return inst['status'] != 'PAID' && paid > 0 && paid < due;
    }).length;

    // 2. Select filtered items based on active choice
    List<Map<String, dynamic>> activeList = [];
    double cardValue = 0.0;
    String cardTitle = '';
    String cardSubtitle = '';
    IconData cardIcon = Icons.payment;
    List<Color> cardColors = [];

    double calculateSum(List<Map<String, dynamic>> list, bool isPaidSum) {
      double sum = 0.0;
      for (var inst in list) {
        final double due =
            ((inst['amount'] ?? inst['amount_due'] ?? 0.0) as num).toDouble();
        final double paid =
            ((inst['paid_amount'] ?? inst['amount_paid'] ?? 0.0) as num)
                .toDouble();
        if (isPaidSum) {
          sum += paid;
        } else {
          sum += (due - paid);
        }
      }
      return sum;
    }

    if (selectedPaymentFilter == 'avenir') {
      activeList = avenirInsts;
      cardValue = calculateSum(avenirInsts, false);
      cardTitle = 'MONTANT À VENIR';
      cardSubtitle = 'Reste à recouvrir sur les futures échéances';
      cardIcon = Icons.hourglass_empty;
      cardColors = [FutaTheme.blueIndigo, const Color(0xFF3B82F6)];
    } else if (selectedPaymentFilter == 'soldes') {
      activeList = List<Map<String, dynamic>>.from(soldesInsts);
      activeList.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['paid_at'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dateB =
            DateTime.tryParse(b['paid_at'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      cardValue = calculateSum(allInstallments, true);
      cardTitle = 'MONTANT COLLECTÉ';
      cardSubtitle = 'Frais de scolarité entièrement payés';
      cardIcon = Icons.check_circle_outline;
      cardColors = [FutaTheme.emeraldGreen, const Color(0xFF10B981)];
    } else {
      activeList = retardInsts;
      cardValue = calculateSum(retardInsts, false);
      cardTitle = 'MONTANT EN RETARD';
      cardSubtitle = 'Encaissements en souffrance / en retard';
      cardIcon = Icons.warning_amber_rounded;
      cardColors = [const Color(0xFFE11D48), const Color(0xFFF43F5E)];
    }

    final currencyFormat = NumberFormat.decimalPattern('fr');

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Title Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Suivi des Paiements',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Suivi et état des tranches de scolarité par catégories',
                  style: TextStyle(color: FutaTheme.textLight, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Split Layout: ChoiceChips & Summary card side-by-side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left part: Category Selection Tiles
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catégories de Tranches',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: FutaTheme.textDark,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tileColor: selectedPaymentFilter == 'avenir'
                            ? FutaTheme.blueIndigo.withOpacity(0.08)
                            : Colors.transparent,
                        leading: Icon(
                          Icons.hourglass_empty,
                          color: selectedPaymentFilter == 'avenir'
                              ? FutaTheme.blueIndigo
                              : FutaTheme.textLight,
                        ),
                        title: Text(
                          'À venir (${avenirInsts.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selectedPaymentFilter == 'avenir'
                                ? FutaTheme.blueIndigo
                                : FutaTheme.textDark,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => onSelectedPaymentFilterChanged('avenir'),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tileColor: selectedPaymentFilter == 'soldes'
                            ? FutaTheme.emeraldLight.withOpacity(0.4)
                            : Colors.transparent,
                        leading: Icon(
                          Icons.check_circle_outline,
                          color: selectedPaymentFilter == 'soldes'
                              ? FutaTheme.success
                              : FutaTheme.textLight,
                        ),
                        title: Text(
                          'Soldés (${soldesInsts.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selectedPaymentFilter == 'soldes'
                                ? FutaTheme.success
                                : FutaTheme.textDark,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => onSelectedPaymentFilterChanged('soldes'),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tileColor: selectedPaymentFilter == 'retard'
                            ? const Color(0xFFFEE2E2)
                            : Colors.transparent,
                        leading: Icon(
                          Icons.warning_amber_rounded,
                          color: selectedPaymentFilter == 'retard'
                              ? FutaTheme.error
                              : FutaTheme.textLight,
                        ),
                        title: Text(
                          'En retard (${retardInsts.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selectedPaymentFilter == 'retard'
                                ? FutaTheme.error
                                : FutaTheme.textDark,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => onSelectedPaymentFilterChanged('retard'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Right part: Gradient Summary Card
            Expanded(
              flex: 1,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  height: 185,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: cardColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cardTitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Icon(cardIcon, color: Colors.white, size: 28),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${currencyFormat.format(cardValue)} FC',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedPaymentFilter == 'soldes'
                            ? '${activeList.length} tranches entièrement réglées • $partialCount tranches partiellement réglées'
                            : '${activeList.length} tranches de paiement • $cardSubtitle',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Bottom section: Payments list
        const Text(
          'Détails des Échéances',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: FutaTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),

        if (activeList.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(
                child: Text(
                  'Aucune tranche de paiement trouvée dans cette catégorie.',
                  style: TextStyle(color: FutaTheme.textLight, fontSize: 14),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final inst = activeList[index];
              final student = students.firstWhere(
                (s) => s['id'] == inst['student_id'],
                orElse: () => {},
              );

              final fullName = student.isNotEmpty
                  ? '${student['first_name']} ${student['last_name']}'
                  : 'Élève';
              final classroom = student.isNotEmpty
                  ? (student['classroom'] ?? 'Classe')
                  : 'Classe';

              final double due =
                  ((inst['amount'] ?? inst['amount_due'] ?? 0.0) as num)
                      .toDouble();
              final double paid =
                  ((inst['paid_amount'] ?? inst['amount_paid'] ?? 0.0) as num)
                      .toDouble();
              final double remaining = due - paid;

              String dateFormatted = inst['due_date'] ?? '';
              if (dateFormatted.length >= 10) {
                try {
                  final parsed = DateTime.parse(dateFormatted);
                  dateFormatted =
                      '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
                } catch (_) {}
              }

              String paidAtFormatted = '';
              if (selectedPaymentFilter == 'soldes') {
                final String paidAtStr = inst['paid_at'] ?? '';
                if (paidAtStr.length >= 10) {
                  try {
                    final parsed = DateTime.parse(paidAtStr);
                    paidAtFormatted =
                        '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
                  } catch (_) {
                    paidAtFormatted = paidAtStr;
                  }
                } else {
                  paidAtFormatted = paidAtStr.isNotEmpty ? paidAtStr : 'N/A';
                }
              }

              final studentInsts = allInstallments
                  .where((i) => i['student_id'] == inst['student_id'])
                  .toList();
              studentInsts.sort(
                (a, b) => (a['due_date'] as String).compareTo(
                  b['due_date'] as String,
                ),
              );
              final instIndex = studentInsts.indexWhere(
                (i) => i['id'] == inst['id'],
              );
              final trancheTitle =
                  'Tranche ${instIndex != -1 ? instIndex + 1 : 1}';

              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (student.isNotEmpty) {
                      onSelectedStudentChanged(student);
                      onTabChanged(
                        1,
                      ); // Switch to Students tab on web to show details
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: selectedPaymentFilter == 'soldes'
                              ? FutaTheme.emeraldLight
                              : selectedPaymentFilter == 'retard'
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDBEAFE),
                          child: Icon(
                            Icons.monetization_on_outlined,
                            color: selectedPaymentFilter == 'soldes'
                                ? FutaTheme.success
                                : selectedPaymentFilter == 'retard'
                                ? FutaTheme.error
                                : FutaTheme.blueIndigo,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: FutaTheme.textDark,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  buildTypeChip(classroom),
                                  buildInstallmentChip(trancheTitle),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 12,
                                    color: selectedPaymentFilter == 'retard'
                                        ? FutaTheme.error
                                        : FutaTheme.textLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    selectedPaymentFilter == 'soldes'
                                        ? 'Payé le: $paidAtFormatted'
                                        : 'Échéance: $dateFormatted',
                                    style: TextStyle(
                                      color: selectedPaymentFilter == 'retard'
                                          ? FutaTheme.error
                                          : FutaTheme.textLight,
                                      fontSize: 11,
                                      fontWeight:
                                          selectedPaymentFilter == 'retard'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              if (paid > 0 &&
                                  selectedPaymentFilter != 'soldes') ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reçu: ${currencyFormat.format(paid)} FC • Reste: ${currencyFormat.format(remaining)} FC',
                                  style: const TextStyle(
                                    color: FutaTheme.textLight,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${currencyFormat.format(selectedPaymentFilter == 'soldes' ? paid : remaining)} FC',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: FutaTheme.blueDark,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: selectedPaymentFilter == 'soldes'
                                    ? FutaTheme.emeraldLight
                                    : selectedPaymentFilter == 'retard'
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                selectedPaymentFilter == 'soldes'
                                    ? 'Payé'
                                    : selectedPaymentFilter == 'retard'
                                    ? 'En Retard'
                                    : 'À venir',
                                style: TextStyle(
                                  color: selectedPaymentFilter == 'soldes'
                                      ? FutaTheme.success
                                      : selectedPaymentFilter == 'retard'
                                      ? FutaTheme.error
                                      : FutaTheme.blueIndigo,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildQuickUploadPrompt() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.upload_file,
                  size: 48,
                  color: FutaTheme.blueDark,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aucun élève enregistré',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Importez le fichier Excel (.xlsx) ou CSV de votre établissement pour initialiser le roster.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FutaTheme.textLight,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                isUploading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: FutaTheme.blueDark,
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onUploadRoster,
                          child: const Text('Sélectionner le fichier Roster'),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
