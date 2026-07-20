import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  int _currentIndex = 0;
  String _merchantName = 'Commerçant';
  Map<String, dynamic>? _profile;

  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _installments = [];

  // Contract list filtering status
  String _selectedContractFilter = 'actifs'; // 'actifs', 'completes'

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    return dateStr.split('T').first.split(' ').first;
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

      // Fetch profile details from merchant_profiles
      final profileRes = await Supabase.instance.client
          .from('merchant_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // 1. Look up merchant's integer ID from the users table
      final userRes = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('firebase_uid', userId)
          .maybeSingle();

      int? merchantUserId;
      if (userRes != null) {
        merchantUserId = userRes['id'] as int;
      }

      if (profileRes != null) {
        _profile = Map<String, dynamic>.from(profileRes);
        final bName = _profile?['business_name'] as String? ?? '';
        final oName = _profile?['owner_name'] as String? ?? '';
        _merchantName = bName.isNotEmpty ? bName : oName;
        if (_merchantName.isEmpty) {
          _merchantName = 'Commerçant';
        }
      }

      // 2. Fetch Contracts (with client details from contracts table)
      if (merchantUserId != null) {
        final contractsRes = await Supabase.instance.client
            .from('contracts')
            .select()
            .eq('merchant_user_id', merchantUserId);

        _contracts = List<Map<String, dynamic>>.from(contractsRes);

        // Fetch client profiles for display names
        if (_contracts.isNotEmpty) {
          final clientPhones = _contracts
              .map((c) => c['client_phone'] as String)
              .toList();
          final profilesRes = await Supabase.instance.client
              .from('profiles')
              .select('first_name, last_name, phone_number')
              .inFilter('phone_number', clientPhones);

          final clientProfiles = List<Map<String, dynamic>>.from(profilesRes);
          // Attach client profile mapping inline to _contracts
          for (var c in _contracts) {
            final phone = c['client_phone'];
            final match = clientProfiles.firstWhere(
              (p) => p['phone_number'] == phone,
              orElse: () => {},
            );
            c['client_profile'] = match.isNotEmpty ? match : null;
          }
        }
      } else {
        _contracts = [];
      }

      // 3. Fetch Installments
      if (_contracts.isNotEmpty) {
        final contractIds = _contracts.map((c) => c['id'] as int).toList();
        final installmentsRes = await Supabase.instance.client
            .from('contract_installments')
            .select()
            .inFilter('contract_id', contractIds);
        final rawInsts = List<Map<String, dynamic>>.from(installmentsRes);

        for (var inst in rawInsts) {
          final instNum = inst['installment_number'] ?? 1;
          final contract = _contracts.firstWhere(
            (c) => c['id']?.toString() == inst['contract_id']?.toString(),
            orElse: () => {},
          );
          inst['type'] = 'Client';
          inst['installment_title'] = instNum == 0
              ? 'Acompte'
              : 'Échéance n°$instNum';
          inst['description'] = contract['description'] ?? '';
        }
        _installments = rawInsts;

        // Sort installments by due date
        _installments.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['due_date'] ?? '') ?? DateTime.now();
          final dateB =
              DateTime.tryParse(b['due_date'] ?? '') ?? DateTime.now();
          return dateA.compareTo(dateB);
        });
      } else {
        _installments = [];
      }
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
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
    if (mounted) {
      context.go('/login');
    }
  }

  Future<void> _confirmDeleteContract(dynamic contractId) async {
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
      _deleteContract(contractId);
    }
  }

  Future<void> _deleteContract(dynamic contractId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Delete associated contract installments first to prevent foreign key errors
      await Supabase.instance.client
          .from('contract_installments')
          .delete()
          .eq('contract_id', contractId);

      // 2. Delete the contract
      await Supabase.instance.client
          .from('contracts')
          .delete()
          .eq('id', contractId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contrat supprimé avec succès.'),
            backgroundColor: FutaTheme.success,
          ),
        );
      }
      _loadData(); // Reload dashboard
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
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
            'https://api.dicebear.com/7.x/adventurer/svg?seed=${_profile?['first_name'] ?? 'merchant'}';
      }

      if (photoUrl.isNotEmpty) {
        try {
          await Supabase.instance.client
              .from('merchant_profiles')
              .update({'photo_url': photoUrl})
              .eq('id', userId);
        } catch (dbErr) {
          debugPrint('Merchant profiles table update failed: $dbErr');
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de sélection de fichier: ${e.toString()}'),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _getContractForInstallment(Map<String, dynamic> inst) {
    final contractId = inst['contract_id'];
    for (var c in _contracts) {
      if (c['id'] == contractId) return c;
    }
    return null;
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
                  onPressed: _loadData,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final photoUrl = _profile?['photo_url'] as String?;
    final initials = _merchantName.isNotEmpty
        ? _merchantName[0].toUpperCase()
        : 'M';

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
          'Bienvenue, $_merchantName',
          style: const TextStyle(
            color: FutaTheme.blueDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildTabContent(),
    );
  }

  Widget _buildTabContent() {
    switch (_currentIndex) {
      case 0:
        return _buildAccueilTab();
      case 1:
        return _buildContractsTab();
      case 2:
        return _buildPaymentsTab();
      case 3:
        return _buildProfilTab();
      default:
        return _buildAccueilTab();
    }
  }

  // TAB 1: Accueil
  Widget _buildAccueilTab() {
    final currencyFormat = NumberFormat.decimalPattern('fr');
    final activeContracts = _contracts
        .where((c) => c['status'] == 'active')
        .length;
    final totalContracts = _contracts.length;

    // Calculate true financial recovery rate (collected amount / total due amount of non-pending contracts)
    double totalDueAmount = 0.0;
    double totalPaidAmount = 0.0;

    for (var c in _contracts) {
      final status = c['status']?.toString();
      if (status == 'pending') continue; // Pending contracts do not count

      final cId = c['id'].toString();
      final contractInsts = _installments.where((inst) => inst['contract_id']?.toString() == cId).toList();

      if (contractInsts.isNotEmpty) {
        for (var inst in contractInsts) {
          totalDueAmount += ((inst['amount'] ?? inst['amount_due'] ?? 0.0) as num).toDouble();
          totalPaidAmount += ((inst['paid_amount'] ?? inst['amount_paid'] ?? 0.0) as num).toDouble();
        }
      } else {
        final totalAmt = ((c['total_amount'] ?? 0.0) as num).toDouble();
        totalDueAmount += totalAmt;
        if (status == 'completed') {
          totalPaidAmount += totalAmt;
        } else {
          final dp = ((c['down_payment'] ?? 0.0) as num).toDouble();
          totalPaidAmount += dp;
        }
      }
    }

    final double recoveryRate = totalDueAmount > 0 ? (totalPaidAmount / totalDueAmount) : 0.0;

    final upcomingInstallments = _installments
        .where((inst) => inst['status'] != 'PAID')
        .take(5)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Custom Dashboard Ratio card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [FutaTheme.blueDark, Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: FutaTheme.blueDark.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'CONTRATS ACTIFS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$activeContracts / $totalContracts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Taux de recouvrement: ${(recoveryRate * 100).round()}%',
                      style: const TextStyle(
                        color: FutaTheme.emeraldGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: recoveryRate,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        color: FutaTheme.emeraldGreen,
                        strokeWidth: 9,
                      ),
                    ),
                    Center(
                      child: Text(
                        '${(recoveryRate * 100).round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: () => setState(() => _currentIndex = 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: FutaTheme.blueDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.receipt_long),
          label: const Text(
            'Gérer mes contrats client',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(height: 28),

        const Text(
          'Prochains paiements attendus',
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
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Aucun paiement en attente. Tout est soldé !',
                  style: TextStyle(
                    color: FutaTheme.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          )
        else
          ...upcomingInstallments.map((inst) {
            final contract = _getContractForInstallment(inst);
            final client = contract?['client_profile'] as Map<String, dynamic>?;
            final clientName = client != null
                ? '${client['first_name']} ${client['last_name']}'
                : 'Client';

            final double amountDue = (inst['amount'] as num).toDouble();
            final double amountPaid = (inst['paid_amount'] as num).toDouble();
            final double remaining = amountDue - amountPaid;
            final String status = inst['status'] ?? 'PENDING';
            final String dueDate = inst['due_date'] ?? '';
            final isOverdue =
                DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) ?? false;

            Color pillBg = const Color(0xFFF1F5F9);
            Color pillText = FutaTheme.textLight;
            String statusText = 'Attendu';

            if (status == 'PARTIAL') {
              pillBg = const Color(0xFFFEF3C7);
              pillText = const Color(0xFFD97706);
              statusText = 'Partiel';
            } else if (isOverdue) {
              pillBg = const Color(0xFFFEE2E2);
              pillText = FutaTheme.error;
              statusText = 'En retard';
            }

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
                        Icons.monetization_on_outlined,
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
                            clientName,
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
                              _buildTypeChip(inst['type'] ?? 'Client'),
                              _buildInstallmentChip(
                                inst['installment_title'] ?? 'Échéance',
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
                          if (amountPaid > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reçu: ${currencyFormat.format(amountPaid)} ${contract?['currency'] == 'FCFA' ? 'FC' : (contract?['currency'] ?? 'FC')} • Reste: ${currencyFormat.format(remaining)} ${contract?['currency'] == 'FCFA' ? 'FC' : (contract?['currency'] ?? 'FC')}',
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${currencyFormat.format(remaining)} ${contract?['currency'] == 'FCFA' ? 'FC' : (contract?['currency'] ?? 'FC')}',
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
              ),
            );
          }),
      ],
    );
  }

  // TAB 2: Contrats
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
                final client =
                    contract['client_profile'] as Map<String, dynamic>?;
                final clientName = client != null
                    ? '${client['first_name']} ${client['last_name']}'
                    : 'Client';
                final phone =
                    contract['client_phone'] ?? client?['phone_number'] ?? '';
                final status = contract['status']?.toString() ?? 'active';
                final description = contract['description']?.toString() ?? '';

                final cId = contract['id'].toString();
                final contractInsts = _installments
                    .where((inst) => inst['contract_id']?.toString() == cId)
                    .toList();
                final int installmentCount = contractInsts.length;
                final double totalDueVal = contractInsts.isNotEmpty
                    ? contractInsts.fold<double>(
                        0.0,
                        (sum, inst) =>
                            sum + ((inst['amount'] as num?) ?? 0.0).toDouble(),
                      )
                    : (contract['total_amount'] as num).toDouble();
                final double totalPaid = contractInsts.isNotEmpty
                    ? contractInsts.fold<double>(
                        0.0,
                        (sum, inst) =>
                            sum +
                            ((inst['paid_amount'] as num?) ?? 0.0).toDouble(),
                      )
                    : 0.0;
                final double remainingBalance = totalDueVal - totalPaid;
                final String currency = contract['currency'] == 'FCFA'
                    ? 'FC'
                    : (contract['currency'] ?? 'FC');

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () async {
                      await context.push(
                        '/contract-detail/${contract['id']}?isMerchant=true',
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
                                  clientName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: FutaTheme.blueDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
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
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: FutaTheme.error,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Supprimer le contrat',
                                    onPressed: () =>
                                        _confirmDeleteContract(contract['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildTypeChip('Client'),
                              if (installmentCount > 0)
                                _buildInstallmentChip(
                                  '$installmentCount tranches',
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (phone.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 14,
                                  color: FutaTheme.textLight,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tél: $phone',
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
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/create-contract');
          if (result == true) {
            _loadData(); // Reload contracts
          }
        },
        backgroundColor: FutaTheme.blueDark,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // TAB 3: Paiements
  Widget _buildPaymentsTab() {
    final currencyFormat = NumberFormat.decimalPattern('fr');
    final activeInstallments = _installments
        .where((inst) => inst['status'] != 'PAID')
        .toList();

    if (activeInstallments.isEmpty) {
      return Scaffold(
        backgroundColor: FutaTheme.backgroundLight,
        body: const Center(
          child: Text(
            'Aucune tranche active planifiée.',
            style: TextStyle(color: FutaTheme.textLight),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await context.push('/archive-payments');
            _loadData();
          },
          backgroundColor: FutaTheme.blueDark,
          foregroundColor: Colors.white,
          child: const Icon(Icons.archive_outlined),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FutaTheme.backgroundLight,
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: activeInstallments.length,
        itemBuilder: (context, index) {
          final inst = activeInstallments[index];
          final contract = _getContractForInstallment(inst);
          final client = contract?['client_profile'] as Map<String, dynamic>?;
          final clientName = client != null
              ? '${client['first_name']} ${client['last_name']}'
              : 'Client';

          final double amountDue = (inst['amount'] as num).toDouble();
          final double amountPaid = (inst['paid_amount'] as num).toDouble();
          final double remaining = amountDue - amountPaid;
          final String status = inst['status'] ?? 'PENDING';
          final String dueDate = inst['due_date'] ?? '';

          Color pillBg = const Color(0xFFF1F5F9);
          Color pillText = FutaTheme.textLight;
          String statusLabel = 'À venir';

          if (status == 'PAID') {
            pillBg = FutaTheme.emeraldLight;
            pillText = FutaTheme.success;
            statusLabel = 'Payé';
          } else if (status == 'PARTIAL') {
            pillBg = const Color(0xFFFEF3C7);
            pillText = const Color(0xFFD97706);
            statusLabel = 'Partiel';
          } else {
            final isOverdue =
                DateTime.tryParse(dueDate)?.isBefore(DateTime.now()) ?? false;
            if (isOverdue) {
              pillBg = const Color(0xFFFEE2E2);
              pillText = FutaTheme.error;
              statusLabel = 'En retard';
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: status == 'PARTIAL'
                        ? const Color(0xFFFEF3C7)
                        : (statusLabel == 'En retard'
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDBEAFE)),
                    child: Icon(
                      Icons.monetization_on_outlined,
                      color: status == 'PARTIAL'
                          ? const Color(0xFFD97706)
                          : (statusLabel == 'En retard'
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
                          clientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: FutaTheme.blueDark,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildTypeChip(inst['type'] ?? 'Client'),
                            _buildInstallmentChip(
                              inst['installment_title'] ?? 'Échéance',
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
                                color: statusLabel == 'En retard'
                                    ? FutaTheme.error
                                    : FutaTheme.textLight,
                                fontSize: 11,
                                fontWeight: statusLabel == 'En retard'
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
                        if (amountPaid > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reçu: ${currencyFormat.format(amountPaid)} ${contract?['currency'] == 'FCFA' ? 'FC' : (contract?['currency'] ?? 'FC')} • Reste: ${currencyFormat.format(remaining)} ${contract?['currency'] == 'FCFA' ? 'FC' : (contract?['currency'] ?? 'FC')}',
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
                        '${currencyFormat.format(amountDue)} ${contract?['currency'] == 'FCFA' ? 'FC' : (contract?['currency'] ?? 'FC')}',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/archive-payments');
          _loadData();
        },
        backgroundColor: FutaTheme.blueDark,
        foregroundColor: Colors.white,
        child: const Icon(Icons.archive_outlined),
      ),
    );
  }

  // TAB 4: Profil
  Widget _buildProfilTab() {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = _profile?['photo_url'] as String?;
    final initials = _merchantName.isNotEmpty
        ? _merchantName[0].toUpperCase()
        : 'M';

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _uploadProfilePicture,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: FutaTheme.emeraldLight,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: FutaTheme.emeraldGreen,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: FutaTheme.blueDark,
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Text(
                        _merchantName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: FutaTheme.blueDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Commerçant FUTA',
                        style: TextStyle(
                          color: FutaTheme.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'INFORMATIONS DE CONNEXION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.textLight,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoDetailRow(
                  'Numéro de téléphone',
                  user?.phoneNumber ??
                      _profile?['phone_number'] ??
                      'Non renseigné',
                ),
                const SizedBox(height: 16),
                _buildInfoDetailRow(
                  'ID Partenaire Commerçant',
                  user?.uid ?? 'Non renseigné',
                ),
                const SizedBox(height: 16),
                _buildInfoDetailRow(
                  'Adresse Physique',
                  _profile?['address'] ?? 'Non renseignée',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: FutaTheme.textLight, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: FutaTheme.blueDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'merchant@futa.cd';
    final photoUrl = _profile?['photo_url'] as String?;
    final initials = _merchantName.isNotEmpty ? _merchantName[0].toUpperCase() : 'M';

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
                      backgroundColor: FutaTheme.emeraldLight,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: FutaTheme.emeraldGreen,
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
                            _merchantName,
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
