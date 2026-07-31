import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import '../../core/theme.dart';
import '../../core/config.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _currentStep = 1;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  // Administrators specific controllers
  final _businessNameController = TextEditingController();
  final _responsibleNameController = TextEditingController();

  String _selectedRole = 'client'; // 'client' or 'admin'
  String _selectedSubRole = 'parent'; // 'parent', 'school', 'merchant'
  bool _isLoading = false;

  String _schoolAdminMode = 'create'; // 'create' or 'join'
  final _schoolCodeController = TextEditingController();
  final List<Map<String, TextEditingController>> _coAdminControllers = [];

  void _addCoAdminField() {
    if (1 + _coAdminControllers.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limite maximale de 4 administrateurs atteinte par école.'),
        ),
      );
      return;
    }
    setState(() {
      _coAdminControllers.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
        'role': TextEditingController(),
      });
    });
  }

  void _removeCoAdminField(int index) {
    setState(() {
      final controllers = _coAdminControllers.removeAt(index);
      controllers['name']?.dispose();
      controllers['phone']?.dispose();
      controllers['role']?.dispose();
    });
  }

  String? _placeholderParentId;
  String _lastCheckedPhone = '';


  Future<void> _setupSupabaseSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          Supabase.instance.client.rest.headers['Authorization'] =
              'Bearer $idToken';
          try {
            Supabase.instance.client.storage.headers['Authorization'] =
                'Bearer $idToken';
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error setting up Supabase session: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Veuillez d\'abord vous connecter avec votre numéro de téléphone.',
            ),
          ),
        );
      } else {
        if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          _phoneController.text = user.phoneNumber!;
        }
        await _setupSupabaseSession();
        if (_phoneController.text.isNotEmpty) {
          _checkExistingProfile(_phoneController.text);
        }
      }
    });
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    if (phone.length >= 10 && phone != _lastCheckedPhone) {
      _lastCheckedPhone = phone;
      _checkExistingProfile(phone);
    }
  }

  Future<void> _checkExistingProfile(String phone) async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('phone_number', phone)
          .maybeSingle();
      if (res != null) {
        final profile = res as Map<String, dynamic>;
        setState(() {
          _firstNameController.text = profile['first_name'] ?? '';
          _lastNameController.text = profile['last_name'] ?? '';
          _addressController.text = profile['address'] ?? '';
          _selectedRole = profile['role'] ?? 'client';
          _selectedSubRole = profile['sub_role'] ?? 'parent';
          _placeholderParentId = profile['id'];
          // Skip role selection if they are already identified as a parent
          if (_selectedRole == 'client') {
            _currentStep = 2;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil scolaire existant détecté et pré-rempli !'),
              backgroundColor: FutaTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking existing profile: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _responsibleNameController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);
    try {
      await _setupSupabaseSession();
      final phone = _phoneController.text.trim();
      final address = _addressController.text.trim();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
          "Aucune session utilisateur active trouvée. Veuillez vous reconnecter.",
        );
      }
      final String userId = currentUser.uid;

      if (_selectedRole == 'client') {
        final firstName = _firstNameController.text.trim();
        final lastName = _lastNameController.text.trim();

        // Migrate placeholder profile references to real Firebase UID if needed
        if (_placeholderParentId != null && _placeholderParentId != userId) {
          final token = await currentUser.getIdToken();
          final dioClient = Dio(BaseOptions(baseUrl: Config.backendUrl));
          await dioClient.post(
            '/api/v1/auth/token-exchange',
            data: {'firebase_token': token},
          );
        }

        // Upsert parent profile record
        await Supabase.instance.client.from('profiles').upsert({
          'id': userId,
          'phone_number': phone.isNotEmpty ? phone : '+243812345678',
          'first_name': firstName,
          'last_name': lastName,
          'address': address,
          'role': 'client',
          'sub_role': 'parent',
        });
      } else {
        final businessName = _businessNameController.text.trim();
        final responsibleName = _responsibleNameController.text.trim();

        if (_selectedSubRole == 'school') {
          if (_schoolAdminMode == 'create') {
            // Generate clean human-friendly invite code e.g. BOBOTO-4981
            final rawPrefix = businessName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
            final cleanPrefix = rawPrefix.length >= 4
                ? rawPrefix.substring(0, 4)
                : (rawPrefix.isNotEmpty ? rawPrefix.padRight(4, 'X') : 'SCHL');
            final randomNum = (1000 + DateTime.now().millisecondsSinceEpoch % 8999);
            final generatedInviteCode = '$cleanPrefix-$randomNum';

            // 1. Upsert to school_profiles table
            await Supabase.instance.client.from('school_profiles').upsert({
              'id': userId,
              'school_name': businessName,
              'admin_name': responsibleName,
              'phone_number': phone.isNotEmpty ? phone : '+243812345678',
              'address': address,
              'invite_code': generatedInviteCode,
              'max_admins': 4,
            });

            // 2. Insert Primary Admin #1 into school_admins
            await Supabase.instance.client.from('school_admins').upsert({
              'school_id': userId,
              'user_id': userId,
              'admin_name': responsibleName,
              'phone_number': phone.isNotEmpty ? phone : '+243812345678',
              'role_title': 'Administrateur Principal',
              'status': 'ACTIVE',
            });

            // 3. Process any co-administrators added via "+" button
            for (var controllers in _coAdminControllers) {
              final coName = controllers['name']?.text.trim() ?? '';
              final coPhone = controllers['phone']?.text.trim() ?? '';
              final coRole = controllers['role']?.text.trim() ?? '';
              if (coName.isNotEmpty && coPhone.isNotEmpty) {
                try {
                  await Supabase.instance.client.from('school_admins').insert({
                    'school_id': userId,
                    'user_id': null, // Automatically set when co-admin logs in with SMS OTP
                    'admin_name': coName,
                    'phone_number': coPhone,
                    'role_title': coRole.isNotEmpty ? coRole : 'Administrateur',
                    'status': 'PENDING_INVITE',
                  });
                } catch (coErr) {
                  debugPrint('Failed to insert co-admin invite: $coErr');
                }
              }
            }
          } else {
            // JOIN EXISTING SCHOOL VIA INVITE CODE
            final enteredCode = _schoolCodeController.text.trim().toUpperCase();
            final schoolQuery = await Supabase.instance.client
                .from('school_profiles')
                .select('*')
                .eq('invite_code', enteredCode)
                .maybeSingle();

            if (schoolQuery == null) {
              throw 'Code d\'école introuvable. Veuillez vérifier le code d\'invitation.';
            }

            final schoolId = schoolQuery['id'].toString();

            // Check admin count limit (max 4)
            final existingAdmins = await Supabase.instance.client
                .from('school_admins')
                .select('id')
                .eq('school_id', schoolId);

            if (existingAdmins.length >= 4) {
              throw 'Cette école a déjà atteint la limite maximale de 4 administrateurs.';
            }

            // Insert into school_admins mapping table
            await Supabase.instance.client.from('school_admins').upsert({
              'school_id': schoolId,
              'user_id': userId,
              'admin_name': responsibleName,
              'phone_number': phone.isNotEmpty ? phone : '+243812345678',
              'role_title': 'Administrateur',
              'status': 'ACTIVE',
            });
          }
        }
 else {
          // Upsert to merchant_profiles table
          await Supabase.instance.client.from('merchant_profiles').upsert({
            'id': userId,
            'business_name': businessName,
            'owner_name': responsibleName,
            'phone_number': phone.isNotEmpty ? phone : '+243812345678',
            'address': address,
          });

          // Also link user to merchant users table
          try {
            await Supabase.instance.client.from('users').upsert({
              'firebase_uid': userId,
              'phone': phone.isNotEmpty ? phone : '+243812345678',
              'role': 'merchant',
            });
          } catch (e) {
            debugPrint('Failed to upsert to merchant users table: $e');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte créé avec succès !')),
      );

      if (!mounted) return;

      if (_selectedRole == 'admin') {
        if (_selectedSubRole == 'school') {
          context.go('/school');
        } else {
          context.go('/merchant');
        }
      } else {
        context.go('/parent');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur d\'inscription : $e')));
      }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },

        ),
        title: const Text('FUTA'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: _buildStepContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildRoleSelectionStep();
      case 2:
        if (_selectedRole == 'client') {
          return _buildParentInfoStep();
        } else {
          return _buildAdminTypeSelectionStep();
        }
      case 3:
        if (_selectedRole == 'admin') {
          return _buildAdminInfoStep();
        }
        return _buildRoleSelectionStep();
      default:
        return _buildRoleSelectionStep();
    }
  }

  // STEP 1: Role Selection Option Card
  Widget _buildRoleSelectionStep() {
    final stepTotal = _selectedRole == 'client' ? 2 : 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ÉTAPE 1 SUR $stepTotal',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: FutaTheme.emeraldGreen,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Choisissez votre profil',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: FutaTheme.blueDark,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Personnalisez votre expérience en sélectionnant le type de compte qui vous correspond.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: FutaTheme.textLight),
        ),
        const SizedBox(height: 24),

        // Option 1: Parent
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(
                    Icons.people,
                    size: 35,
                    color: FutaTheme.blueIndigo,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Particulier',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.blueDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gérez les frais de scolarité, suivez les paiements et recevez des notifications pour vos enfants.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: FutaTheme.textLight),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide.none,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRole = 'client';
                        _selectedSubRole = 'parent';
                        _currentStep = 2;
                      });
                    },
                    child: const Text(
                      'Choisir ce profil',
                      style: TextStyle(
                        color: FutaTheme.blueDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Option 2: Administrateur
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: FutaTheme.blueDark.withOpacity(0.05),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 35,
                    color: FutaTheme.blueDark,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Administrateur',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FutaTheme.blueDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gérez votre établissement ou votre commerce, visualisez les rapports et traitez les transactions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: FutaTheme.textLight),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide.none,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRole = 'admin';
                        _currentStep = 2;
                      });
                    },
                    child: const Text(
                      'Choisir ce profil',
                      style: TextStyle(
                        color: FutaTheme.blueDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton.icon(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 16, color: FutaTheme.textLight),
            label: const Text(
              'Modifier le numéro de téléphone (Retour Connexion)',
              style: TextStyle(
                fontSize: 13,
                color: FutaTheme.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }


  // STEP 2 (Parent): Parent Form Info Card
  Widget _buildParentInfoStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ÉTAPE 2 SUR 2',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: FutaTheme.emeraldGreen,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Créer votre profil',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FutaTheme.blueDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Renseignez vos coordonnées de parent.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: FutaTheme.textLight),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'Prénom'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                hintText: '+243812345678',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Adresse'),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_firstNameController.text.trim().isEmpty ||
                          _lastNameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Veuillez remplir le nom et le prénom.',
                            ),
                          ),
                        );
                        return;
                      }
                      _submitRegistration();
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Finaliser l\'inscription'),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 2 (Admin): Admin Options (Institution vs Merchant)
  Widget _buildAdminTypeSelectionStep() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ÉTAPE 2 SUR 3',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: FutaTheme.emeraldGreen,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Type d\'administration',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FutaTheme.blueDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quel type d\'établissement administrez-vous ?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: FutaTheme.textLight),
            ),
            const SizedBox(height: 32),

            // School Option
            InkWell(
              onTap: () => setState(() => _selectedSubRole = 'school'),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedSubRole == 'school'
                        ? FutaTheme.emeraldGreen
                        : Colors.grey.shade200,
                    width: _selectedSubRole == 'school' ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.school, size: 28, color: FutaTheme.blueIndigo),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Institution / École',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Gérer les inscriptions et les frais académiques.',
                            style: TextStyle(
                              fontSize: 12,
                              color: FutaTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Merchant Option
            InkWell(
              onTap: () => setState(() => _selectedSubRole = 'merchant'),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedSubRole == 'merchant'
                        ? FutaTheme.emeraldGreen
                        : Colors.grey.shade200,
                    width: _selectedSubRole == 'merchant' ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.store, size: 28, color: FutaTheme.blueIndigo),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commerçant / Merchant',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Gérer la facturation et les paiements directs.',
                            style: TextStyle(
                              fontSize: 12,
                              color: FutaTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentStep = 3);
              },
              child: const Text('Continuer'),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 3 (Admin): Admin Profile Form Card
  Widget _buildAdminInfoStep() {
    final isSchool = _selectedSubRole == 'school';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ÉTAPE 3 SUR 3',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: FutaTheme.emeraldGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSchool ? 'Profil École' : 'Profil Commerçant',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: FutaTheme.blueDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSchool
                  ? 'Renseignez les coordonnées de l\'école.'
                  : 'Renseignez les coordonnées du commerce.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: FutaTheme.textLight),
            ),
            const SizedBox(height: 32),

            if (isSchool) ...[
              // School mode selector
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _schoolAdminMode == 'create'
                            ? FutaTheme.blueDark
                            : Colors.transparent,
                        foregroundColor: _schoolAdminMode == 'create'
                            ? Colors.white
                            : FutaTheme.blueDark,
                        side: BorderSide(
                          color: _schoolAdminMode == 'create'
                              ? FutaTheme.blueDark
                              : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => setState(() => _schoolAdminMode = 'create'),
                      child: const Text('Créer une école', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _schoolAdminMode == 'join'
                            ? FutaTheme.blueDark
                            : Colors.transparent,
                        foregroundColor: _schoolAdminMode == 'join'
                            ? Colors.white
                            : FutaTheme.blueDark,
                        side: BorderSide(
                          color: _schoolAdminMode == 'join'
                              ? FutaTheme.blueDark
                              : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => setState(() => _schoolAdminMode = 'join'),
                      child: const Text('Rejoindre une école', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if (isSchool && _schoolAdminMode == 'join') ...[
              TextField(
                controller: _schoolCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code d\'invitation de l\'école',
                  hintText: 'Ex: BOBOTO-4982',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _responsibleNameController,
                decoration: const InputDecoration(
                  labelText: 'Votre nom complet (Administrateur)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Votre téléphone de contact',
                  hintText: '+243812345678',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ] else ...[
              TextField(
                controller: _businessNameController,
                decoration: InputDecoration(
                  labelText: isSchool ? 'Nom de l\'école' : 'Nom du commerce',
                  prefixIcon: Icon(isSchool ? Icons.school_outlined : Icons.store_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: isSchool ? 'Adresse de l\'école' : 'Adresse du commerce',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 20),

              if (isSchool) ...[
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ADMINISTRATEURS (${1 + _coAdminControllers.length}/4)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FutaTheme.blueDark,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (1 + _coAdminControllers.length < 4)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: FutaTheme.emeraldGreen,
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text(
                          'Ajouter',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _addCoAdminField,
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Primary Admin #1 Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FutaTheme.blueDark.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FutaTheme.blueDark.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.stars, size: 16, color: FutaTheme.emeraldGreen),
                          SizedBox(width: 6),
                          Text(
                            'Administrateur #1 (Principal / Vous)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: FutaTheme.blueDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _responsibleNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du responsable',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone de contact',
                          hintText: '+243812345678',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Co-Administrators Cards (Admins #2, #3, #4)
                ..._coAdminControllers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ctrl = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Administrateur #${idx + 2}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: FutaTheme.blueDark,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: FutaTheme.error),
                              onPressed: () => _removeCoAdminField(idx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: ctrl['name'],
                          decoration: InputDecoration(
                            labelText: 'Nom de l\'admin #${idx + 2}',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: ctrl['phone'],
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Téléphone de l\'admin #${idx + 2}',
                            hintText: '+243812345678',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: ctrl['role'],
                          decoration: const InputDecoration(
                            labelText: 'Fonction (ex: Directeur, Comptable)',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                if (1 + _coAdminControllers.length < 4)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FutaTheme.emeraldGreen,
                      side: const BorderSide(color: FutaTheme.emeraldGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      'Ajouter un administrateur (${1 + _coAdminControllers.length}/4)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _addCoAdminField,
                  ),
              ] else ...[
                TextField(
                  controller: _responsibleNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du responsable',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone de contact',
                    hintText: '+243812345678',
                  ),
                ),
              ],
            ],

            const SizedBox(height: 32),

            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: FutaTheme.emeraldGreen,
                    ),
                  )
                : ElevatedButton(
                    onPressed: () {
                      if (isSchool && _schoolAdminMode == 'join') {
                        if (_schoolCodeController.text.trim().isEmpty ||
                            _responsibleNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez entrer le code d\'école et votre nom.'),
                            ),
                          );
                          return;
                        }
                      } else {
                        if (_businessNameController.text.trim().isEmpty ||
                            _responsibleNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isSchool
                                    ? 'Veuillez remplir le nom de l\'école et du responsable.'
                                    : 'Veuillez remplir le nom du commerce et du responsable.',
                              ),
                            ),
                          );
                          return;
                        }
                      }
                      _submitRegistration();
                    },
                    child: const Text('Finaliser l\'inscription'),
                  ),

          ],
        ),
      ),
    );
  }
}
