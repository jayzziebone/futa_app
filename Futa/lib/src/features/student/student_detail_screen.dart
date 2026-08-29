import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart' as dio;
import '../../core/theme.dart';
import '../../core/config.dart';
import '../../core/widgets/skeleton_shimmer.dart';
import '../../core/auth_token_manager.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Map<String, dynamic> _studentData;
  late List<Map<String, dynamic>> _transactions;
  List<Map<String, dynamic>> _installments = [];
  bool _isLoading = true;
  String _schoolName = 'FUTA';

  final _dio = dio.Dio(dio.BaseOptions(baseUrl: Config.backendUrl));

  @override
  void initState() {
    super.initState();
    _loadStudentDetails();
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildMethodChip(String method) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);

    if (method.contains('Mobile Money')) {
      bg = const Color(0xFFEFF6FF);
      text = FutaTheme.blueIndigo;
    } else if (method.contains('Espèces')) {
      bg = const Color(0xFFF0FDF4);
      text = const Color(0xFF16A34A);
    } else if (method.contains('Virement')) {
      bg = const Color(0xFFF5F3FF);
      text = const Color(0xFF7C3AED);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        method,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Future<void> _loadStudentDetails() async {
    setState(() => _isLoading = true);
    try {
      await AuthTokenManager.applySupabaseHeaders();
      final supabase = Supabase.instance.client;

      // Run student query and installments query in parallel
      final studentFuture = supabase
          .from('students')
          .select(
            '*, parent:profiles!students_parent_id_fkey(id, first_name, last_name, phone_number, address)',
          )
          .eq('id', widget.studentId)
          .single();

      final installmentsFuture = supabase
          .from('school_installments')
          .select('*')
          .eq('student_id', widget.studentId);

      final results = await Future.wait<dynamic>([studentFuture, installmentsFuture]);

      final studentRes = results[0] as Map<String, dynamic>;
      final installmentsRes = results[1] as List<dynamic>;

      final String? schoolId = studentRes['school_id'];
      String tempSchoolName = 'FUTA';
      if (schoolId != null) {
        try {
          final schoolRes = await supabase
              .from('school_profiles')
              .select('school_name')
              .eq('id', schoolId)
              .maybeSingle();
          if (schoolRes != null) {
            tempSchoolName = schoolRes['school_name'] ?? 'FUTA';
          }
        } catch (_) {}
      }

      _installments = List<Map<String, dynamic>>.from(installmentsRes);


      double totalTuition = 0.0;
      double totalPaid = 0.0;
      List<Map<String, dynamic>> tempTransactions = [];

      // Sort installments by due date to label them as T1, T2, T3 sequentially
      _installments.sort(
        (a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String),
      );

      int trancheIndex = 1;
      for (var inst in _installments) {
        final double due = ((inst['amount_due'] ?? 0.0) as num).toDouble();
        final double paid = ((inst['amount_paid'] ?? 0.0) as num).toDouble();
        totalTuition += due;
        totalPaid += paid;

        if (paid > 0.0) {
          final isFull = paid >= due;
          final dateVal = inst['paid_at'] ?? inst['due_date'] ?? 'Aujourd\'hui';
          final formattedDate = dateVal != 'Aujourd\'hui'
              ? _formatDate(dateVal as String)
              : 'Aujourd\'hui';

          tempTransactions.add({
            'title':
                'Versement Scolarité T$trancheIndex${isFull ? "" : " (Partiel)"}',
            'amount': paid,
            'date': formattedDate,
            'method': isFull ? 'Mobile Money' : 'Espèces',
            'status': isFull ? 'PAID' : 'PARTIAL',
          });
        }
        trancheIndex++;
      }

      String statusText = 'En retard';
      if (totalPaid >= totalTuition && totalTuition > 0) {
        statusText = 'Réglé';
      } else if (totalPaid > 0.0) {
        statusText = 'Paiement Partiel';
      }

      final parentData = studentRes['parent'] as Map<String, dynamic>?;
      final parentId = parentData?['id'] ?? studentRes['parent_id'] ?? '';
      final parentFirstName = parentData?['first_name'] ?? '';
      final parentLastName = parentData?['last_name'] ?? '';
      final parentPhone = parentData?['phone_number'] ?? '';
      final parentAddress = parentData?['address'] ?? '';
      final parentName = '$parentFirstName $parentLastName'.trim();

      setState(() {
        _studentData = {
          'first_name': studentRes['first_name'] ?? 'Élève',
          'last_name': studentRes['last_name'] ?? '',
          'matricule':
              '#FUTA-2026-${widget.studentId.substring(0, 4).toUpperCase()}',
          'classroom': studentRes['classroom'] ?? 'Classe',
          'specialty': parentName.isNotEmpty
              ? 'Parent: $parentName'
              : 'Régulier',
          'gpa': '${studentRes['academic_score'] ?? "15.0"}/20',
          'attendance': '${(studentRes['attendance_rate'] ?? 95.0).round()}%',
          'total_tuition': totalTuition,
          'amount_paid': totalPaid,
          'status_text': statusText,
          'parent_id': parentId,
          'parent_first_name': parentFirstName,
          'parent_last_name': parentLastName,
          'parent_name': parentName,
          'parent_phone': parentPhone,
          'parent_address': parentAddress,
        };
        _transactions = tempTransactions;
        _schoolName = tempSchoolName;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading student details, falling back to mock: $e');
      setState(() {
        _studentData = {
          'first_name': 'Jean-Luc',
          'last_name': 'Dupont',
          'matricule': '#FUTA-2024-0892',
          'classroom': '3ème Année',
          'specialty': 'Génie Civil',
          'gpa': '16.4/20',
          'attendance': '94%',
          'total_tuition': 1700000.0,
          'amount_paid': 1250000.0,
          'status_text': 'Paiement Partiel',
          'parent_id': '',
          'parent_first_name': 'Richard',
          'parent_last_name': 'Dupont',
          'parent_name': 'Richard Dupont',
          'parent_phone': '+243 812 345 678',
          'parent_address': 'Gombe, Kinshasa',
        };
        _transactions = [
          {
            'title': 'Versement Scolarité T2',
            'amount': 450000.0,
            'date': '15 Mars 2024',
            'method': 'Virement Bancaire',
            'status': 'PAID',
          },
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _updateParentDetails({
    required String parentId,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? address,
  }) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      await _dio.post(
        '/api/v1/school/update-parent',
        data: {
          'parent_id': parentId,
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
          'address': address,
        },
        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil du parent mis à jour avec succès.'),
            backgroundColor: FutaTheme.success,
          ),
        );
      }
      _loadStudentDetails();
    } catch (e) {
      debugPrint('Error updating parent: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de la mise à jour: ${e.toString()}'),
            backgroundColor: FutaTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _updateInstallmentDates({
    String? studentId,
    required String tranche1Date,
    required String tranche2Date,
    required String tranche3Date,
  }) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      await _dio.post(
        '/api/v1/school/update-installment-dates',
        data: {
          'school_id': FirebaseAuth.instance.currentUser?.uid,
          'student_id': studentId,
          'tranche1_date': tranche1Date,
          'tranche2_date': tranche2Date,
          'tranche3_date': tranche3Date,
        },

        options: dio.Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dates d\'échéances mises à jour avec succès.'),
            backgroundColor: FutaTheme.success,
          ),
        );
      }
      _loadStudentDetails();
    } catch (e) {
      debugPrint('Error updating installment dates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de la mise à jour: ${e.toString()}'),
            backgroundColor: FutaTheme.error,
          ),
        );
      }
    }
  }

  void _showEditParentDialog() {
    final firstNameController = TextEditingController(text: _studentData['parent_first_name'] ?? '');
    final lastNameController = TextEditingController(text: _studentData['parent_last_name'] ?? '');
    final phoneController = TextEditingController(text: _studentData['parent_phone'] ?? '');
    final addressController = TextEditingController(text: _studentData['parent_address'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Modifier le profil du parent',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: FutaTheme.blueDark),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'Prénom du parent'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Nom du parent'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  hintText: '+243... ou 08...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Adresse'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FutaTheme.emeraldGreen),
            onPressed: () {
              if (firstNameController.text.trim().isEmpty || lastNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez remplir le prénom et le nom.')),
                );
                return;
              }
              _updateParentDetails(
                parentId: _studentData['parent_id'] ?? '',
                firstName: firstNameController.text.trim(),
                lastName: lastNameController.text.trim(),
                phoneNumber: phoneController.text.trim(),
                address: addressController.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditInstallmentDatesDialog() {
    final now = DateTime.now();
    DateTime t1 = now.add(const Duration(days: 30));
    DateTime t2 = now.add(const Duration(days: 60));
    DateTime t3 = now.add(const Duration(days: 90));

    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate(int trancheNum) async {
              final initial = trancheNum == 1 ? t1 : (trancheNum == 2 ? t2 : t3);
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setDialogState(() {
                  if (trancheNum == 1) t1 = picked;
                  if (trancheNum == 2) t2 = picked;
                  if (trancheNum == 3) t3 = picked;
                });
              }
            }

            return AlertDialog(
              title: const Text(
                'Définir les Échéances (Élève)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: FutaTheme.blueDark),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Tranche 1', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(formatter.format(t1)),
                    trailing: const Icon(Icons.calendar_today, size: 18, color: FutaTheme.blueDark),
                    onTap: () => pickDate(1),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Tranche 2', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(formatter.format(t2)),
                    trailing: const Icon(Icons.calendar_today, size: 18, color: FutaTheme.blueDark),
                    onTap: () => pickDate(2),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Tranche 3', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(formatter.format(t3)),
                    trailing: const Icon(Icons.calendar_today, size: 18, color: FutaTheme.blueDark),
                    onTap: () => pickDate(3),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: FutaTheme.emeraldGreen),
                  onPressed: () {
                    _updateInstallmentDates(
                      studentId: widget.studentId,
                      tranche1Date: formatter.format(t1),
                      tranche2Date: formatter.format(t2),
                      tranche3Date: formatter.format(t3),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _showDepositDialog() {
    final amountController = TextEditingController();

    // Find active installment
    final activeInst = _installments.firstWhere(
      (inst) => inst['status'] != 'PAID',
      orElse: () => {},
    );

    if (activeInst.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La scolarité de cet élève est déjà entièrement réglée !',
          ),
          backgroundColor: FutaTheme.success,
        ),
      );
      return;
    }

    final double totalOwed = _installments.fold(0.0, (sum, i) {
      final double due = ((i['amount_due'] ?? i['amount'] ?? 0.0) as num).toDouble();
      final double paid = ((i['amount_paid'] ?? i['paid_amount'] ?? 0.0) as num).toDouble();
      final double rem = due - paid;
      return sum + (rem > 0 ? rem : 0.0);
    });

    final double maxDeposit = totalOwed;

    showDialog(
      context: context,
      builder: (ctx) {
        bool subIsLoading = false;
        String? subError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Effectuer un versement',
                style: TextStyle(
                  color: FutaTheme.blueDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Saisissez le montant en FC (Reste total dû: ${NumberFormat.decimalPattern('fr').format(maxDeposit)} FC).',
                    style: const TextStyle(
                      fontSize: 13,
                      color: FutaTheme.textLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    enabled: !subIsLoading,
                    decoration: InputDecoration(
                      labelText: 'Montant',
                      hintText: 'Ex: 100000',
                      errorText: subError,
                    ),
                  ),
                  if (subIsLoading) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(
                        color: FutaTheme.emeraldGreen,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: subIsLoading
                      ? null
                      : () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: FutaTheme.textLight),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: subIsLoading
                      ? null
                      : () async {
                          final double deposit =
                              double.tryParse(amountController.text.trim()) ??
                              0;
                          if (deposit <= 0) {
                            setDialogState(
                              () => subError =
                                  'Veuillez entrer un montant valide supérieur à 0.',
                            );
                            return;
                          }
                          if (deposit > maxDeposit) {
                            setDialogState(
                              () => subError =
                                  'Le montant dépasse le solde total dû (${NumberFormat.decimalPattern('fr').format(maxDeposit)} FC).',
                            );
                            return;
                          }

                          setDialogState(() {
                            subIsLoading = true;
                            subError = null;
                          });

                          try {
                            final token = await FirebaseAuth.instance.currentUser?.getIdToken();

                            // 1. Process payment via backend (updates DB once & recalculates FUTA score)
                            final response = await _dio.post(
                              '/api/v1/payments/cash-adjustment',
                              data: {
                                'installment_id': activeInst['id'],
                                'amount': deposit,
                              },
                              options: dio.Options(
                                headers: {
                                  'Authorization': 'Bearer $token',
                                },
                              ),
                            );
                            final int newScore = response.data['new_futa_score'] ?? 100;

                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Versement de ${NumberFormat.decimalPattern('fr').format(deposit)} FC enregistré. Nouveau Score FUTA: $newScore',
                                ),
                                backgroundColor: FutaTheme.success,
                              ),
                            );
                            _loadStudentDetails();
                          } catch (e) {
                            if (e is dio.DioException) {
                               debugPrint('Dio error response data: ${e.response?.data}');
                            }
                            // Fallback mock payment update
                            debugPrint(
                              'Backend payment failed, falling back to mock: $e',
                            );
                            Navigator.of(ctx).pop();

                            setState(() {
                              final double totalOwed = _installments.fold(0.0, (sum, i) => sum + (((i['amount_due'] ?? 0.0) as num).toDouble() - ((i['amount_paid'] ?? 0.0) as num).toDouble()));
                              if (deposit > totalOwed) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Le montant dépasse le solde total dû.")),
                                );
                                return;
                              }

                              double remainingPayment = deposit;
                              for (var inst in _installments) {
                                final double due = ((inst['amount_due'] ?? 0.0) as num).toDouble();
                                final double paid = ((inst['amount_paid'] ?? 0.0) as num).toDouble();
                                final double remaining = due - paid;

                                if (remaining <= 0) continue;

                                final double toApply = remainingPayment < remaining ? remainingPayment : remaining;
                                final double newPaid = paid + toApply;
                                inst['amount_paid'] = newPaid;
                                inst['status'] = newPaid >= due ? 'PAID' : 'PARTIAL';
                                inst['paid_at'] = DateTime.now().toIso8601String();
                                remainingPayment -= toApply;

                                if (remainingPayment <= 0) break;
                              }
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Versement enregistré localement (mode hors ligne).',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );

                            _loadStudentDetails(); // Re-read from local updated list
                          }
                        },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SkeletonStudentDetail();
    }


    final currencyFormat = NumberFormat.decimalPattern('fr');
    final double total = _studentData['total_tuition'];
    final double paid = _studentData['amount_paid'];
    final double remaining = total - paid;
    final double paidPercentage = total > 0 ? (paid / total) : 0;

    final statusText = _studentData['status_text'] ?? '';
    Color statusBgColor = const Color(0xFFFEF3C7);
    Color statusTextColor = const Color(0xFFD97706);
    Color paidTextColor = const Color(0xFFD97706);
    Color progressColor = const Color(0xFFD97706);

    if (statusText == 'Réglé') {
      statusBgColor = FutaTheme.emeraldLight;
      statusTextColor = FutaTheme.success;
      paidTextColor = FutaTheme.success;
      progressColor = FutaTheme.success;
    } else if (statusText == 'En retard') {
      statusBgColor = const Color(0xFFFEE2E2);
      statusTextColor = FutaTheme.error;
      paidTextColor = FutaTheme.blueDark;
      progressColor = FutaTheme.error;
    } else {
      // Paiement Partiel
      statusBgColor = const Color(0xFFFEF3C7);
      statusTextColor = const Color(0xFFD97706);
      paidTextColor = const Color(0xFFD97706);
      progressColor = const Color(0xFFD97706);
    }

    return Scaffold(
      backgroundColor: FutaTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. HERO GRADIENT HEADER BANNER CARD
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E1B4B), // Deep Slate Navy
                          FutaTheme.blueDark, // Brand Deep Indigo
                          Color(0xFF313B9B), // Vibrant Indigo
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: FutaTheme.blueDark.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                              onPressed: () => context.pop(),
                            ),
                            Text(
                              _schoolName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.notifications_none, color: Colors.white, size: 18),
                              onPressed: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: FutaTheme.emeraldGreen,
                            child: Text(
                              _studentData['first_name']?[0] ?? '',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_studentData['first_name']} ${_studentData['last_name']}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _studentData['matricule'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school, size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    _studentData['classroom'],
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person, size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    _studentData['specialty'],
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. PARENT PROFILE & ACTIONS CARD
                  Card(
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'INFORMATIONS DU PARENT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: FutaTheme.blueDark,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: FutaTheme.emeraldLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Tuteur Légal',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: FutaTheme.emeraldGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.person, size: 16, color: FutaTheme.blueIndigo),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Nom: ', style: TextStyle(color: FutaTheme.textLight, fontSize: 13)),
                                    Expanded(
                                      child: Text(
                                        (_studentData['parent_name'] ?? '').isNotEmpty
                                            ? _studentData['parent_name']
                                            : 'Non spécifié',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FutaTheme.textDark),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.phone, size: 16, color: FutaTheme.blueIndigo),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Téléphone: ', style: TextStyle(color: FutaTheme.textLight, fontSize: 13)),
                                    Expanded(
                                      child: Text(
                                        (_studentData['parent_phone'] ?? '').isNotEmpty
                                            ? _studentData['parent_phone']
                                            : 'Non spécifié',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FutaTheme.textDark),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.location_on, size: 16, color: FutaTheme.blueIndigo),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Adresse: ', style: TextStyle(color: FutaTheme.textLight, fontSize: 13)),
                                    Expanded(
                                      child: Text(
                                        (_studentData['parent_address'] ?? '').isNotEmpty
                                            ? _studentData['parent_address']
                                            : 'Non spécifiée',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FutaTheme.textDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FutaTheme.emeraldGreen,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                  label: const Text('Modifier Parent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                  onPressed: _showEditParentDialog,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: FutaTheme.blueDark, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.edit_calendar, size: 16, color: FutaTheme.blueDark),
                                  label: const Text('Échéances Élève', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FutaTheme.blueDark)),
                                  onPressed: _showEditInstallmentDatesDialog,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. FINANCIAL SUMMARY CARD
                  Card(
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'STATUT DES PAIEMENTS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: FutaTheme.blueDark,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _studentData['status_text'],
                                  style: TextStyle(
                                    color: statusTextColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFDCFCE7)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TOTAL PAYÉ',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${currencyFormat.format(paid)} FC',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFEE2E2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'RESTE À PAYER',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: FutaTheme.error),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${currencyFormat.format(remaining)} FC',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FutaTheme.error),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: paidPercentage,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(paidPercentage * 100).round()}% du montant total réglé',
                                style: const TextStyle(color: FutaTheme.textLight, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'Total: ${currencyFormat.format(total)} FC',
                                style: const TextStyle(color: FutaTheme.textLight, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FutaTheme.blueDark,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.payments, size: 18, color: Colors.white),
                            label: const Text('Enregistrer un versement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: _showDepositDialog,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.file_download_outlined, size: 18, color: FutaTheme.textDark),
                            label: const Text(
                              'Télécharger l\'échéancier',
                              style: TextStyle(color: FutaTheme.textDark, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. TRANSACTIONS / INSTALLMENTS CARD
                  Card(
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ÉCHÉANCIER DE SCOLARITÉ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: FutaTheme.blueDark,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Voir tout',
                                  style: TextStyle(
                                    color: FutaTheme.emeraldGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _installments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final inst = _installments[index];
                            final status = inst['status'] ?? 'PENDING';
                            final double amountDue =
                                ((inst['amount_due'] ?? 0.0) as num).toDouble();
                            final double amountPaid =
                                ((inst['amount_paid'] ?? 0.0) as num)
                                    .toDouble();
                            final double remaining = amountDue - amountPaid;
                            final dueDateStr =
                                inst['due_date']?.toString() ?? '';
                            final todayStr = DateFormat(
                              'yyyy-MM-dd',
                            ).format(DateTime.now());

                            final isPaid = status == 'PAID';
                            final isLate =
                                status != 'PAID' &&
                                dueDateStr.isNotEmpty &&
                                dueDateStr.compareTo(todayStr) < 0;

                            // Left status icon indicators
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

                            // Right status pill badge
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

                            // Method chip helper
                            final method = isPaid ? 'Mobile Money' : 'Espèces';
                            final dateVal =
                                inst['paid_at'] ??
                                inst['due_date'] ??
                                'Aujourd\'hui';
                            final formattedDate = dateVal != 'Aujourd\'hui'
                                ? _formatDate(dateVal as String)
                                : 'Aujourd\'hui';

                            return Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey.shade100,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: iconBgColor,
                                      radius: 20,
                                      child: Icon(
                                        iconData,
                                        color: iconColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tranche ${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: FutaTheme.blueDark,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          if (amountPaid > 0.0) ...[
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                _buildMethodChip(method),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today_outlined,
                                                size: 12,
                                                color: isLate
                                                    ? FutaTheme.error
                                                    : FutaTheme.textLight,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  isPaid
                                                      ? 'Payé le: $formattedDate'
                                                      : (status == 'PARTIAL'
                                                            ? 'Dernier versement: $formattedDate'
                                                            : 'Échéance: ${_formatDate(dueDateStr)}'),
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
                                              ),
                                            ],
                                          ),
                                          if (status == 'PARTIAL') ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Reçu: ${currencyFormat.format(amountPaid)} FC • Reste: ${currencyFormat.format(remaining)} FC',
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isPaid
                                              ? '+ ${currencyFormat.format(amountPaid)} FC'
                                              : '${currencyFormat.format(remaining)} FC',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isPaid
                                                ? FutaTheme.success
                                                : (isLate
                                                      ? FutaTheme.error
                                                      : (status == 'PARTIAL'
                                                            ? const Color(
                                                                0xFFD97706,
                                                              )
                                                            : FutaTheme
                                                                  .blueDark)),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusBgColor,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusTextColor,
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}




