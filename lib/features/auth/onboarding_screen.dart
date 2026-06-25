import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_logo.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A0820), Color(0xFF0D0408)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AnimatedLogo(size: 100)
                    .animate()
                    .scale(begin: const Offset(0.5, 0.5), duration: 800.ms, curve: Curves.elasticOut),
                const SizedBox(height: 32),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [AppColors.rose, AppColors.coral],
                  ).createShader(b),
                  child: const Text(
                    'Your world\nis ready.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
                  ),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
                const Text(
                  'Everything you share here becomes\npart of your shared story.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.6),
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 60),
                GradientButton(
                  label: 'Enter Your World ♡',
                  onTap: () => context.go('/room'),
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
