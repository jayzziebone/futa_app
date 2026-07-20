import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';

class ArchivePaymentsScreen extends StatefulWidget {
  const ArchivePaymentsScreen({super.key});

  @override
  State<ArchivePaymentsScreen> createState() => _ArchivePaymentsScreenState();
}

class _ArchivePaymentsScreenState extends State<ArchivePaymentsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _archivedInstallments = [];

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    return dateStr.split('T').first.split(' ').first;
  }

  String _formatPaidAt(String? paidAtStr) {
    if (paidAtStr == null || paidAtStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(paidAtStr).toLocal();
      final datePart = dt.toIso8601String().split('T').first;
      final timePart = dt.toIso8601String().split('T').last.split('.').first;
      return 'Payé le $datePart à $timePart';
    } catch (e) {
      return 'Payé le $paidAtStr';
    }
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

  @override
  void initState() {
    super.initState();
    _loadArchivedPayments();
  }

  Future<void> _loadArchivedPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Aucune session utilisateur active trouvée. Veuillez vous reconnecter.");
      }
      final userId = user.uid;

      // 1. Fetch Profile to get phone number and role
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileRes == null) {
        throw Exception("Profil introuvable pour cet utilisateur.");
      }
      final clientPhone = profileRes['phone_number'] ?? '';
      final subRole = profileRes['sub_role'] ?? '';

      final List<Map<String, dynamic>> unified = [];

      if (subRole == 'merchant') {
        // Merchant flow: load completed installments for merchant's contracts
        final userRes = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('firebase_uid', userId)
            .maybeSingle();

        if (userRes != null) {
          final merchantUserId = userRes['id'] as int;

          final contractsRes = await Supabase.instance.client
              .from('contracts')
              .select()
              .eq('merchant_user_id', merchantUserId);
          
          final merchantContracts = List<Map<String, dynamic>>.from(contractsRes);

          if (merchantContracts.isNotEmpty) {
            final merchantContractIds = merchantContracts.map((c) => c['id'] as int).toList();
            final clientPhones = merchantContracts
                .map((c) => c['client_phone'] as String)
                .toList();

            Map<String, String> clientNamesMap = {};
            if (clientPhones.isNotEmpty) {
              final profilesRes = await Supabase.instance.client
                  .from('profiles')
                  .select('first_name, last_name, phone_number')
                  .inFilter('phone_number', clientPhones);
              for (var p in profilesRes) {
                final fullName = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
                clientNamesMap[p['phone_number']] = fullName.isNotEmpty ? fullName : 'Client';
              }
            }

            final merchantInstRes = await Supabase.instance.client
                .from('contract_installments')
                .select()
                .inFilter('contract_id', merchantContractIds)
                .eq('status', 'PAID');
            
            final merchantInstsRaw = List<Map<String, dynamic>>.from(merchantInstRes);
            for (var inst in merchantInstsRaw) {
              final contractId = inst['contract_id'];
              final contract = merchantContracts.firstWhere(
                (c) => c['id'] == contractId,
                orElse: () => {},
              );
              final cPhone = contract['client_phone'] ?? '';
              final clientName = clientNamesMap[cPhone] ?? 'Client';
              final instNum = inst['installment_number'] ?? 1;

              unified.add({
                'id': inst['id'].toString(),
                'contract_id': contractId.toString(),
                'amount_due': (inst['amount'] as num).toDouble(),
                'amount_paid': (inst['paid_amount'] as num).toDouble(),
                'due_date': inst['due_date'],
                'status': inst['status'],
                'partner_name': clientName,
                'type': 'Client',
                'currency': contract['currency'] == 'FCFA' ? 'FC' : (contract['currency'] ?? 'FC'),
                'paid_at': inst['paid_at'],
                'installment_number': instNum,
                'installment_title': instNum == 0 ? 'Acompte' : 'Échéance n°$instNum',
              });
            }
          }
        }
      } else {
        // Parent flow
        // 2. Fetch school contracts
        final schoolContractsRes = await Supabase.instance.client
            .from('school_contracts')
            .select()
            .eq('parent_id', userId);
        final schoolContracts = List<Map<String, dynamic>>.from(schoolContractsRes);

        // 3. Fetch school installments (all of them to compute correct index in memory)
        List<Map<String, dynamic>> schoolInstallments = [];
        if (schoolContracts.isNotEmpty) {
          final schoolContractIds = schoolContracts.map((c) => c['id']).toList();
          final schoolInstRes = await Supabase.instance.client
              .from('school_installments')
              .select('*, students(first_name, last_name)')
              .inFilter('contract_id', schoolContractIds);
          
          final allSchoolInsts = List<Map<String, dynamic>>.from(schoolInstRes);
          
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
              final dateA = DateTime.tryParse(a['due_date'] ?? '') ?? DateTime.now();
              final dateB = DateTime.tryParse(b['due_date'] ?? '') ?? DateTime.now();
              return dateA.compareTo(dateB);
            });
            for (int i = 0; i < list.length; i++) {
              list[i]['computed_number'] = i + 1;
            }
          }
          
          // Only take PAID ones
          schoolInstallments = allSchoolInsts.where((inst) => inst['status'] == 'PAID').toList();
        }

        // 4. Fetch merchant contracts
        List<Map<String, dynamic>> merchantInstallments = [];
        if (clientPhone.isNotEmpty) {
          final merchantContractsRes = await Supabase.instance.client
              .from('contracts')
              .select('*, users(firebase_uid)')
              .eq('client_phone', clientPhone);
          
          final merchantContracts = List<Map<String, dynamic>>.from(merchantContractsRes);

          if (merchantContracts.isNotEmpty) {
            final merchantContractIds = merchantContracts.map((c) => c['id'] as int).toList();
            final merchantUids = merchantContracts
                .map((c) => c['users']?['firebase_uid'])
                .where((uid) => uid != null)
                .toList();

            Map<String, String> merchantNamesMap = {};
            if (merchantUids.isNotEmpty) {
              final profilesRes = await Supabase.instance.client
                  .from('profiles')
                  .select('id, first_name, last_name')
                  .inFilter('id', merchantUids);
              for (var p in profilesRes) {
                final fullName = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
                merchantNamesMap[p['id']] = fullName.isNotEmpty ? fullName : 'Commerçant';
              }
            }

            final merchantInstRes = await Supabase.instance.client
                .from('contract_installments')
                .select()
                .inFilter('contract_id', merchantContractIds)
                .eq('status', 'PAID');
            
            final merchantInstsRaw = List<Map<String, dynamic>>.from(merchantInstRes);
            for (var inst in merchantInstsRaw) {
              final contractId = inst['contract_id'];
              final contract = merchantContracts.firstWhere(
                (c) => c['id'] == contractId,
                orElse: () => {},
              );
              final merchantUid = contract['users']?['firebase_uid'];
              final merchantName = merchantNamesMap[merchantUid] ?? 'Commerçant';
              final instNum = inst['installment_number'] ?? 1;

              merchantInstallments.add({
                'id': inst['id'].toString(),
                'contract_id': contractId.toString(),
                'amount_due': (inst['amount'] as num).toDouble(),
                'amount_paid': (inst['paid_amount'] as num).toDouble(),
                'due_date': inst['due_date'],
                'status': inst['status'],
                'partner_name': merchantName,
                'type': 'Commerçant',
                'currency': contract['currency'] == 'FCFA' ? 'FC' : (contract['currency'] ?? 'FC'),
                'paid_at': inst['paid_at'],
                'installment_number': instNum,
                'installment_title': instNum == 0 ? 'Acompte' : 'Échéance n°$instNum',
              });
            }
          }
        }

        // Merge and map school installments
        for (var inst in schoolInstallments) {
          final student = inst['students'] as Map<String, dynamic>?;
          final studentName = student != null
              ? '${student['first_name']} ${student['last_name']}'
              : 'Élève';
          final instNum = inst['computed_number'] ?? 1;

          unified.add({
            'id': inst['id'].toString(),
            'contract_id': inst['contract_id'].toString(),
            'amount_due': ((inst['amount'] ?? inst['amount_due'] ?? 0.0) as num).toDouble(),
            'amount_paid': ((inst['paid_amount'] ?? inst['amount_paid'] ?? 0.0) as num).toDouble(),
            'due_date': inst['due_date'],
            'status': inst['status'],
            'partner_name': studentName,
            'type': 'Scolarité',
            'currency': 'FC',
            'paid_at': inst['paid_at'],
            'installment_number': instNum,
            'installment_title': 'Tranche n°$instNum',
          });
        }

        unified.addAll(merchantInstallments);
      }

      // Sort by due date (newest deadlines first)
      unified.sort((a, b) {
        final dateA = DateTime.tryParse(a['due_date'] ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['due_date'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA); // Newest deadlines first
      });

      _archivedInstallments = unified;

    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.decimalPattern('fr');

    return Scaffold(
      backgroundColor: FutaTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Paiements Archivés'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FutaTheme.emeraldGreen))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: FutaTheme.error),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadArchivedPayments,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : _archivedInstallments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.archive_outlined, size: 64, color: FutaTheme.textLight.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucun paiement archivé pour le moment.',
                              style: TextStyle(color: FutaTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Les tranches de paiement entièrement réglées apparaîtront ici.',
                              style: TextStyle(color: FutaTheme.textLight, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: FutaTheme.emeraldGreen,
                      onRefresh: _loadArchivedPayments,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _archivedInstallments.length,
                        itemBuilder: (context, index) {
                          final inst = _archivedInstallments[index];
                          final amountPaid = (inst['amount_paid'] as num).toDouble();
                          final partnerName = inst['partner_name'] ?? '';
                          final type = inst['type'] ?? '';
                          final dueDate = inst['due_date'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: FutaTheme.emeraldLight,
                                    child: const Icon(
                                      Icons.check_circle_outline,
                                      color: FutaTheme.success,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          partnerName,
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
                                            _buildTypeChip(type),
                                            _buildInstallmentChip(inst['installment_title'] ?? 'Paiement'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_outlined, size: 12, color: FutaTheme.textLight),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Échéance: ${_formatDate(dueDate)}',
                                              style: const TextStyle(
                                                color: FutaTheme.textLight,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (inst['paid_at'] != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_filled_rounded, size: 12, color: FutaTheme.success),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatPaidAt(inst['paid_at']),
                                                style: const TextStyle(
                                                  color: FutaTheme.success,
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
                                    children: [
                                      Text(
                                        '${currencyFormat.format(amountPaid)} ${inst['currency'] == 'FCFA' ? 'FC' : (inst['currency'] ?? 'FC')}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: FutaTheme.success,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: FutaTheme.emeraldLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Archivé',
                                          style: TextStyle(
                                            color: FutaTheme.success,
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
                    ),
    );
  }
}
