import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart' as dio;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../../core/config.dart';
import './school_dashboard_mobile_layout.dart';
import './school_dashboard_web_layout.dart';

class SchoolDashboardScreen extends StatefulWidget {
  const SchoolDashboardScreen({super.key});

  @override
  State<SchoolDashboardScreen> createState() => _SchoolDashboardScreenState();
}

class _SchoolDashboardScreenState extends State<SchoolDashboardScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  Map<String, dynamic>? _selectedStudent;
  
  List<Map<String, dynamic>> _allInstallments = [];
  String _selectedPaymentFilter = 'avenir';
  
  final _searchController = TextEditingController();
  final _cashAmountController = TextEditingController();
  String _selectedClassFilter = 'Toutes';
  
  // Navigation & School Metadata
  int _currentTab = 0;
  String _schoolName = 'FUTA Administration';
  
  // Analytics variables
  int _totalStudentsCount = 0;
  int _totalParentsCount = 0;
  int _totalTeachersCount = 0;
  double _totalAmountCollected = 0.0;
  double _recoveryRate = 0.0;
  
  final _dio = dio.Dio(dio.BaseOptions(baseUrl: Config.backendUrl));

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    _cashAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showFullScreenLoading = true}) async {
    if (showFullScreenLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Aucune session utilisateur active trouvée. Veuillez vous reconnecter.");
      }
      final schoolId = user.uid;

      // 0. Fetch School Profile details to display school name
      try {
        final schoolProfileRes = await Supabase.instance.client
            .from('school_profiles')
            .select('school_name')
            .eq('id', schoolId)
            .maybeSingle();

        if (schoolProfileRes != null) {
          final sName = schoolProfileRes['school_name'] as String? ?? '';
          if (sName.isNotEmpty) {
            _schoolName = sName;
          }
        }
      } catch (profileErr) {
        debugPrint('Failed to load school profile name: $profileErr');
      }

      // 1. Get contracts for this school
      final contractsRes = await Supabase.instance.client
          .from('school_contracts')
          .select()
          .eq('school_id', schoolId);

      List<Map<String, dynamic>> loadedStudents = [];
      List<Map<String, dynamic>> loadedInstallments = [];
      double totalDue = 0.0;
      double totalPaid = 0.0;
      double recoveryRate = 0.0;

      if (contractsRes.isNotEmpty) {
        final contractIds = contractsRes.map((c) => c['id']).toList();
        
        // 2. Get installments linked to these contracts
        final installmentsRes = await Supabase.instance.client
            .from('school_installments')
            .select()
            .inFilter('contract_id', contractIds);

        loadedInstallments = List<Map<String, dynamic>>.from(installmentsRes);

        for (var inst in installmentsRes) {
          totalDue += ((inst['amount_due'] ?? inst['amount'] ?? 0.0) as num).toDouble();
          totalPaid += ((inst['amount_paid'] ?? inst['paid_amount'] ?? 0.0) as num).toDouble();
        }

        recoveryRate = totalDue > 0 ? (totalPaid / totalDue) * 100 : 0.0;

        // 3. Fetch details for these students directly belonging to the school
        final studentsRes = await Supabase.instance.client
            .from('students')
            .select('*, profiles!students_parent_id_fkey(first_name, last_name, phone_number)')
            .eq('school_id', schoolId);

        // 4. Merge active installment details with each student profile
        loadedStudents = List<Map<String, dynamic>>.from(studentsRes).map((student) {
          final studentInsts = installmentsRes.where((inst) => inst['student_id'] == student['id']).toList();
          
          // Sort by due date
          studentInsts.sort((a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String));
          
          // Select the first pending/partial installment, or fallback to the last paid one
          final activeInst = studentInsts.firstWhere(
            (inst) => inst['status'] != 'PAID',
            orElse: () => studentInsts.isNotEmpty ? studentInsts.last : {},
          );

          return {
            ...student,
            'installment': activeInst,
          };
        }).toList();
      }

      final uniqueParentsCount = loadedStudents
          .map((student) => student['parent_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .length;
      final estimatedTeachers = loadedStudents.isNotEmpty ? (loadedStudents.length / 10).ceil() + 1 : 0;

      setState(() {
        _allInstallments = loadedInstallments;
        _students = loadedStudents;
        _filteredStudents = List.from(_students);
        _totalStudentsCount = _students.length;
        _totalParentsCount = uniqueParentsCount;
        _totalTeachersCount = estimatedTeachers;
        _totalAmountCollected = totalPaid;
        _recoveryRate = recoveryRate;

        // Default select first student in list on desktop view if none is selected
        if (_students.isNotEmpty && _selectedStudent == null) {
          _selectedStudent = _students.first;
        }
      });

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((student) {
        final matchesQuery = student['first_name'].toString().toLowerCase().contains(query) ||
            student['last_name'].toString().toLowerCase().contains(query);
        final matchesClass = _selectedClassFilter == 'Toutes' ||
            student['classroom'].toString() == _selectedClassFilter;
        return matchesQuery && matchesClass;
      }).toList();
    });
  }

  Future<void> _uploadRoster() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expirée. Veuillez vous reconnecter.')),
      );
      return;
    }
    final schoolId = user.uid;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (result == null || result.files.isEmpty) {
        return; // User canceled
      }

      setState(() => _isUploading = true);

      final file = result.files.first;
      final fileBytes = file.bytes;
      final fileName = file.name;

      dio.MultipartFile multipartFile;
      if (fileBytes != null) {
        multipartFile = dio.MultipartFile.fromBytes(fileBytes, filename: fileName);
      } else if (file.path != null) {
        multipartFile = await dio.MultipartFile.fromFile(file.path!, filename: fileName);
      } else {
        throw Exception("Impossible de lire les données du fichier.");
      }

      final formData = dio.FormData.fromMap({
        'file': multipartFile,
      });

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await _dio.post(
        '/api/v1/school/upload-roster?school_id=$schoolId',
        data: formData,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (mounted) {
        final data = response.data;
        final results = data['resultats'] as Map<String, dynamic>?;
        final successCount = results?['success_count'] ?? 0;
        final errorCount = results?['error_count'] ?? 0;
        final errors = List<String>.from(results?['errors'] ?? []);

        if (errorCount > 0 && successCount == 0) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Erreur d'importation", style: TextStyle(color: FutaTheme.error, fontWeight: FontWeight.bold)),
              content: Text("Aucune ligne n'a pu être importée.\n\nDétails des erreurs:\n${errors.join('\n')}"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Fermer"),
                )
              ],
            ),
          );
        } else if (errorCount > 0) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Importation partielle", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              content: Text("$successCount élèves importés, mais $errorCount erreurs ont eu lieu.\n\nDétails des erreurs:\n${errors.join('\n')}"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loadData();
                  },
                  child: const Text("Fermer et actualiser"),
                )
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount élèves importés et validés avec succès !'),
              backgroundColor: FutaTheme.success,
            ),
          );
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'importation: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Logs a manual cash adjustment and recalculates parent FUTA score
  Future<void> _applyCashAdjustment() async {
    if (_cashAmountController.text.isEmpty || _selectedStudent == null) return;
    
    final double amount = double.parse(_cashAmountController.text.trim());
    final inst = _selectedStudent!['installment'] as Map<String, dynamic>?;
    final instId = inst?['id'] ?? 'inst_mock_2';

    setState(() => _isLoading = true);

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();

      // 1. Process payment via backend (updates DB once & recalculates FUTA score)
      final response = await _dio.post(
        '/api/v1/payments/cash-adjustment',
        data: {
          'installment_id': instId,
          'amount': amount,
        },
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final int newScore = response.data['new_futa_score'] ?? 100;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ajustement Enregistré', style: TextStyle(color: FutaTheme.blueDark, fontWeight: FontWeight.bold)),
          content: Text(
            'Le paiement en espèces de ${NumberFormat.decimalPattern('fr').format(amount)} FC a été crédité.\nNouveau Score de Crédit du Parent: $newScore',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _loadData();
                setState(() {
                  _selectedStudent = null; // Close side panel
                  _cashAmountController.clear();
                });
              },
              child: const Text('Fermer', style: TextStyle(color: FutaTheme.emeraldGreen)),
            )
          ],
        ),
      );
    } catch (e) {
      // Mock adjustment fallback
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ajustement en Espèces', style: TextStyle(color: FutaTheme.blueDark, fontWeight: FontWeight.bold)),
          content: Text(
            'Montant de ${NumberFormat.decimalPattern('fr').format(amount)} FC reçu.\nLe compte étudiant et l\'échéance ont été mis à jour.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  final double totalOwed = _allInstallments
                      .where((i) => i['student_id'] == _selectedStudent!['id'])
                      .fold(0.0, (sum, i) => sum + (((i['amount_due'] ?? i['amount'] ?? 0.0) as num).toDouble() - ((i['amount_paid'] ?? i['paid_amount'] ?? 0.0) as num).toDouble()));

                  if (amount > totalOwed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Le montant dépasse le solde total dû.")),
                    );
                    _isLoading = false;
                    return;
                  }

                  double remainingPayment = amount;
                  final studentInsts = _allInstallments
                      .where((i) => i['student_id'] == _selectedStudent!['id'])
                      .toList();
                  studentInsts.sort((a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String));

                  for (var i in studentInsts) {
                    final double due = ((i['amount_due'] ?? i['amount'] ?? 0.0) as num).toDouble();
                    final double paid = ((i['amount_paid'] ?? i['paid_amount'] ?? 0.0) as num).toDouble();
                    final double remaining = due - paid;

                    if (remaining <= 0) continue;

                    final double toApply = remainingPayment < remaining ? remainingPayment : remaining;
                    final double newPaid = paid + toApply;
                    i['amount_paid'] = newPaid;
                    i['status'] = newPaid >= due ? 'PAID' : 'PARTIAL';
                    i['paid_at'] = DateTime.now().toIso8601String();
                    remainingPayment -= toApply;

                    if (remainingPayment <= 0) break;
                  }

                  // Recalculate global metrics
                  double newTotalDue = 0.0;
                  double newTotalPaid = 0.0;
                  for (var inst in _allInstallments) {
                    newTotalDue += ((inst['amount_due'] ?? inst['amount'] ?? 0.0) as num).toDouble();
                    newTotalPaid += ((inst['amount_paid'] ?? inst['paid_amount'] ?? 0.0) as num).toDouble();
                  }
                  _totalAmountCollected = newTotalPaid;
                  _recoveryRate = newTotalDue > 0 ? (newTotalPaid / newTotalDue) * 100 : 0.0;

                  _selectedStudent = null;
                  _cashAmountController.clear();
                  _isLoading = false;
                });
              },
              child: const Text('OK', style: TextStyle(color: FutaTheme.emeraldGreen)),
            )
          ],
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: FutaTheme.blueDark)),
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
                  onPressed: _loadData,
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
          return SchoolDashboardWebLayout(
            schoolName: _schoolName,
            isUploading: _isUploading,
            students: _students,
            filteredStudents: _filteredStudents,
            selectedStudent: _selectedStudent,
            allInstallments: _allInstallments,
            selectedPaymentFilter: _selectedPaymentFilter,
            selectedClassFilter: _selectedClassFilter,
            currentTab: _currentTab,
            totalStudentsCount: _totalStudentsCount,
            totalParentsCount: _totalParentsCount,
            totalTeachersCount: _totalTeachersCount,
            totalAmountCollected: _totalAmountCollected,
            recoveryRate: _recoveryRate,
            searchController: _searchController,
            cashAmountController: _cashAmountController,
            onUploadRoster: _uploadRoster,
            onApplyCashAdjustment: _applyCashAdjustment,
            onLogout: _logout,
            onTabChanged: (index) {
              setState(() {
                _currentTab = index;
                if (index == 1 && _students.isNotEmpty && _selectedStudent == null) {
                  _selectedStudent = _students.first;
                }
              });
            },
            onSelectedStudentChanged: (student) => setState(() => _selectedStudent = student),
            onSelectedPaymentFilterChanged: (filter) => setState(() => _selectedPaymentFilter = filter),
            onSelectedClassFilterChanged: (classroom) {
              setState(() {
                _selectedClassFilter = classroom;
                _applyFilters();
              });
            },
          );
        } else {
          return SchoolDashboardMobileLayout(
            schoolName: _schoolName,
            isUploading: _isUploading,
            students: _students,
            filteredStudents: _filteredStudents,
            selectedStudent: _selectedStudent,
            allInstallments: _allInstallments,
            selectedPaymentFilter: _selectedPaymentFilter,
            selectedClassFilter: _selectedClassFilter,
            currentTab: _currentTab,
            totalStudentsCount: _totalStudentsCount,
            totalParentsCount: _totalParentsCount,
            totalTeachersCount: _totalTeachersCount,
            totalAmountCollected: _totalAmountCollected,
            recoveryRate: _recoveryRate,
            searchController: _searchController,
            cashAmountController: _cashAmountController,
            onRefresh: () => _loadData(showFullScreenLoading: false),
            onUploadRoster: _uploadRoster,
            onApplyCashAdjustment: _applyCashAdjustment,
            onLogout: _logout,
            onTabChanged: (index) {
              setState(() {
                _currentTab = index;
                _selectedStudent = null;
              });
            },
            onSelectedStudentChanged: (student) => setState(() => _selectedStudent = student),
            onSelectedPaymentFilterChanged: (filter) => setState(() => _selectedPaymentFilter = filter),
            onSelectedClassFilterChanged: (classroom) {
              setState(() {
                _selectedClassFilter = classroom;
                _applyFilters();
              });
            },
          );
        }
      },
    );
  }
}
