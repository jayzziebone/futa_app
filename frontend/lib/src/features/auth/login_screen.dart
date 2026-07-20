import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  String _selectedPrefix = '+243'; // Default DRC prefix
  String? _verificationId;

  late AnimationController _logoEntranceController;
  late AnimationController _logoFloatController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoFloat;

  @override
  void initState() {
    super.initState();
    _logoEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..value = 1.0;
    _logoScale = const AlwaysStoppedAnimation<double>(1.0);
    _logoOpacity = const AlwaysStoppedAnimation<double>(1.0);
    _logoFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _logoFloat = const AlwaysStoppedAnimation<double>(0.0);

    // Start floating animation after page transition (Hero flight) completes
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _logoFloat = Tween<double>(begin: -6.0, end: 6.0).animate(
            CurvedAnimation(
              parent: _logoFloatController,
              curve: Curves.easeInOut,
            ),
          );
        });
        _logoFloatController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _logoEntranceController.dispose();
    _logoFloatController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber {
    String raw = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
    if (raw.startsWith('0')) {
      raw = raw.substring(1);
    }
    return '$_selectedPrefix$raw';
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un numéro de téléphone valide.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _fullPhoneNumber;

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential = await FirebaseAuth.instance
                .signInWithCredential(credential);
            final user = userCredential.user;
            if (user != null) {
              await _handlePostLogin(user.uid);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Erreur de connexion automatique: ${e.toString()}',
                  ),
                ),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Erreur de vérification: ${e.message ?? e.toString()}',
                ),
              ),
            );
            setState(() => _isLoading = false);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _codeSent = true;
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Code de vérification envoyé par SMS.'),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePostLogin(String uid) async {
    try {
      debugPrint('FUTA Auth: Starting post-login for Firebase UID: $uid');
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final idToken = await firebaseUser.getIdToken();
        if (idToken != null) {
          debugPrint(
            'FUTA Auth: Setting Supabase headers using Firebase ID token...',
          );
          Supabase.instance.client.rest.headers['Authorization'] =
              'Bearer $idToken';
          try {
            Supabase.instance.client.storage.headers['Authorization'] =
                'Bearer $idToken';
          } catch (_) {}
        }
      }

      debugPrint('FUTA Auth: Querying Supabase profiles for id: $uid');
      var response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      String role = 'client';
      String subRole = 'parent';

      if (response != null) {
        role = response['role'] ?? 'client';
        subRole = response['sub_role'] ?? 'parent';
      } else {
        // Check school profiles
        final schoolProfile = await Supabase.instance.client
            .from('school_profiles')
            .select()
            .eq('id', uid)
            .maybeSingle();
        if (schoolProfile != null) {
          role = 'admin';
          subRole = 'school';
          response = schoolProfile;
        } else {
          // Check merchant profiles
          final merchantProfile = await Supabase.instance.client
              .from('merchant_profiles')
              .select()
              .eq('id', uid)
              .maybeSingle();
          if (merchantProfile != null) {
            role = 'admin';
            subRole = 'merchant';
            response = merchantProfile;
          }
        }
      }

      debugPrint('FUTA Auth: Supabase profile query response: $response');

      if (!mounted) return;

      if (response != null) {
        debugPrint(
          'FUTA Auth: Routing user based on role: $role, subRole: $subRole',
        );

        if (subRole == 'merchant') {
          context.go('/merchant');
        } else if (role == 'admin' || subRole == 'school') {
          context.go('/school');
        } else {
          context.go('/parent');
        }
      } else {
        debugPrint('FUTA Auth: Profile not found. Routing to /register');
        context.go('/register');
      }
    } catch (e, stack) {
      debugPrint('FUTA Auth ERROR: Exception in post-login token exchange: $e');
      debugPrint('FUTA Auth ERROR Stack: $stack');
      if (mounted) {
        context.go('/parent');
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer le code de vérification.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_verificationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Identifiant de vérification introuvable. Veuillez renvoyer le code.',
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        await _handlePostLogin(user.uid);
      } else {
        throw Exception("L'utilisateur n'a pas pu être authentifié.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code incorrect ou expiré. Veuillez réessayer.'),
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
    return Scaffold(
      body: Container(
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
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Section: Animated Logo
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 60.0,
                            bottom: 110.0,
                            left: 24.0,
                            right: 24.0,
                          ),
                          child: Column(
                            children: [
                              FadeTransition(
                                opacity: _logoOpacity,
                                child: ScaleTransition(
                                  scale: _logoScale,
                                  child: AnimatedBuilder(
                                    animation: _logoFloatController,
                                    builder: (context, child) {
                                      return Transform.translate(
                                        offset: Offset(0, _logoFloat.value),
                                        child: Hero(
                                          tag: 'brand-logo',
                                          child: Image.asset(
                                            'assets/futa_new_logo.png',
                                            width: 200,
                                            height: 200,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    width: 90,
                                                    height: 90,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white24,
                                                      ),
                                                    ),
                                                    child: const Center(
                                                      child: Material(
                                                        type: MaterialType
                                                            .transparency,
                                                        child: Icon(
                                                          Icons.layers_outlined,
                                                          color: FutaTheme
                                                              .blueDark,
                                                          size: 40,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Center(
                                child: Text(
                                  'FUTA',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Center(
                                child: Text(
                                  'Gérez vos frais scolaires en toute sécurité.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // White Container stretching to the bottom, left, and right
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(28),
                                topRight: Radius.circular(28),
                              ),
                            ),
                            padding: EdgeInsets.only(
                              left: 24.0,
                              right: 24.0,
                              top: 36.0,
                              bottom: 24.0 + MediaQuery.of(context).padding.bottom,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: _codeSent
                                      ? _buildOtpSection()
                                      : _buildPhoneSection(),
                                ),
                                const Spacer(),
                                const SizedBox(height: 24),
                                const Text(
                                  'By signing up you are agreeing to our Terms & Conditions and Privacy policy',
                                  textAlign: TextAlign.center,
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
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneSection() {
    return Column(
      key: const ValueKey('phone_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Numéro de téléphone',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FutaTheme.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(30),
              ),
              child: CountryCodePicker(
                onChanged: (country) {
                  if (country.dialCode != null) {
                    setState(() => _selectedPrefix = country.dialCode!);
                  }
                },
                initialSelection: 'CD',
                favorite: const ['CD', 'CG'],
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                alignLeft: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(
                  color: FutaTheme.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                dialogTextStyle: const TextStyle(
                  color: FutaTheme.textDark,
                  fontSize: 14,
                ),
                searchStyle: const TextStyle(
                  color: FutaTheme.textDark,
                  fontSize: 14,
                ),
                searchDecoration: InputDecoration(
                  hintText: 'Rechercher un pays...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: FutaTheme.textLight,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(
                  color: FutaTheme.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: FutaTheme.blueDark,
                  ),
                  hintText: '--- --- ----',
                  hintStyle: const TextStyle(
                    color: Colors.black26,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(
                      color: FutaTheme.blueDark,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Action Button
        _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: FutaTheme.blueDark),
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FutaTheme.blueDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _sendOtp,
                  child: const Text(
                    'Continuer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildOtpSection() {
    return Column(
      key: const ValueKey('otp_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Code de vérification',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: FutaTheme.textDark,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: FutaTheme.textDark,
            letterSpacing: 8.0,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: FutaTheme.blueDark,
            ),
            hintText: '••••••',
            hintStyle: const TextStyle(
              color: Colors.black26,
              letterSpacing: 8.0,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(
                color: FutaTheme.blueDark,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: FutaTheme.blueDark),
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FutaTheme.blueDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _verifyOtp,
                  child: const Text(
                    'Vérifier et Se Connecter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _codeSent = false),
          child: const Text(
            'Modifier le numéro',
            style: TextStyle(
              color: FutaTheme.blueDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
