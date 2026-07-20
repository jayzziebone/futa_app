import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import './school_dashboard_shared_widgets.dart';

class SchoolDashboardMobileLayout extends StatelessWidget {
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

  final Future<void> Function() onRefresh;
  final VoidCallback onUploadRoster;
  final VoidCallback onApplyCashAdjustment;
  final VoidCallback onLogout;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<Map<String, dynamic>?> onSelectedStudentChanged;
  final ValueChanged<String> onSelectedPaymentFilterChanged;
  final ValueChanged<String> onSelectedClassFilterChanged;

  const SchoolDashboardMobileLayout({
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
    required this.onRefresh,
    required this.onUploadRoster,
    required this.onApplyCashAdjustment,
    required this.onLogout,
    required this.onTabChanged,
    required this.onSelectedStudentChanged,
    required this.onSelectedPaymentFilterChanged,
    required this.onSelectedClassFilterChanged,
  });

  double _getAverageAttendance() {
    if (students.isEmpty) return 95.0;
    double sum = 0.0;
    for (var s in students) {
      sum += ((s['attendance_rate'] ?? 95.0) as num).toDouble();
    }
    return sum / students.length;
  }

  List<Map<String, dynamic>> _getTopPerformers() {
    final list = List<Map<String, dynamic>>.from(students);
    list.sort((a, b) {
      final double scoreA = ((a['academic_score'] ?? 0.0) as num).toDouble();
      final double scoreB = ((b['academic_score'] ?? 0.0) as num).toDouble();
      return scoreB.compareTo(scoreA);
    });
    return list.take(3).toList();
  }

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
      backgroundColor: FutaTheme.backgroundLight,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          schoolName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildMobileTabContent(context),
    );
  }

  Widget _buildMobileTabContent(BuildContext context) {
    switch (currentTab) {
      case 0:
        return _buildMobileAccueilTab(context);
      case 1:
        return _buildElevesTab(context);
      case 2:
        return _buildMobilePaymentTab(context);
      case 3:
        return _buildProfilTab();
      default:
        return _buildMobileAccueilTab(context);
    }
  }

  Widget _buildMobileAccueilTab(BuildContext context) {
    final months = _getPast6MonthsLabels();
    final revenues = _getPast6MonthsRevenues();
    final averageAttendance = _getAverageAttendance();
    final topPerformers = _getTopPerformers();
    final currentYear = DateTime.now().year.toString();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Tableau de bord',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: FutaTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),

        // Horizontal Stats Cards matching Image 3
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildMobileStatsCard(
                'Étudiants',
                '$totalStudentsCount',
                Icons.school,
                Colors.blue.shade50,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildMobileStatsCard(
                'Enseignants',
                '$totalTeachersCount',
                Icons.badge,
                Colors.teal.shade50,
                Colors.teal,
              ),
              const SizedBox(width: 12),
              _buildMobileStatsCard(
                'Parents',
                '$totalParentsCount',
                Icons.people,
                Colors.purple.shade50,
                Colors.purple,
              ),
              const SizedBox(width: 12),
              _buildMobileStatsCard(
                'Collecté',
                '${NumberFormat.compact(locale: 'fr').format(totalAmountCollected)} FC',
                Icons.payments,
                Colors.red.shade50,
                Colors.red,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Revenus Totaux Card matching Image 3
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Revenus Mensuels',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: FutaTheme.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentYear,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 150,
                  child: RevenusTotauxBarChart(
                    months: months,
                    revenues: revenues,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Presences Card matching Image 3
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Présences',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: FutaTheme.textDark,
                  ),
                ),
                const Text(
                  'Taux global ce mois',
                  style: TextStyle(color: FutaTheme.textLight, fontSize: 12),
                ),
                const SizedBox(height: 20),
                Center(
                  child: AttendanceRingChart(attendanceRate: averageAttendance),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Top Performances ranking matching Image 3
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Top Performances',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: FutaTheme.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (topPerformers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Aucune donnée disponible.',
                        style: TextStyle(
                          color: FutaTheme.textLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...List.generate(topPerformers.length, (index) {
                    final s = topPerformers[index];
                    final fullName = '${s['first_name']} ${s['last_name']}';
                    final matricule =
                        s['id']?.toString().substring(0, 4).toUpperCase() ?? '';
                    final classroom = s['classroom'] ?? 'Classe';
                    final double score = ((s['academic_score'] ?? 0.0) as num)
                        .toDouble();
                    final percentageStr = '${score.toStringAsFixed(1)}/20';

                    // Assign color dynamically
                    Color circleColor = Colors.purple;
                    if (index == 1) circleColor = Colors.teal;
                    if (index == 2) circleColor = Colors.orange;

                    return _buildTopPerformanceItem(
                      fullName,
                      'Matricule: #$matricule • $classroom',
                      percentageStr,
                      circleColor,
                    );
                  }),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Le classement complet est disponible dans la section Contrats.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Voir tout le classement'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Promotional call-out banner card matching Image 3
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gérez mieux votre école',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Découvrez nos nouveaux outils de gestion de contrats et paiements automatisés.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  'Explorer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMobileStatsCard(
    String label,
    String value,
    IconData icon,
    Color bg,
    Color iconColor,
  ) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: bg,
            radius: 18,
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: FutaTheme.textLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FutaTheme.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformanceItem(
    String name,
    String sub,
    String score,
    Color avatarBg,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: avatarBg.withOpacity(0.1),
            radius: 18,
            child: Text(
              name[0],
              style: TextStyle(color: avatarBg, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: FutaTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: FutaTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              score,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElevesTab(BuildContext context) {
    return RefreshIndicator(
      color: FutaTheme.emeraldGreen,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contrats & Roster',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: FutaTheme.textDark,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Filtrez et gérez les élèves par classe',
                    style: TextStyle(color: FutaTheme.textLight, fontSize: 12),
                  ),
                ],
              ),
              isUploading
                  ? const CircularProgressIndicator(color: FutaTheme.blueDark)
                  : IconButton(
                      icon: const Icon(
                        Icons.upload_file,
                        color: FutaTheme.blueDark,
                      ),
                      tooltip: 'Importer un Roster (Excel/CSV)',
                      onPressed: onUploadRoster,
                    ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFiltersCard(),
          const SizedBox(height: 16),
          _buildStudentTable(context),
        ],
      ),
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

  Widget _buildStudentTable(BuildContext context) {
    if (filteredStudents.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
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

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade100,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    child: ListTile(
                                      onTap: () {
                                        context.pushNamed(
                                          'student_detail',
                                          pathParameters: {
                                            'studentId':
                                                student['id']?.toString() ??
                                                '1',
                                          },
                                        );
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

  Widget _buildSelectedStudentSidebar(BuildContext context) {
    final student = selectedStudent!;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBar(
            title: const Text(
              'Fiche de l\'Élève',
              style: TextStyle(fontSize: 15),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => onSelectedStudentChanged(null),
            ),
          ),
          Expanded(child: _buildStudentDetailsContent(student)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                context.pushNamed(
                  'student_detail',
                  pathParameters: {'studentId': student['id'] ?? '1'},
                );
              },
              child: const Text(
                'Voir le dossier complet',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDetailsBottomSheet(
    BuildContext context,
    Map<String, dynamic> student,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: _buildStudentDetailsContent(student),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        context.pushNamed(
                          'student_detail',
                          pathParameters: {'studentId': student['id'] ?? '1'},
                        );
                      },
                      child: const Text(
                        'Voir le dossier complet',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentDetailsContent(Map<String, dynamic> student) {
    final currencyFormat = NumberFormat.decimalPattern('fr');
    final fullName = '${student['first_name']} ${student['last_name']}';

    final double score =
        (student['academic_score'] as num?)?.toDouble() ?? 15.0;
    final double attendance =
        (student['attendance_rate'] as num?)?.toDouble() ?? 95.0;

    final inst = student['installment'] as Map<String, dynamic>?;
    final double amountDue =
        (inst?['amount_due'] as num?)?.toDouble() ?? 500000.0;
    final double amountPaid = (inst?['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final double debt = amountDue - amountPaid;

    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: FutaTheme.emeraldLight,
                child: Text(
                  student['first_name']?[0] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    color: FutaTheme.emeraldGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fullName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FutaTheme.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Classe: ${student['classroom']}',
                style: const TextStyle(
                  color: FutaTheme.textLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'RÉSUMÉ ACADÉMIQUE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: FutaTheme.textLight,
          ),
        ),
        const SizedBox(height: 8),
        _buildPanelStatRow(
          Icons.grade_outlined,
          'Moyenne Générale',
          '$score/20',
        ),
        const SizedBox(height: 8),
        _buildPanelStatRow(
          Icons.calendar_today_outlined,
          'Assiduité',
          '${attendance.round()}%',
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'STATUT DES PAIEMENTS',
          style: TextStyle(
            fontSize: 10,
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

        if (debt > 0) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'ENREGISTRER ENCAISSEMENT ESPÈCES',
            style: TextStyle(
              fontSize: 10,
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
                'Enregistrer versement',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ],
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

  Widget _buildMobilePaymentTab(BuildContext context) {
    if (students.isEmpty) {
      return _buildQuickUploadPrompt();
    }

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
      final double paid =
          ((inst['amount_paid'] ?? inst['paid_amount'] ?? 0.0) as num)
              .toDouble();
      final double due = ((inst['amount_due'] ?? inst['amount'] ?? 0.0) as num)
          .toDouble();
      return inst['status'] != 'PAID' && paid > 0 && paid < due;
    }).length;

    // 2. Select filtered items based on active ChoiceChip
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

    return RefreshIndicator(
      color: FutaTheme.emeraldGreen,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Suivi des Paiements',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: FutaTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Suivi des tranches de scolarité par catégories',
            style: TextStyle(color: FutaTheme.textLight, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // 3. Category ChoiceChips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(
                    'À venir (${avenirInsts.length})',
                    style: TextStyle(
                      color: selectedPaymentFilter == 'avenir'
                          ? Colors.white
                          : FutaTheme.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  selected: selectedPaymentFilter == 'avenir',
                  selectedColor: FutaTheme.blueIndigo,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (selected) {
                    if (selected) onSelectedPaymentFilterChanged('avenir');
                  },
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'Soldés (${soldesInsts.length})',
                    style: TextStyle(
                      color: selectedPaymentFilter == 'soldes'
                          ? Colors.white
                          : FutaTheme.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  selected: selectedPaymentFilter == 'soldes',
                  selectedColor: FutaTheme.emeraldGreen,
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (selected) {
                    if (selected) onSelectedPaymentFilterChanged('soldes');
                  },
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'En retard (${retardInsts.length})',
                    style: TextStyle(
                      color: selectedPaymentFilter == 'retard'
                          ? Colors.white
                          : FutaTheme.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  selected: selectedPaymentFilter == 'retard',
                  selectedColor: const Color(0xFFE11D48),
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (selected) {
                    if (selected) onSelectedPaymentFilterChanged('retard');
                  },
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Premium Category Summary Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: cardColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cardTitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Icon(cardIcon, color: Colors.white, size: 24),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${currencyFormat.format(cardValue)} FC',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedPaymentFilter == 'soldes'
                        ? '${activeList.length} tranches entièrement réglées • $partialCount tranches partiellement réglées'
                        : '${activeList.length} tranches de paiement • $cardSubtitle',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Payments List
          if (activeList.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    selectedPaymentFilter == 'avenir'
                        ? 'Aucune échéance à venir.'
                        : selectedPaymentFilter == 'soldes'
                        ? 'Aucun versement soldé.'
                        : 'Aucun paiement en retard.',
                    style: const TextStyle(
                      color: FutaTheme.textLight,
                      fontSize: 13,
                    ),
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
                        context.pushNamed(
                          'student_detail',
                          pathParameters: {
                            'studentId': student['id']?.toString() ?? '1',
                          },
                        );
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
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    buildTypeChip(classroom),
                                    const SizedBox(width: 6),
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
                                  fontSize: 13,
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
                                    fontSize: 9,
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
      ),
    );
  }

  Widget _buildProfilTab() {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Mon Profil Établissement',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: FutaTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: FutaTheme.emeraldLight,
                      child: Icon(
                        Icons.school,
                        size: 30,
                        color: FutaTheme.emeraldGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schoolName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: FutaTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Administrateur Scolaire FUTA',
                            style: TextStyle(
                              color: FutaTheme.textLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'INFORMATIONS DE CONNEXION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.textLight,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoDetailRow(
                  'Numéro de téléphone',
                  user?.phoneNumber ?? '+243 812 345 678',
                ),
                const SizedBox(height: 12),
                _buildInfoDetailRow(
                  'ID Établissement',
                  user?.uid ?? 'FB-SCHOOL-1002',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ROSTER / BASE DE DONNÉES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.textLight,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                isUploading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: FutaTheme.blueDark,
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onUploadRoster,
                          icon: const Icon(Icons.upload_file),
                          label: const Text(
                            'Importer une mise à jour Roster (Excel/CSV)',
                          ),
                        ),
                      ),
                const SizedBox(height: 8),
                const Text(
                  'Téléchargez le fichier Excel ou CSV contenant la liste complète ou mise à jour de vos élèves pour synchroniser les contrats de paiement.',
                  style: TextStyle(
                    fontSize: 11,
                    color: FutaTheme.textLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        // const SizedBox(height: 24),
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16.0),
        //   child: ElevatedButton.icon(
        //     style: ElevatedButton.styleFrom(
        //       backgroundColor: FutaTheme.error,
        //       foregroundColor: Colors.white,
        //       padding: const EdgeInsets.symmetric(vertical: 12),
        //     ),
        //     onPressed: onLogout,
        //     icon: const Icon(Icons.logout),
        //     label: const Text('Se déconnecter'),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildInfoDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: FutaTheme.textLight, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: FutaTheme.textDark,
          ),
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mac-style Window dots + Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5F56),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFBD2E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF27C93F),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.search, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 24),
              // App Logo / Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: FutaTheme.blueDark.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      color: FutaTheme.blueDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'FUTA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: FutaTheme.textDark,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Text(
                    ' v1.0',
                    style: TextStyle(
                      color: FutaTheme.textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Segmented Control (Ecole / Roster)
              // Container(
              //   padding: const EdgeInsets.all(4),
              //   decoration: BoxDecoration(
              //     color: const Color(0xFFF1F5F9),
              //     borderRadius: BorderRadius.circular(12),
              //   ),
              //   child: Row(
              //     children: [
              //       Expanded(
              //         child: Container(
              //           padding: const EdgeInsets.symmetric(vertical: 8),
              //           decoration: BoxDecoration(
              //             color: FutaTheme.blueDark,
              //             borderRadius: BorderRadius.circular(10),
              //           ),
              //           child: const Center(
              //             child: Text(
              //               'ÉCOLE',
              //               style: TextStyle(
              //                 color: Colors.white,
              //                 fontWeight: FontWeight.bold,
              //                 fontSize: 11,
              //               ),
              //             ),
              //           ),
              //         ),
              //       ),
              //       Expanded(
              //         child: Container(
              //           padding: const EdgeInsets.symmetric(vertical: 8),
              //           child: const Center(
              //             child: Text(
              //               'ROSTER',
              //               style: TextStyle(
              //                 color: FutaTheme.textLight,
              //                 fontWeight: FontWeight.bold,
              //                 fontSize: 11,
              //               ),
              //             ),
              //           ),
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              // const SizedBox(height: 24),
              // MENU Header
              const Text(
                'MENU',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: FutaTheme.textLight,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              // Menu Options List
              _buildDrawerItem(
                index: 0,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Acceuil',
                context: context,
              ),
              _buildDrawerItem(
                index: 1,
                icon: Icons.school_outlined,
                activeIcon: Icons.school,
                label: 'Élèves',
                context: context,
              ),
              _buildDrawerItem(
                index: 2,
                icon: Icons.payment_outlined,
                activeIcon: Icons.payment,
                label: 'Paiements',
                context: context,
              ),
              _buildDrawerItem(
                index: 3,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil École',
                context: context,
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),
              // COMPTE Header
              const Text(
                'COMPTE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: FutaTheme.textLight,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              // Account Options
              _buildAccountDrawerItem(
                icon: Icons.notifications_none,
                label: 'Notifications',
                badge: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '24',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildAccountDrawerItem(
                icon: Icons.chat_bubble_outline,
                label: 'Messagerie',
                badge: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '8',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildAccountDrawerItem(
                icon: Icons.settings_outlined,
                label: 'Paramètres',
              ),
              const Spacer(),
              // Profile Capsule at the bottom
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: FutaTheme.blueDark,
                      radius: 18,
                      child: Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            schoolName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: FutaTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'admin@futa.cd',
                            style: TextStyle(
                              fontSize: 10,
                              color: FutaTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz,
                        color: FutaTheme.textLight,
                      ),
                      onSelected: (val) {
                        if (val == 'logout') {
                          onLogout();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout,
                                color: FutaTheme.error,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Se déconnecter',
                                style: TextStyle(
                                  color: FutaTheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required BuildContext context,
  }) {
    final isSelected = currentTab == index;
    return GestureDetector(
      onTap: () {
        onTabChanged(index);
        Navigator.pop(context); // Close drawer
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? FutaTheme.blueDark.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? FutaTheme.blueDark : FutaTheme.textLight,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? FutaTheme.blueDark : FutaTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDrawerItem({
    required IconData icon,
    required String label,
    Widget? badge,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: FutaTheme.textLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: FutaTheme.textDark,
              ),
            ),
          ),
          if (badge != null) badge,
        ],
      ),
    );
  }
}
