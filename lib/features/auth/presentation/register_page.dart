import 'package:flutter/material.dart';
import '../../../shared/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/localization/app_localizations.dart';
import '../logic/auth_validators.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return e.message ?? 'Account creation failed.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    // Do NOT trim the password — leading/trailing whitespace is rejected by
    // the validator, but trimming silently would mask the user's mistake.
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final nameError = AuthValidators.displayName(name);
    if (nameError != null) {
      _showError(nameError);
      return;
    }
    final emailError = AuthValidators.email(email);
    if (emailError != null) {
      _showError(emailError);
      return;
    }
    final passwordError = AuthValidators.passwordForRegister(password);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }
    final confirmError =
        AuthValidators.confirmPassword(password, confirmPassword);
    if (confirmError != null) {
      _showError(confirmError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;

      // The account exists and the user is now signed in. Updating the
      // display name and writing the profile document is best-effort — if
      // it fails we still take the user into the app rather than stranding
      // them on this page.
      if (user != null) {
        try {
          // Ensure the freshly-minted auth token is available before the
          // Firestore write. A not-yet-propagated token is the most common
          // reason the profile write fails right after sign-up.
          await user.getIdToken();

          if (name.isNotEmpty) {
            await user.updateDisplayName(name);
          }

          final profile = <String, dynamic>{
            'uid': user.uid,
            'displayName': name.isNotEmpty ? name : email.split('@').first,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          };
          final docRef =
              FirebaseFirestore.instance.collection('users').doc(user.uid);

          try {
            await docRef.set(profile);
          } catch (e) {
            // Retry once after a short delay — covers a transient
            // auth-token propagation race on the first write.
            debugPrint('Register: profile write failed, retrying once: $e');
            await Future<void>.delayed(const Duration(milliseconds: 600));
            await docRef.set(profile);
          }
        } catch (e) {
          debugPrint('Register: profile setup failed: $e');
        }
      }

      // createUserWithEmailAndPassword already signs the user in, so take
      // them straight into the app instead of back to the login page.
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.homeDashboard);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_mapAuthError(e));
    } catch (e) {
      if (!mounted) return;
      _showError('Account creation failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeIn),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    Future.delayed(
        const Duration(milliseconds: 150), () => _contentController.forward());
  }

  @override
  void dispose() {
    _contentController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: AppColors.black,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D0D),
                  Color(0xFF1A1200),
                  Color(0xFF0D0D0D),
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: -80,
                    right: -80,
                    child: _GlowCircle(
                      size: 280,
                      color: AppColors.gold.withOpacity(0.07),
                    ),
                  ),
                  Positioned(
                    bottom: -100,
                    left: -60,
                    child: _GlowCircle(
                      size: 320,
                      color: AppColors.gold.withOpacity(0.05),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: AnimatedBuilder(
                      animation: _contentController,
                      builder: (context, child) => SlideTransition(
                        position: _slideUp,
                        child: Opacity(opacity: _fadeIn.value, child: child),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 48),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushReplacementNamed(AppRoutes.login),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: AppColors.gold.withOpacity(0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.gold,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [AppColors.goldLight, AppColors.gold],
                            ).createShader(bounds),
                            child: Text(
                              S.of('create_account_title'),
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.5,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            S.of('create_account_subtitle'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 36),
                          _buildLabel(S.of('full_name')),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _nameController,
                            hint: S.of('name_hint'),
                            icon: Icons.person_outline_rounded,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 20),
                          _buildLabel(S.of('email')),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hint: S.of('email_hint'),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 20),
                          _buildLabel(S.of('password')),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _passwordController,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            maxLength: AuthValidators.passwordMaxLength,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.gold.withOpacity(0.6),
                                size: 20,
                              ),
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 13,
                                  color: AppColors.gold.withOpacity(0.55),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    S.of('password_requirements_hint'),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.45),
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildLabel(S.of('confirm_password')),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscureConfirm,
                            maxLength: AuthValidators.passwordMaxLength,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.gold.withOpacity(0.6),
                                size: 20,
                              ),
                              onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          const SizedBox(height: 36),
                          _buildGoldButton(
                            label: S.of('create_account_btn'),
                            isLoading: _isLoading,
                            onTap: _isLoading ? null : _register,
                          ),
                          const SizedBox(height: 28),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.login),
                              child: RichText(
                                text: TextSpan(
                                  text: S.of('already_have_account'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 14,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: S.of('sign_in_link'),
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 16,
                    child: const LanguageSwitcher(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(
      color: Colors.white.withOpacity(0.7),
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: AppColors.gold.withOpacity(0.2), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 15),
          prefixIcon:
          Icon(icon, color: AppColors.gold.withOpacity(0.5), size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          counterText: '',
          contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildGoldButton({
    required String label,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.black),
          )
              : Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

