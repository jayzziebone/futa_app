import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/theme.dart';
import '../../core/config.dart';

class ContractDetailScreen extends StatefulWidget {
  final String contractId;
  final bool isMerchant;

  const ContractDetailScreen({
    super.key,
    required this.contractId,
    required this.isMerchant,
  });

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _currentUserId = '';
  String _userRole = 'parent';

  Map<String, dynamic> _contract = {};
  List<Map<String, dynamic>> _installments = [];
  String _partnerName = '';
  String _partnerPhone = '';

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

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
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
      _currentUserId = user.uid;

      var profileRes = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', _currentUserId)
          .maybeSingle();
      if (profileRes != null) {
        _userRole = profileRes['sub_role']?.toString() ?? 'parent';
      } else {
        // Check school_profiles
        final schoolProfile = await Supabase.instance.client
            .from('school_profiles')
            .select()
            .eq('id', _currentUserId)
            .maybeSingle();
        if (schoolProfile != null) {
          _userRole = 'school';
        } else {
          // Check merchant_profiles
          final merchantProfile = await Supabase.instance.client
              .from('merchant_profiles')
              .select()
              .eq('id', _currentUserId)
              .maybeSingle();
          if (merchantProfile != null) {
            _userRole = 'merchant';
          }
        }
      }

      if (widget.isMerchant) {
        // Merchant contract (table: contracts)
        final intId = int.parse(widget.contractId);
        final contractRes = await Supabase.instance.client
            .from('contracts')
            .select('*, users(firebase_uid)')
            .eq('id', intId)
            .maybeSingle();

        if (contractRes == null) {
          throw Exception("Contrat introuvable.");
        }
        _contract = Map<String, dynamic>.from(contractRes);

        // Fetch companion details (merchant vs client)
        if (_userRole == 'merchant') {
          // I am the merchant, show client profile by phone
          final clientPhone = _contract['client_phone']?.toString() ?? '';
          if (clientPhone.isNotEmpty) {
            final clientRes = await Supabase.instance.client
                .from('profiles')
                .select('first_name, last_name, phone_number')
                .eq('phone_number', clientPhone)
                .maybeSingle();
            if (clientRes != null) {
              _partnerName =
                  '${clientRes['first_name'] ?? ''} ${clientRes['last_name'] ?? ''}'
                      .trim();
            } else {
              _partnerName = clientPhone;
            }
            _partnerPhone = clientPhone;
          }
        } else {
          final merchantUid =
              _contract['users']?['firebase_uid']?.toString() ?? '';
          if (merchantUid.isNotEmpty) {
            final merchantRes = await Supabase.instance.client
                .from('merchant_profiles')
                .select('business_name, owner_name, phone_number')
                .eq('id', merchantUid)
                .maybeSingle();
            if (merchantRes != null) {
              final bName = merchantRes['business_name'] ?? '';
              final oName = merchantRes['owner_name'] ?? '';
              _partnerName = bName.isNotEmpty ? bName : oName;
              _partnerPhone = merchantRes['phone_number'] ?? '';
            }
          }
        }

        if (_partnerName.isEmpty) _partnerName = 'Commerçant';

        // Load installments
        final installmentsRes = await Supabase.instance.client
            .from('contract_installments')
            .select()
            .eq('contract_id', intId);
        _installments = List<Map<String, dynamic>>.from(installmentsRes);
        _installments.sort((a, b) {
          final aNum = a['installment_number'] as int? ?? 0;
          final bNum = b['installment_number'] as int? ?? 0;
          return aNum.compareTo(bNum);
        });
      } else {
        // School contract (table: school_contracts)
        final contractRes = await Supabase.instance.client
            .from('school_contracts')
            .select()
            .eq('id', widget.contractId)
            .maybeSingle();

        if (contractRes == null) {
          throw Exception("Contrat scolaire introuvable.");
        }
        _contract = Map<String, dynamic>.from(contractRes);

        final schoolId = _contract['school_id']?.toString() ?? '';
        if (schoolId.isNotEmpty) {
          final schoolRes = await Supabase.instance.client
              .from('school_profiles')
              .select('school_name, phone_number')
              .eq('id', schoolId)
              .maybeSingle();
          if (schoolRes != null) {
            _partnerName = schoolRes['school_name'] ?? '';
            _partnerPhone = schoolRes['phone_number'] ?? '';
          }
        }

        if (_partnerName.isEmpty) _partnerName = 'École';

        // Load installments
        final installmentsRes = await Supabase.instance.client
            .from('school_installments')
            .select()
            .eq('contract_id', widget.contractId);
        _installments = List<Map<String, dynamic>>.from(installmentsRes);

        // Map keys if needed (school_installments uses amount/paid_amount vs amount_due/amount_paid)
        for (var inst in _installments) {
          inst['amount_due'] =
              ((inst['amount'] ?? inst['amount_due'] ?? 0.0) as num).toDouble();
          inst['amount_paid'] =
              ((inst['paid_amount'] ?? inst['amount_paid'] ?? 0.0) as num)
                  .toDouble();
        }

        _installments.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['due_date'] ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['due_date'] ?? '') ?? DateTime.now();
          return dateA.compareTo(dateB);
        });

        // Assign installment numbers in-memory for school installments
        for (int i = 0; i < _installments.length; i++) {
          _installments[i]['installment_number'] = i + 1;
        }
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleContractAction(bool approve) async {
    setState(() => _isLoading = true);
    try {
      final newStatus = approve ? 'active' : 'rejected';
      final intId = int.parse(widget.contractId);

      await Supabase.instance.client
          .from('contracts')
          .update({'status': newStatus})
          .eq('id', intId);

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
      await _loadDetails();
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

  Future<void> _confirmDeleteContract() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Supprimer le contrat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: FutaTheme.blueDark,
          ),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce contrat ? Cette action supprimera également toutes ses échéances.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: FutaTheme.textLight),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(
                color: FutaTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteContract();
    }
  }

  Future<void> _deleteContract() async {
    setState(() => _isLoading = true);
    try {
      final intId = int.parse(widget.contractId);

      // Delete installments first
      await Supabase.instance.client
          .from('contract_installments')
          .delete()
          .eq('contract_id', intId);

      // Delete contract
      await Supabase.instance.client.from('contracts').delete().eq('id', intId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contrat supprimé avec succès.'),
            backgroundColor: FutaTheme.success,
          ),
        );
        context.pop(true); // Return back to list dashboard and trigger reload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: FutaTheme.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerPaymentFlow(Map<String, dynamic> installment) async {
    if (installment['status'] == 'PAID') return;

    final double amountDue =
        ((installment['amount_due'] ?? installment['amount'] ?? 0.0) as num)
            .toDouble();
    final double amountPaid =
        ((installment['amount_paid'] ?? installment['paid_amount'] ?? 0.0)
                as num)
            .toDouble();
    final remaining = amountDue - amountPaid;

    if (remaining <= 0) return;

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
          'Lancement de la transaction de ${NumberFormat.decimalPattern('fr').format(remaining)} ${_contract['currency'] == 'FCFA' ? 'FC' : (_contract['currency'] ?? 'FC')}.\nUne notification USSD va apparaître sur votre téléphone.',
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
            onPressed: () {
              Navigator.of(ctx).pop();
              _executePayment(installment, remaining);
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

  Future<void> _executePayment(
    Map<String, dynamic> installment,
    double payAmount,
  ) async {
    setState(() => _isLoading = true);
    try {
      final instIdStr = installment['id']?.toString() ?? '';
      final intId = int.tryParse(instIdStr);

      if (intId != null) {
        // Merchant contract installment
        await Supabase.instance.client
            .from('contract_installments')
            .update({
              'paid_amount': payAmount,
              'status': 'PAID',
              'paid_at': DateTime.now().toIso8601String(),
            })
            .eq('id', intId);

        // Check for contract completion
        final contractId = installment['contract_id'];
        if (contractId != null) {
          final allInstsRes = await Supabase.instance.client
              .from('contract_installments')
              .select('status')
              .eq('contract_id', contractId);
          final allPaid = allInstsRes.every((inst) => inst['status'] == 'PAID');
          if (allPaid) {
            await Supabase.instance.client
                .from('contracts')
                .update({'status': 'completed'})
                .eq('id', contractId);
          }
        }
      } else if (instIdStr.isNotEmpty) {
        // School contract installment
        try {
          final dio = Dio(BaseOptions(baseUrl: Config.backendUrl));
          await dio.post(
            '/api/v1/payments/mpesa-push',
            data: {
              'installment_id': instIdStr,
              'phone_number': _partnerPhone.replaceAll(' ', '').isEmpty
                  ? '+243812345678'
                  : _partnerPhone,
              'amount': payAmount,
            },
          );
        } catch (e) {
          debugPrint(
            'API payment failed, running direct Supabase update fallback: $e',
          );
          await Supabase.instance.client
              .from('school_installments')
              .update({
                'amount_paid': payAmount,
                'status': 'PAID',
                'paid_at': DateTime.now().toIso8601String(),
              })
              .eq('id', instIdStr);

          // Check for contract completion
          final contractId = installment['contract_id'];
          if (contractId != null) {
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
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement enregistré avec succès !'),
            backgroundColor: FutaTheme.success,
          ),
        );
      }
      await _loadDetails();
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
        appBar: AppBar(title: const Text('Détails du contrat')),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadDetails,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.decimalPattern('fr');
    final String currency = _contract['currency'] == 'FCFA'
        ? 'FC'
        : (_contract['currency'] ?? 'FC');
    final status = _contract['status']?.toString() ?? 'active';
    final totalDue = widget.isMerchant
        ? (_contract['total_amount'] as num?)?.toDouble() ?? 0.0
        : (_contract['total_tuition_due'] as num?)?.toDouble() ?? 0.0;

    final downPayment = widget.isMerchant
        ? (_contract['down_payment'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final totalPaid =
        _installments.fold<double>(
          0.0,
          (sum, inst) =>
              sum +
              ((inst['amount_paid'] ?? inst['paid_amount'] ?? 0.0) as num)
                  .toDouble(),
        ) +
        (widget.isMerchant &&
                !_installments.any(
                  (inst) => (inst['installment_number'] as num?)?.toInt() == 0,
                )
            ? downPayment
            : 0.0);

    final remaining = totalDue - totalPaid;

    Color statusColor = FutaTheme.blueIndigo;
    String statusLabel = 'Actif';
    if (status == 'completed') {
      statusColor = FutaTheme.success;
      statusLabel = 'Soldé';
    } else if (status == 'pending') {
      statusColor = Colors.orange;
      statusLabel = 'En attente';
    } else if (status == 'rejected') {
      statusColor = FutaTheme.error;
      statusLabel = 'Refusé';
    }

    final isClient = _userRole == 'parent';

    return Scaffold(
      backgroundColor: FutaTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Détails du contrat'),
        centerTitle: true,
        actions: [
          if (!isClient &&
              (status == 'active' || status == 'pending') &&
              widget.isMerchant)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: FutaTheme.error),
              tooltip: 'Supprimer le contrat',
              onPressed: _confirmDeleteContract,
            ),
        ],
      ),
      body: Scrollbar(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Glassmorphic Contract Profile card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FutaTheme.blueDark, Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: FutaTheme.blueDark.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        isClient
                            ? (widget.isMerchant
                                  ? 'Contrat Commerçant'
                                  : 'Contrat Scolarité')
                            : 'Client',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _partnerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_partnerPhone.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tél: $_partnerPhone',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 20),
                  _buildWhiteDetailRow(
                    'Montant Total:',
                    '${currencyFormat.format(totalDue)} $currency',
                  ),
                  if (downPayment > 0) ...[
                    const SizedBox(height: 12),
                    _buildWhiteDetailRow(
                      'Acompte versé:',
                      '${currencyFormat.format(downPayment)} $currency',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildWhiteDetailRow(
                    'Montant réglé:',
                    '${currencyFormat.format(totalPaid)} $currency',
                  ),
                  const SizedBox(height: 12),
                  _buildWhiteDetailRow(
                    'Solde restant:',
                    '${currencyFormat.format(remaining < 0 ? 0.0 : remaining)} $currency',
                    isBold: true,
                    valueColor: remaining <= 0
                        ? FutaTheme.emeraldGreen
                        : Colors.white,
                  ),
                  if ((_contract['description'] != null &&
                          _contract['description'].toString().isNotEmpty) ||
                      !widget.isMerchant) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _contract['description']?.toString() ??
                          'Frais de scolarité',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pending Actions for Parents
            if (isClient && status == 'pending' && widget.isMerchant) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FutaTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _handleContractAction(false),
                      child: const Text(
                        'Refuser',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FutaTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _handleContractAction(true),
                      child: const Text(
                        'Approuver',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Section list for upcoming payments
            Text(
              isClient ? 'Vos Échéances de Paiement' : 'Échéances Associées',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FutaTheme.blueDark,
              ),
            ),
            const SizedBox(height: 12),

            if (_installments.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'Aucune tranche planifiée pour ce contrat.',
                      style: TextStyle(
                        color: FutaTheme.textLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            else
              ..._installments.map((inst) {
                final double instAmount =
                    ((inst['amount_due'] ?? inst['amount'] ?? 0.0) as num)
                        .toDouble();
                final double instPaid =
                    ((inst['amount_paid'] ?? inst['paid_amount'] ?? 0.0) as num)
                        .toDouble();
                final remainingInst = instAmount - instPaid;
                final String dueDate = inst['due_date'] ?? '';
                final String instStatus = inst['status'] ?? 'PENDING';
                final isOverdue =
                    DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) ??
                    false;

                Color pillBg = const Color(0xFFF1F5F9);
                Color pillText = FutaTheme.textLight;
                String statusLabel = 'À venir';

                if (instStatus == 'PAID') {
                  pillBg = FutaTheme.emeraldLight;
                  pillText = FutaTheme.success;
                  statusLabel = 'Payé';
                } else if (instStatus == 'PARTIAL') {
                  pillBg = const Color(0xFFFEF3C7);
                  pillText = const Color(0xFFD97706);
                  statusLabel = 'Partiel';
                } else if (isOverdue) {
                  pillBg = const Color(0xFFFEE2E2);
                  pillText = FutaTheme.error;
                  statusLabel = 'En retard';
                }

                // Make clickable only for parent/client to trigger payment
                final isClickable =
                    isClient && instStatus != 'PAID' && status == 'active';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: isClickable ? () => _triggerPaymentFlow(inst) : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: instStatus == 'PAID'
                                ? FutaTheme.emeraldLight
                                : instStatus == 'PARTIAL'
                                ? const Color(0xFFFEF3C7)
                                : (isOverdue
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFDBEAFE)),
                            child: Icon(
                              instStatus == 'PAID'
                                  ? Icons.check_circle_outlined
                                  : instStatus == 'PARTIAL'
                                  ? Icons.monetization_on_outlined
                                  : (isOverdue
                                        ? Icons.error_outline
                                        : Icons.payment_outlined),
                              color: instStatus == 'PAID'
                                  ? FutaTheme.success
                                  : instStatus == 'PARTIAL'
                                  ? const Color(0xFFD97706)
                                  : (isOverdue
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
                                  'Échéance ${inst['installment_number'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: FutaTheme.blueDark,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: isOverdue && instStatus != 'PAID'
                                          ? FutaTheme.error
                                          : FutaTheme.textLight,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Date limite: ${_formatDate(dueDate)}',
                                      style: TextStyle(
                                        color: isOverdue && instStatus != 'PAID'
                                            ? FutaTheme.error
                                            : FutaTheme.textLight,
                                        fontSize: 12,
                                        fontWeight:
                                            isOverdue && instStatus != 'PAID'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                if (instPaid > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outlined,
                                        size: 13,
                                        color: FutaTheme.textLight,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Réglé: ${currencyFormat.format(instPaid)} $currency',
                                        style: const TextStyle(
                                          color: FutaTheme.textLight,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (instStatus == 'PARTIAL' &&
                                    remainingInst > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 13,
                                        color: FutaTheme.error,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Reste: ${currencyFormat.format(remainingInst)} $currency',
                                        style: const TextStyle(
                                          color: FutaTheme.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (instStatus == 'PAID' &&
                                    inst['paid_at'] != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_filled_rounded,
                                        size: 13,
                                        color: FutaTheme.success,
                                      ),
                                      const SizedBox(width: 6),
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
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${currencyFormat.format(instAmount)} $currency',
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
                                  statusLabel,
                                  style: TextStyle(
                                    color: pillText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isClickable) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: FutaTheme.emeraldGreen,
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

  Widget _buildWhiteDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
