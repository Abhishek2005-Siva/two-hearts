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
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
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
                        ],
                        _Field(
                          controller: _email,
                          hint: 'Email address',
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
