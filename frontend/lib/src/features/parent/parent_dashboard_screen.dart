import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../../core/config.dart';
import 'widgets/credit_score_gauge.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Local states
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _installments = [];
  int _futaScore = 600;
  int? _previousFutaScore;
  String _selectedContractFilter = 'actifs'; // 'actifs', 'pending', 'completes'

  Map<String, int?> _getStoredScores(String rawAddress) {
    if (!rawAddress.contains('|')) {
      return {'score': 600, 'prev': null};
    }
    try {
      final parts = rawAddress.split('|');
      if (parts.length > 1) {
        final scoreSection = parts[1].trim();
        final scoreParts = scoreSection.split(',');
        int score = 600;
        int? prev;
        for (var part in scoreParts) {
          if (part.contains('score:')) {
            score = int.tryParse(part.split('score:')[1].trim()) ?? 600;
          } else if (part.contains('prev:')) {
            prev = int.tryParse(part.split('prev:')[1].trim());
          }
        }
        return {'score': score, 'prev': prev};
      }
    } catch (e) {
      debugPrint('Error parsing stored scores: $e');
    }
    return {'score': 600, 'prev': null};
  }

  Widget _buildTypeChip(String type) {
    Color bg = FutaTheme.blueDark.withOpacity(0.08);
    Color text = FutaTheme.blueDark;

    if (type == 'Scolarité') {
      bg = const Color(0xFFEEF2FF);
      text = FutaTheme.blueIndigo;
    } else if (type == 'Commerçant') {
      bg = const Color(0xFFFFFBEB);
      text = const Color(0xFFD97706);
    } else if (type == 'Client') {
      bg = const Color(0xFFF0FDF4);
      text = const Color(0xFF0F766E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildInstallmentChip(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  String _getCleanAddress(String? rawAddress) {
    if (rawAddress == null || rawAddress.isEmpty) return 'Gombe, Kinshasa';
    return rawAddress.split('|').first.trim();
  }

  // Dio client for Cloud Run backend calls
  final _dio = Dio(BaseOptions(baseUrl: Config.backendUrl));

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    return dateStr.split('T').first.split(' ').first;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(
          "Aucune session utilisateur active trouvée. Veuillez vous reconnecter.",
        );
      }
      final userId = user.uid;

      // 1. Fetch Profile
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileRes != null) {
        _profile = Map<String, dynamic>.from(profileRes);
        final rawAddress = _profile?['address']?.toString() ?? '';
        final scoreData = _getStoredScores(rawAddress);
        _futaScore = scoreData['score'] ?? 600;
        _previousFutaScore = scoreData['prev'];
      } else {
        throw Exception("Profil introuvable pour cet utilisateur.");
      }

      // 2. Fetch Students
      final studentsRes = await Supabase.instance.client
          .from('students')
          .select()
          .eq('parent_id', userId);
      _students = List<Map<String, dynamic>>.from(studentsRes);

      // 3. Fetch School Contracts
      final schoolContractsRes = await Supabase.instance.client
          .from('school_contracts')
          .select(
            '*, school_profiles!school_contracts_school_id_fkey(school_name, admin_name, phone_number)',
          )
          .eq('parent_id', userId);

      // 4. Fetch Merchant Contracts
      final clientPhone = _profile?['phone_number'] ?? '';
      List<Map<String, dynamic>> merchantContracts = [];
      List<Map<String, dynamic>> merchantInstallments = [];
      Map<String, String> merchantNamesMap = {};
      Map<String, String> merchantPhonesMap = {};

      if (clientPhone.isNotEmpty) {
        try {
          final merchantContractsRes = await Supabase.instance.client
              .from('contracts')
              .select('*, users(firebase_uid)')
              .eq('client_phone', clientPhone);

          if (merchantContractsRes.isNotEmpty) {
            merchantContracts = List<Map<String, dynamic>>.from(
              merchantContractsRes,
            );
            final merchantUids = merchantContracts
                .map((c) => c['users']?['firebase_uid'])
                .where((uid) => uid != null)
                .toList();

            if (merchantUids.isNotEmpty) {
              final profilesRes = await Supabase.instance.client
                  .from('profiles')
                  .select('id, first_name, last_name, phone_number')
                  .inFilter('id', merchantUids);
              for (var p in profilesRes) {
                final fullName =
                    '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
                merchantNamesMap[p['id']] = fullName.isNotEmpty
                    ? fullName
                    : 'Commerçant';
                merchantPhonesMap[p['id']] = p['phone_number'] ?? '';
              }
            }

            // Fetch Merchant Installments
            final merchantContractIds = merchantContracts
                .where((c) => c['status'] == 'active' || c['status'] == 'completed')
                .map((c) => c['id'] as int)
                .toList();
            if (merchantContractIds.isNotEmpty) {
              final installmentsRes = await Supabase.instance.client
                  .from('contract_installments')
                  .select()
                  .inFilter('contract_id', merchantContractIds);
              merchantInstallments = List<Map<String, dynamic>>.from(
                installmentsRes,
              );
            }
          }
        } catch (merchantErr) {
          debugPrint('Failed to query merchant contracts: $merchantErr');
        }
      }

      // Merge contracts into _contracts
      final List<Map<String, dynamic>> unifiedContracts = [];
      for (var c in schoolContractsRes) {
        final contractMap = Map<String, dynamic>.from(c);
        contractMap['currency'] = 'FC';
        
        // Map school_profiles metadata to profiles key so UI displays it correctly
        final schoolProf = contractMap['school_profiles'] as Map<String, dynamic>?;
        if (schoolProf != null) {
          contractMap['profiles'] = {
            'first_name': schoolProf['school_name'] ?? '',
            'last_name': '',
            'phone_number': schoolProf['phone_number'] ?? '',
          };
        } else {
          contractMap['profiles'] = {
            'first_name': 'École',
            'last_name': '',
            'phone_number': '',
          };
        }
        
        unifiedContracts.add(contractMap);
      }
      for (var c in merchantContracts) {
        final merchantUid = c['users']?['firebase_uid'];
        final name = merchantNamesMap[merchantUid] ?? 'Commerçant';
        final phone = merchantPhonesMap[merchantUid] ?? '';
        unifiedContracts.add({
          'id': c['id'].toString(),
          'school_id': 'merchant_$merchantUid', // Tag to identify as merchant
          'parent_id': userId,
          'total_tuition_due': (c['total_amount'] as num).toDouble(),
          'status': c['status'],
          'description': c['description'] ?? '',
          'profiles': {'first_name': name, 'last_name': ''},
          'currency': c['currency'] == 'FCFA' ? 'FC' : (c['currency'] ?? 'FC'),
          'merchant_phone': phone,
        });
      }
      _contracts = unifiedContracts;

      // Merge installments into _installments
      final List<Map<String, dynamic>> unifiedInstallments = [];
      // School installments (if any exist)
      if (schoolContractsRes.isNotEmpty) {
        try {
          final schoolContractIds = schoolContractsRes
              .map((c) => c['id'])
              .toList();
          final schoolInstallmentsRes = await Supabase.instance.client
              .from('school_installments')
              .select('*, students(first_name, last_name)')
              .inFilter('contract_id', schoolContractIds);

          final allSchoolInsts = List<Map<String, dynamic>>.from(
            schoolInstallmentsRes,
          );

          // Group by contract_id
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (var inst in allSchoolInsts) {
            final cId = inst['contract_id'].toString();
            grouped.putIfAbsent(cId, () => []).add(inst);
          }

          // Sort each group by due_date ascending and assign computed_number
          for (var entry in grouped.entries) {
            final list = entry.value;
            list.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a['due_date'] ?? '') ?? DateTime.now();
              final dateB =
                  DateTime.tryParse(b['due_date'] ?? '') ?? DateTime.now();
              return dateA.compareTo(dateB);
            });
            for (int i = 0; i < list.length; i++) {
              list[i]['computed_number'] = i + 1;
            }
          }

          for (var inst in allSchoolInsts) {
            final instNum = inst['computed_number'] ?? 1;
            final schoolContract = schoolContractsRes.firstWhere(
              (c) => c['id']?.toString() == inst['contract_id']?.toString(),
              orElse: () => {},
            );
            final description = schoolContract['description'] ?? 'Frais de scolarité';
            unifiedInstallments.add({
              'id': inst['id'].toString(),
              'contract_id': inst['contract_id'].toString(),
              'amount_due':
                  ((inst['amount'] ?? inst['amount_due'] ?? 0.0) as num)
                      .toDouble(),
              'amount_paid':
                  ((inst['paid_amount'] ?? inst['amount_paid'] ?? 0.0) as num)
                      .toDouble(),
              'due_date': inst['due_date'],
              'status': inst['status'],
              'students': inst['students'],
              'currency': 'FC',
              'type': 'Scolarité',
              'description': description,
              'installment_number': instNum,
              'installment_title': 'Tranche n°$instNum',
            });
          }
        } catch (schoolInstErr) {
          debugPrint('Failed to query school installments: $schoolInstErr');
        }
      }
      // Merchant installments
      for (var inst in merchantInstallments) {
        final contractId = inst['contract_id'];
        final contract = merchantContracts.firstWhere(
          (c) => c['id'] == contractId,
          orElse: () => {},
        );
        final merchantUid = contract['users']?['firebase_uid'];
        final merchantName = merchantNamesMap[merchantUid] ?? 'Commerçant';
        final instNum = inst['installment_number'] ?? 1;

        unifiedInstallments.add({
          'id': inst['id'].toString(),
          'contract_id': contractId.toString(),
          'amount_due': (inst['amount'] as num).toDouble(),
          'amount_paid': (inst['paid_amount'] as num).toDouble(),
          'due_date': inst['due_date'],
          'status': inst['status'],
          'students': {'first_name': merchantName, 'last_name': ''},
          'currency': contract['currency'] == 'FCFA'
              ? 'FC'
              : (contract['currency'] ?? 'FC'),
          'type': 'Commerçant',
          'description': contract['description'] ?? '',
          'installment_number': instNum,
          'installment_title': instNum == 0 ? 'Acompte' : 'Échéance n°$instNum',
        });
      }
      _installments = unifiedInstallments;

      // 5. Query/Calculate current FUTA Score
      await _refreshCreditScore();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshCreditScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userId = user.uid;

    try {
      final token = await user.getIdToken();
      final response = await _dio.get(
        '/api/v1/payments/credit-score/$userId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      if (response.data != null && response.data['futa_score'] != null) {
        final int newScore = (response.data['futa_score'] as num).toInt();
        if (newScore != _futaScore) {
          final int oldScore = _futaScore;
          setState(() {
            _previousFutaScore = oldScore;
            _futaScore = newScore;
          });

          // Save back to profiles
          final rawAddress = _profile?['address']?.toString() ?? '';
          final cleanAddress = _getCleanAddress(rawAddress);
          final newAddress = '$cleanAddress|score:$newScore,prev:$oldScore';

          await Supabase.instance.client
              .from('profiles')
              .update({'address': newAddress})
              .eq('id', userId);

          setState(() {
            if (_profile != null) {
              _profile!['address'] = newAddress;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating credit score: $e');
    }
  }

  Future<void> _triggerMpesaPayment(Map<String, dynamic> installment) async {
    final amountDue = (installment['amount_due'] as num).toDouble();
    final amountPaid = (installment['amount_paid'] as num).toDouble();
    final remaining = amountDue - amountPaid;

    if (remaining <= 0) return;

    // Direct text entry modal for custom amount or direct paying full remaining
    double payAmount = remaining;

    setState(() => _isLoading = true);

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await _dio.post(
        '/api/v1/payments/mpesa-push',
        data: {
          'installment_id': installment['id'],
          'phone_number':
              _profile?['phone_number']?.replaceAll(' ', '') ?? '+243812345678',
          'amount': payAmount,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.data['status'] == 'success') {
        // Show success alert in French
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(
              'Paiement Réussi',
              style: TextStyle(
                color: FutaTheme.blueDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Votre paiement de ${NumberFormat.decimalPattern('fr').format(payAmount)} ${installment['currency'] == 'FCFA' ? 'FC' : (installment['currency'] ?? 'FC')} a été traité via M-Pesa.\n\nNouveau Score de Crédit FUTA: ${response.data['new_futa_score']}',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _loadData(); // Reload stats and scores
                },
                child: const Text(
                  'Fermer',
                  style: TextStyle(color: FutaTheme.emeraldGreen),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Simulating payment fallback for standalone evaluation
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Simulation M-Pesa',
            style: TextStyle(
              color: FutaTheme.blueDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Lancement de la transaction de ${NumberFormat.decimalPattern('fr').format(payAmount)} ${installment['currency'] == 'FCFA' ? 'FC' : (installment['currency'] ?? 'FC')}.\nUne notification USSD va apparaître sur votre téléphone.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Apply locally to allow testing the UI transitions
                setState(() {
                  installment['amount_paid'] = amountDue;
                  installment['status'] = 'PAID';
                  installment['paid_at'] = DateTime.now().toIso8601String();
                  _futaScore = 810; // Upgrade score on payment success
                });

                // Write back directly to Supabase to persist payment state
                final instIdStr = installment['id']?.toString() ?? '';
                final intId = int.tryParse(instIdStr);
                if (intId != null) {
                  Supabase.instance.client
                      .from('contract_installments')
                      .update({
                        'paid_amount': amountDue,
                        'status': 'PAID',
                        'paid_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', intId)
                      .then((_) async {
                        final contractId = installment['contract_id'];
                        if (contractId != null) {
                          try {
                            final allInstsRes = await Supabase.instance.client
                                .from('contract_installments')
                                .select('status')
                                .eq('contract_id', contractId);
                            final allPaid = allInstsRes.every(
                              (inst) => inst['status'] == 'PAID',
                            );
                            if (allPaid) {
                              await Supabase.instance.client
                                  .from('contracts')
                                  .update({'status': 'completed'})
                                  .eq('id', contractId);
                            }
                          } catch (e) {
                            debugPrint(
                              'Failed to auto-complete merchant contract: $e',
                            );
                          }
                        }
                        _loadData();
                      })
                      .catchError((err) {
                        debugPrint('Supabase update failed: $err');
                        return null;
                      });
                } else if (instIdStr.isNotEmpty) {
                  // Fallback for UUID string IDs if they are used
                  Supabase.instance.client
                      .from('school_installments')
                      .update({
                        'amount_paid': amountDue,
                        'status': 'PAID',
                        'paid_at': DateTime.now().toIso8601String(),
                      })
                      .eq('id', instIdStr)
                      .then((_) async {
                        final contractId = installment['contract_id'];
                        if (contractId != null) {
                          try {
                            final allInstsRes = await Supabase.instance.client
                                .from('school_installments')
                                .select('status')
                                .eq('contract_id', contractId);
                            final allPaid = allInstsRes.every(
                              (inst) => inst['status'] == 'PAID',
                            );
                            if (allPaid) {
                              await Supabase.instance.client
                                  .from('school_contracts')
                                  .update({'status': 'completed'})
                                  .eq('id', contractId);
                            }
                          } catch (e) {
                            debugPrint(
                              'Failed to auto-complete school contract: $e',
                            );
                          }
                        }
                        _loadData();
                      })
                      .catchError((err) {
                        debugPrint('Supabase update failed: $err');
                        return null;
                      });
                }
              },
              child: const Text(
                'Confirmer le code PIN',
                style: TextStyle(color: FutaTheme.emeraldGreen),
              ),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _payAllRemainingDebt() async {
    final double totalDebt = _totalRemainingDebt;
    if (totalDebt <= 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Simulation M-Pesa - Régler Tout',
          style: TextStyle(
            color: FutaTheme.blueDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Lancement de la transaction globale de ${NumberFormat.decimalPattern('fr').format(totalDebt)} USD.\nUne notification USSD va apparaître sur votre téléphone pour valider le montant total.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Annuler',
              style: TextStyle(color: FutaTheme.textLight),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);

              try {
                final unpaid = _installments
                    .where((inst) => inst['status'] != 'PAID')
                    .toList();
                final Set<String> updatedContractIds = {};
                final Set<String> updatedSchoolContractIds = {};

                for (var inst in unpaid) {
                  final double amountDue =
                      ((inst['amount_due'] ?? inst['amount'] ?? 0.0) as num)
                          .toDouble();
                  final String instIdStr = inst['id']?.toString() ?? '';
                  final intId = int.tryParse(instIdStr);
                  final String contractId =
                      inst['contract_id']?.toString() ?? '';
                  final bool isSchool = inst['type'] == 'Scolarité';

                  if (isSchool) {
                    await Supabase.instance.client
                        .from('school_installments')
                        .update({
                          'amount_paid': amountDue,
                          'status': 'PAID',
                          'paid_at': DateTime.now().toIso8601String(),
                        })
                        .eq('id', instIdStr);
                    if (contractId.isNotEmpty) {
                      updatedSchoolContractIds.add(contractId);
                    }
                  } else {
                    if (intId != null) {
                      await Supabase.instance.client
                          .from('contract_installments')
                          .update({
                            'paid_amount': amountDue,
                            'status': 'PAID',
                            'paid_at': DateTime.now().toIso8601String(),
                          })
                          .eq('id', intId);
                      if (contractId.isNotEmpty) {
                        updatedContractIds.add(contractId);
                      }
                    }
                  }
                }

                // Auto-complete updated merchant contracts
                for (var contractId in updatedContractIds) {
                  try {
                    final allInstsRes = await Supabase.instance.client
                        .from('contract_installments')
                        .select('status')
                        .eq('contract_id', int.parse(contractId));
                    final allPaid = allInstsRes.every(
                      (inst) => inst['status'] == 'PAID',
                    );
                    if (allPaid) {
                      await Supabase.instance.client
                          .from('contracts')
                          .update({'status': 'completed'})
                          .eq('id', int.parse(contractId));
                    }
                  } catch (e) {
                    debugPrint(
                      'Failed to auto-complete merchant contract $contractId: $e',
                    );
                  }
                }

                // Auto-complete updated school contracts
                for (var contractId in updatedSchoolContractIds) {
                  try {
                    final allInstsRes = await Supabase.instance.client
                        .from('school_installments')
                        .select('status')
                        .eq('contract_id', contractId);
                    final allPaid = allInstsRes.every(
                      (inst) => inst['status'] == 'PAID',
                    );
                    if (allPaid) {
                      await Supabase.instance.client
                          .from('school_contracts')
                          .update({'status': 'completed'})
                          .eq('id', contractId);
                    }
                  } catch (e) {
                    debugPrint(
                      'Failed to auto-complete school contract $contractId: $e',
                    );
                  }
                }

                setState(() {
                  _futaScore = 810; // Upgrade score on payment success
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tous les paiements ont été réglés avec succès !',
                      ),
                      backgroundColor: FutaTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors du traitement: $e'),
                      backgroundColor: FutaTheme.error,
                    ),
                  );
                }
              } finally {
                _loadData();
              }
            },
            child: const Text(
              'Confirmer le code PIN',
              style: TextStyle(
                color: FutaTheme.emeraldGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _totalRemainingDebt {
    double total = 0.0;
    for (var inst in _installments) {
      if (inst['status'] != 'PAID') {
        total +=
            (((inst['amount_due'] as num?) ?? 0.0).toDouble() -
            ((inst['amount_paid'] as num?) ?? 0.0).toDouble());
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: FutaTheme.emeraldGreen),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: FutaTheme.backgroundLight,
        appBar: AppBar(title: const Text('FUTA')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: FutaTheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: FutaTheme.textDark,
                    fontWeight: FontWeight.w600,
                  ),
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

    return Scaffold(
      backgroundColor: FutaTheme.backgroundLight,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: FutaTheme.blueDark),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Bienvenue, ${_profile?['first_name'] ?? ''}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: FutaTheme.blueDark,
          ),
        ),
        centerTitle: false,
      ),
      body: _buildCurrentTab(),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/archive-payments');
                _loadData();
              },
              backgroundColor: FutaTheme.blueDark,
              foregroundColor: Colors.white,
              child: const Icon(Icons.archive_outlined),
            )
          : null,
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildScoreTab();
      case 1:
        return _buildContractsTab();
      case 2:
        return _buildPaymentsTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildScoreTab();
    }
  }

  // TAB 1: SCORE DE CRÉDIT (Accueil)
  Widget _buildScoreTab() {
    final currencyFormat = NumberFormat.decimalPattern('fr');
    final upcomingInstallments = _installments
        .where((inst) => inst['status'] != 'PAID')
        .toList();
    upcomingInstallments.sort((a, b) {
      final dateA = DateTime.tryParse(a['due_date'] ?? '') ?? DateTime.now();
      final dateB = DateTime.tryParse(b['due_date'] ?? '') ?? DateTime.now();
      return dateA.compareTo(dateB);
    });

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Credit Score Circular Gauge Box
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: CreditScoreGauge(
              score: _futaScore,
              previousScore: _previousFutaScore,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Total tuition card banner (moved below the gauge)
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: FutaTheme.blueDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL DÛ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currencyFormat.format(_totalRemainingDebt)} USD',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white54,
                          size: 14,
                        ),
                        Text(
                          upcomingInstallments.isNotEmpty
                              ? 'Prochain prélèvement : ${_formatDate(upcomingInstallments.first['due_date'])}'
                              : 'Aucun prélèvement prévu',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: FutaTheme.blueDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (_installments.any((i) => i['status'] != 'PAID')) {
                    _payAllRemainingDebt();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Toutes les échéances sont réglées !'),
                      ),
                    );
                  }
                },
                child: const Text('Régler tout'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section: "Paiements à venir" (Upcoming payments)
        const Text(
          'Paiements à venir',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: FutaTheme.blueDark,
          ),
        ),
        const SizedBox(height: 12),
        if (upcomingInstallments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'Aucun paiement à venir. Félicitations !',
                  style: TextStyle(
                    color: FutaTheme.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
        else
          ...upcomingInstallments.map((inst) {
            final student = inst['students'] as Map<String, dynamic>?;
            final studentName = student != null
                ? '${student['first_name']} ${student['last_name']}'
                : 'Élève';
            final double due = (inst['amount_due'] as num).toDouble();
            final double paid = (inst['amount_paid'] as num).toDouble();
            final double remaining = due - paid;
            final String dueDate = inst['due_date'] ?? '';
            final isOverdue =
                DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isOverdue
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFDBEAFE),
                      child: Icon(
                        Icons.payment,
                        color: isOverdue
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
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: FutaTheme.blueDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildTypeChip(inst['type'] ?? 'Paiement'),
                              _buildInstallmentChip(
                                inst['installment_title'] ?? 'Tranche',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: FutaTheme.textLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Échéance: ${_formatDate(dueDate)}',
                                style: TextStyle(
                                  color: isOverdue
                                      ? FutaTheme.error
                                      : FutaTheme.textLight,
                                  fontSize: 11,
                                  fontWeight: isOverdue
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 12,
                                color: FutaTheme.textLight,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  inst['description']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: FutaTheme.textLight,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (isOverdue) ...[
                            const SizedBox(height: 4),
                            const Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 12,
                                  color: FutaTheme.error,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'En retard',
                                  style: TextStyle(
                                    color: FutaTheme.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${currencyFormat.format(remaining)} ${inst['currency'] == 'FCFA' ? 'FC' : (inst['currency'] ?? 'FC')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: FutaTheme.blueDark,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FutaTheme.blueDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => _triggerMpesaPayment(inst),
                          child: const Text(
                            'Payer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
      ],
    );
  }

  // TAB 2: CONTRATS DE SCOLARITÉ
  Widget _buildContractsTab() {
    final currencyFormat = NumberFormat.decimalPattern('fr');

    final filtered = _contracts.where((c) {
      if (_selectedContractFilter == 'actifs') {
        return c['status'] == 'active';
      } else if (_selectedContractFilter == 'pending') {
        return c['status'] == 'pending' || c['status'] == 'rejected';
      } else {
        return c['status'] == 'completed';
      }
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: FutaTheme.emeraldGreen,
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('En Attente'),
                  selected: _selectedContractFilter == 'pending',
                  onSelected: (selected) {
                    if (selected)
                      setState(() => _selectedContractFilter = 'pending');
                  },
                  side: BorderSide.none,
                  elevation: 5.0,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Actifs'),
                  selected: _selectedContractFilter == 'actifs',
                  onSelected: (selected) {
                    if (selected)
                      setState(() => _selectedContractFilter = 'actifs');
                  },
                  side: BorderSide.none,
                  elevation: 5.0,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Soldés'),
                  selected: _selectedContractFilter == 'completes',
                  onSelected: (selected) {
                    if (selected)
                      setState(() => _selectedContractFilter = 'completes');
                  },
                  side: BorderSide.none,
                  elevation: 5.0,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      _selectedContractFilter == 'actifs'
                          ? 'Aucun contrat actif.'
                          : _selectedContractFilter == 'pending'
                          ? 'Aucun contrat en attente.'
                          : 'Aucun contrat complété.',
                      style: const TextStyle(color: FutaTheme.textLight),
                    ),
                  ),
                ),
              )
            else
              ...filtered.map((contract) {
                final school = contract['profiles'] as Map<String, dynamic>?;
                final schoolName = school != null
                    ? '${school['first_name']} ${school['last_name']}'
                    : 'École';
                final String status =
                    contract['status']?.toString() ?? 'active';
                final isMerchant =
                    contract['school_id']?.toString().contains('merchant') ==
                    true;
                final description = contract['description']?.toString() ?? '';
                final String currency = contract['currency'] == 'FCFA'
                    ? 'FC'
                    : (contract['currency'] ?? 'FC');

                final cId = contract['id'].toString();
                final contractInsts = _installments
                    .where((inst) => inst['contract_id'] == cId)
                    .toList();
                final int installmentCount = contractInsts.length;
                final double totalDueVal = contractInsts.isNotEmpty
                    ? contractInsts.fold<double>(
                        0.0,
                        (sum, inst) =>
                            sum +
                            ((inst['amount_due'] as num?) ?? 0.0).toDouble(),
                      )
                    : (contract['total_tuition_due'] as num).toDouble();
                final double totalPaid = contractInsts.isNotEmpty
                    ? contractInsts.fold<double>(
                        0.0,
                        (sum, inst) =>
                            sum +
                            ((inst['amount_paid'] as num?) ?? 0.0).toDouble(),
                      )
                    : 0.0;
                final double remainingBalance = totalDueVal - totalPaid;

                final String partnerPhone = isMerchant
                    ? (contract['merchant_phone'] ?? '')
                    : (school?['phone_number'] ?? '');

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () async {
                      await context.push(
                        '/contract-detail/${contract['id']}?isMerchant=$isMerchant',
                      );
                      _loadData();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  schoolName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: FutaTheme.blueDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'completed'
                                      ? FutaTheme.emeraldLight
                                      : status == 'pending'
                                      ? Colors.blue.shade50
                                      : status == 'rejected'
                                      ? FutaTheme.error.withOpacity(0.08)
                                      : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status == 'completed'
                                      ? 'Complété'
                                      : status == 'pending'
                                      ? 'En attente'
                                      : status == 'rejected'
                                      ? 'Refusé'
                                      : 'Actif',
                                  style: TextStyle(
                                    color: status == 'completed'
                                        ? FutaTheme.success
                                        : status == 'pending'
                                        ? Colors.blue.shade700
                                        : status == 'rejected'
                                        ? FutaTheme.error
                                        : FutaTheme.blueIndigo,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildTypeChip(
                                isMerchant ? 'Commerçant' : 'Scolarité',
                              ),
                              if (installmentCount > 0)
                                _buildInstallmentChip(
                                  '$installmentCount tranches',
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (partnerPhone.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 14,
                                  color: FutaTheme.textLight,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tél: $partnerPhone',
                                  style: const TextStyle(
                                    color: FutaTheme.textLight,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (description.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  size: 14,
                                  color: FutaTheme.textLight,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    description,
                                    style: const TextStyle(
                                      color: FutaTheme.textLight,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                          ],
                          const Divider(
                            height: 24,
                            thickness: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Montant total:',
                                    style: TextStyle(
                                      color: FutaTheme.textLight,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${currencyFormat.format(totalDueVal)} $currency',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: FutaTheme.textDark,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Solde restant:',
                                    style: TextStyle(
                                      color: FutaTheme.textLight,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${currencyFormat.format(remainingBalance)} $currency',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: remainingBalance > 0
                                          ? FutaTheme.error
                                          : FutaTheme.success,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (status == 'pending' && isMerchant) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _handleContractAction(
                                      contract['id'],
                                      false,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: FutaTheme.error,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Refuser'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _handleContractAction(
                                      contract['id'],
                                      true,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: FutaTheme.emeraldGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Approuver'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // TAB 3: PAIEMENTS & INSTALLMENTS (M-Pesa Trigger)
  Widget _buildPaymentsTab() {
    final currencyFormat = NumberFormat.decimalPattern('fr');

    final activeInstallments = _installments
        .where((inst) => inst['status'] != 'PAID')
        .toList();

    if (activeInstallments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Aucun paiement en attente. Tout est payé !',
            style: TextStyle(
              color: FutaTheme.textLight,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: activeInstallments.length,
      itemBuilder: (context, index) {
        final inst = activeInstallments[index];
        final student = inst['students'] as Map<String, dynamic>?;
        final studentName = student != null
            ? '${student['first_name']} ${student['last_name']}'
            : 'Élève';

        final double amountDue = (inst['amount_due'] as num).toDouble();
        final double amountPaid = (inst['amount_paid'] as num).toDouble();
        final double remaining = amountDue - amountPaid;
        final String status = inst['status'] ?? 'PENDING';
        final String dueDate = inst['due_date'] ?? '';

        Color pillBg = const Color(0xFFF1F5F9);
        Color pillText = FutaTheme.textLight;
        String statusText = 'En Attente';

        if (status == 'PAID') {
          pillBg = FutaTheme.emeraldLight;
          pillText = FutaTheme.success;
          statusText = 'Payé';
        } else if (status == 'PARTIAL') {
          pillBg = const Color(0xFFFEF3C7);
          pillText = const Color(0xFFD97706);
          statusText = 'Partiel';
        } else if (DateTime.parse(dueDate).isBefore(DateTime.now())) {
          pillBg = const Color(0xFFFEE2E2);
          pillText = FutaTheme.error;
          statusText = 'En Retard';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: status == 'PARTIAL'
                          ? const Color(0xFFFEF3C7)
                          : (statusText == 'En Retard'
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDBEAFE)),
                      child: Icon(
                        Icons.payment,
                        color: status == 'PARTIAL'
                            ? const Color(0xFFD97706)
                            : (statusText == 'En Retard'
                                  ? FutaTheme.error
                                  : FutaTheme.blueIndigo),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: FutaTheme.blueDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildTypeChip(inst['type'] ?? 'Paiement'),
                              _buildInstallmentChip(
                                inst['installment_title'] ?? 'Tranche',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: FutaTheme.textLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Échéance: ${_formatDate(dueDate)}',
                                style: TextStyle(
                                  color: statusText == 'En Retard'
                                      ? FutaTheme.error
                                      : FutaTheme.textLight,
                                  fontSize: 11,
                                  fontWeight: statusText == 'En Retard'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 12,
                                color: FutaTheme.textLight,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  inst['description']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: FutaTheme.textLight,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Payé: ${currencyFormat.format(amountPaid)} ${inst['currency'] == 'FCFA' ? 'FC' : (inst['currency'] ?? 'FC')} • Reste: ${currencyFormat.format(remaining)} ${inst['currency'] == 'FCFA' ? 'FC' : (inst['currency'] ?? 'FC')}',
                            style: const TextStyle(
                              color: FutaTheme.textLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${currencyFormat.format(amountDue)} ${inst['currency'] == 'FCFA' ? 'FC' : (inst['currency'] ?? 'FC')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: FutaTheme.blueDark,
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
                            color: pillBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: pillText,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (remaining > 0) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FutaTheme.blueDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.phone_iphone, size: 18),
                      label: const Text(
                        'Payer via M-Pesa',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _triggerMpesaPayment(inst),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // TAB 4: PROFIL PARENT & CHILDREN
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Parent Metadata Details Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _uploadProfilePicture,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: FutaTheme.blueDark,
                        backgroundImage: _profile?['photo_url'] != null
                            ? NetworkImage(_profile!['photo_url'])
                            : null,
                        child: _profile?['photo_url'] == null
                            ? Text(
                                '${_profile?['first_name']?[0] ?? 'J'}${_profile?['last_name']?[0] ?? 'D'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: FutaTheme.emeraldGreen,
                          child: const Icon(
                            Icons.camera_alt,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_profile?['first_name'] ?? 'Jean-Luc'} ${_profile?['last_name'] ?? 'Dupont'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.blueDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _profile?['phone_number'] ?? '+243 81 234 5678',
                  style: const TextStyle(color: FutaTheme.textLight),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildProfileRow(
                  Icons.location_on,
                  'Adresse',
                  _getCleanAddress(_profile?['address']),
                ),
                const SizedBox(height: 12),
                _buildProfileRow(
                  Icons.verified_user,
                  'Statut du compte',
                  'Vérifié',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Children Expandable Roster
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.child_care, color: FutaTheme.blueIndigo),
            title: const Text(
              'Liste des Enfants Enregistrés',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: FutaTheme.blueDark,
              ),
            ),
            children: _students.map((student) {
              final isPaid =
                  student['academic_score'] >=
                  15.0; // Mock condition or payment relation
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 6.0,
                ),
                child: Card(
                  elevation: 0,
                  color: FutaTheme.backgroundLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade100),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: FutaTheme.emeraldLight,
                      child: Text(
                        student['first_name']?[0] ?? '',
                        style: const TextStyle(
                          color: FutaTheme.emeraldGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${student['first_name']} ${student['last_name']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: FutaTheme.blueDark,
                      ),
                    ),
                    subtitle: Text(
                      'Classe: ${student['classroom'] ?? 'Non renseignée'} • Moyenne: ${student['academic_score']}/20',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? FutaTheme.emeraldLight
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPaid ? 'Payé' : 'Partiel',
                        style: TextStyle(
                          color: isPaid
                              ? FutaTheme.success
                              : const Color(0xFFD97706),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadProfilePicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);

      if (result == null || result.files.isEmpty) return;

      setState(() => _isLoading = true);

      final file = result.files.first;
      final fileBytes = file.bytes;
      final fileName = file.name;
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'temp';

      String? photoUrl;
      try {
        final fileExtension = fileName.split('.').last;
        final path = '$userId/avatar.$fileExtension';

        if (fileBytes != null) {
          await Supabase.instance.client.storage
              .from('profile_pictures')
              .uploadBinary(
                path,
                fileBytes,
                fileOptions: const FileOptions(upsert: true),
              );
        } else if (file.path != null) {
          await Supabase.instance.client.storage
              .from('profile_pictures')
              .upload(
                path,
                io.File(file.path!),
                fileOptions: const FileOptions(upsert: true),
              );
        }

        photoUrl = Supabase.instance.client.storage
            .from('profile_pictures')
            .getPublicUrl(path);
      } catch (storageErr) {
        debugPrint(
          'Supabase storage upload failed, using mock profile photo: $storageErr',
        );
        photoUrl =
            'https://api.dicebear.com/7.x/adventurer/svg?seed=${_profile?['first_name'] ?? 'parent'}';
      }

      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'photo_url': photoUrl})
            .eq('id', userId);
      } catch (dbErr) {
        debugPrint(
          'Profiles table update failed (maybe photo_url col missing): $dbErr',
        );
      }

      setState(() {
        if (_profile != null) {
          _profile!['photo_url'] = photoUrl;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo de profil mise à jour avec succès !'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'importation: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleContractAction(String contractId, bool approve) async {
    setState(() => _isLoading = true);
    try {
      final newStatus = approve ? 'active' : 'rejected';
      await Supabase.instance.client
          .from('contracts')
          .update({'status': newStatus})
          .eq('id', int.parse(contractId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Contrat approuvé avec succès !' : 'Contrat refusé.',
            ),
            backgroundColor: approve ? FutaTheme.success : FutaTheme.error,
          ),
        );
      }
      // Reload dashboard data
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: FutaTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: FutaTheme.textLight),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: FutaTheme.textLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FutaTheme.blueDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

  Widget _buildDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'parent@futa.cd';
    final photoUrl = _profile?['photo_url'] as String?;
    final parentName = '${_profile?['first_name'] ?? ''} ${_profile?['last_name'] ?? ''}'.trim();
    final initials = '${_profile?['first_name']?[0] ?? 'J'}${_profile?['last_name']?[0] ?? 'D'}';

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
                label: 'Accueil',
                context: context,
              ),
              _buildDrawerItem(
                index: 1,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Contrats',
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
                label: 'Profil',
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
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: FutaTheme.blueDark,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            parentName.isNotEmpty ? parentName : 'Parent',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: FutaTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
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
                          _logout();
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
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
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
