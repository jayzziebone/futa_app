import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class CreateContractScreen extends StatefulWidget {
  const CreateContractScreen({super.key});

  @override
  State<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientPhoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _installmentsController = TextEditingController(text: '3');

  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCurrency = 'FC';
  String _billingFrequency = 'monthly'; // 'weekly' or 'monthly'

  @override
  void dispose() {
    _clientPhoneController.dispose();
    _descriptionController.dispose();
    _totalAmountController.dispose();
    _downPaymentController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  Future<void> _submitContract() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Aucune session utilisateur active trouvée. Veuillez vous reconnecter.");
      }
      final merchantId = user.uid;

      final phoneCleaned = _clientPhoneController.text.trim();
      final totalAmount = double.parse(_totalAmountController.text.trim());
      final downPayment = double.tryParse(_downPaymentController.text.trim()) ?? 0.0;
      final installmentsCount = int.parse(_installmentsController.text.trim());

      if (downPayment >= totalAmount) {
        throw Exception("L'acompte ne peut pas être supérieur ou égal au montant total.");
      }

      // 1. Look up merchant's integer ID from the users table
      final userRes = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('firebase_uid', merchantId)
          .maybeSingle();

      int merchantUserId;
      if (userRes != null) {
        merchantUserId = userRes['id'] as int;
      } else {
        // If not found in users table, insert a mock user entry to satisfy FK constraint
        final insertUser = await Supabase.instance.client.from('users').insert({
          'firebase_uid': merchantId,
          'phone': user.phoneNumber ?? '',
          'role': 'merchant',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();
        merchantUserId = insertUser['id'] as int;
      }

      // 2. Insert contract into contracts (merchant contract table)
      final contractInsert = await Supabase.instance.client.from('contracts').insert({
        'merchant_user_id': merchantUserId,
        'client_phone': phoneCleaned,
        'currency': _selectedCurrency,
        'total_amount': totalAmount,
        'down_payment': downPayment,
        'installments_count': installmentsCount,
        'status': 'pending',
        'description': _descriptionController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      final contractId = contractInsert['id'] as int;

      // 3. Generate installments in contract_installments
      final List<Map<String, dynamic>> installments = [];
      final remainingAmount = totalAmount - downPayment;

      // Down payment installment
      if (downPayment > 0) {
        installments.add({
          'contract_id': contractId,
          'installment_number': 0,
          'due_date': DateTime.now().toIso8601String().split('T').first,
          'amount': downPayment,
          'paid_amount': downPayment,
          'status': 'PAID',
        });
      }

      // Regular installments
      final installmentAmount = remainingAmount / installmentsCount;
      final daysInterval = _billingFrequency == 'weekly' ? 7 : 30;
      for (int i = 1; i <= installmentsCount; i++) {
        final dueDate = DateTime.now().add(Duration(days: daysInterval * i));
        installments.add({
          'contract_id': contractId,
          'installment_number': i,
          'due_date': dueDate.toIso8601String().split('T').first,
          'amount': double.parse(installmentAmount.toStringAsFixed(2)),
          'paid_amount': 0.0,
          'status': 'PENDING',
        });
      }

      await Supabase.instance.client.from('contract_installments').insert(installments);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Contrat Créé', style: TextStyle(color: FutaTheme.blueDark, fontWeight: FontWeight.bold)),
            content: const Text(
              'Le contrat a été enregistré et les échéances ont été générées avec succès.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // Close dialog
                  context.pop(true); // Return true to trigger refresh
                },
                child: const Text('OK', style: TextStyle(color: FutaTheme.emeraldGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FutaTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Nouveau Contrat'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FutaTheme.emeraldGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Création de contrat client',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: FutaTheme.blueDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Remplissez les détails pour générer les échéances de paiement.',
                      style: TextStyle(color: FutaTheme.textLight, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FutaTheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: FutaTheme.error.withOpacity(0.2)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: FutaTheme.error, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _clientPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Numéro de téléphone client',
                                hintText: '+243812345678',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Veuillez saisir le numéro de téléphone.';
                                }
                                if (!val.trim().startsWith('+')) {
                                  return 'Le format doit commencer par + (ex: +243...)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Abonnement / Achat matériel / Service',
                                prefixIcon: Icon(Icons.description_outlined),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Veuillez renseigner une description.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCurrency,
                                    decoration: const InputDecoration(
                                      labelText: 'Devise',
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'FC', child: Text('FC')),
                                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedCurrency = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _totalAmountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Montant Total',
                                      hintText: 'Montant',
                                      prefixIcon: Icon(Icons.monetization_on),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Obligatoire';
                                      }
                                      if (double.tryParse(val.trim()) == null ||
                                          double.parse(val.trim()) <= 0) {
                                        return 'Invalide';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _downPaymentController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Acompte',
                                      hintText: 'Optionnel',
                                      prefixIcon: Icon(Icons.check_circle_outline),
                                    ),
                                    validator: (val) {
                                      if (val != null && val.trim().isNotEmpty) {
                                        if (double.tryParse(val.trim()) == null ||
                                            double.parse(val.trim()) < 0) {
                                          return 'Invalide';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _installmentsController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "Nombre d'échéances",
                                      prefixIcon: Icon(Icons.calendar_month_outlined),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Veuillez saisir le nombre d\'échéances.';
                                      }
                                      final numVal = int.tryParse(val.trim());
                                      if (numVal == null || numVal <= 0) {
                                        return 'Doit être supérieur à 0.';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _billingFrequency,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Fréquence',
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'weekly', child: Text('Hebdomadaire')),
                                      DropdownMenuItem(value: 'monthly', child: Text('Mensuelle')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _billingFrequency = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _submitContract,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: FutaTheme.blueDark,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Créer le contrat client',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
