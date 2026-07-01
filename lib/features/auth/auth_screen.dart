import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firestore_service.dart';
import '../../core/firebase/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_logo.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  bool _obscure = true;
  String? _error;
  DateTime? _dob;
  String? _gender;

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        final input = _email.text.trim();
        String email = input;
        if (!input.contains('@')) {
          // Treat as username — look up email
          final found = await FirestoreService().getEmailByUsername(input);
          if (found == null) {
            setState(() => _error = 'Username not found.');
            return;
          }
          email = found;
        }
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _password.text.trim(),
        );
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text.trim(),
        );
        await cred.user?.updateDisplayName(_name.text.trim());
        if (cred.user != null) {
          await FirestoreService().createUser(UserModel(
            uid: cred.user!.uid,
            displayName: _name.text.trim(),
            email: _email.text.trim(),
            username: _username.text.trim().isEmpty ? null : _username.text.trim(),
            birthday: _dob,
            gender: _gender,
          ));
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found': return 'No account with that email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'email-already-in-use': return 'That email is already taken.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email.';
      default: return 'Something went wrong. Try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A0820), Color(0xFF0D0408), Color(0xFF12060E)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.rose.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.coral.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  Center(
                    child: const AnimatedLogo(size: 72)
                        .animate()
                        .scale(begin: const Offset(0.5, 0.5), duration: 700.ms, curve: Curves.elasticOut),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Two Hearts',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [AppColors.rose, AppColors.coral],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ),
                  Center(
                    child: Text(
                      'A private world for two.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(delay: 400.ms),
                  ),
                  const SizedBox(height: 48),
                  GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLogin ? 'Welcome back' : 'Create account',
                          style: Theme.of(context).textTheme.titleLarge,
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 24),
                        if (!_isLogin) ...[
                          _Field(
                            controller: _name,
                            hint: 'Your name',
                            icon: Icons.person_outline_rounded,
                          ).animate().fadeIn(delay: 250.ms).slideX(begin: -0.05),
                          const SizedBox(height: 14),
                          _Field(
                            controller: _username,
                            hint: 'Username (optional)',
                            icon: Icons.alternate_email_rounded,
                          ).animate().fadeIn(delay: 260.ms).slideX(begin: -0.05),
                          const SizedBox(height: 14),
                          // DOB picker row
                          GestureDetector(
                            onTap: _pickDob,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cake_outlined, color: AppColors.textMuted, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    _dob == null
                                        ? 'Date of birth (optional)'
                                        : '${_dob!.day.toString().padLeft(2, '0')} / ${_dob!.month.toString().padLeft(2, '0')} / ${_dob!.year}',
                                    style: TextStyle(
                                      color: _dob == null ? AppColors.textMuted : AppColors.textPrimary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: 270.ms).slideX(begin: -0.05),
                          const SizedBox(height: 14),
                          // Gender selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _GenderChip(
                                label: '👦 Male',
                                selected: _gender == 'male',
                                onTap: () => setState(() => _gender = 'male'),
                              ),
                              const SizedBox(width: 10),
                              _GenderChip(
                                label: '👧 Female',
                                selected: _gender == 'female',
                                onTap: () => setState(() => _gender = 'female'),
                              ),
                              const SizedBox(width: 10),
                              _GenderChip(
                                label: 'Skip',
                                selected: _gender == null,
                                onTap: () => setState(() => _gender = null),
                              ),
                            ],
                          ).animate().fadeIn(delay: 285.ms),
                          const SizedBox(height: 14),
                        ],
                        _Field(
                          controller: _email,
                          hint: _isLogin ? 'Email or username' : 'Email address',
                          icon: Icons.mail_outline_rounded,
                          keyboard: TextInputType.emailAddress,
                        ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05),
                        const SizedBox(height: 14),
                        _Field(
                          controller: _password,
                          hint: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.05),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        GradientButton(
                          label: _isLogin ? 'Sign In' : 'Create Account',
                          onTap: _submit,
                          loading: _loading,
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() { _isLogin = !_isLogin; _error = null; }),
                      child: Text(
                        _isLogin ? "Don't have an account?  Sign up →" : 'Already have an account?  Sign in →',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.rose.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.rose : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.5 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? AppColors.rose : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboard,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}
