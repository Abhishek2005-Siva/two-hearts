import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/firebase/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_logo.dart';

class PairingScreen extends ConsumerStatefulWidget {
  /// Pre-filled code from a deep link (twohearts:///pair?code=XXXXXX)
  final String? initialCode;
  const PairingScreen({super.key, this.initialCode});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _loading = false;
  String? _generatedCode;
  late final TextEditingController _codeController;
  String? _error;
  bool _showJoin = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    // If we received a code from a deep link, jump straight to the join view
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _showJoin = true;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createCode() async {
    setState(() { _loading = true; _error = null; });
    try {
      final code = await FirestoreService().createInviteCode();
      setState(() => _generatedCode = code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) { setState(() => _error = 'Enter the 6-letter code'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final couple = await FirestoreService().redeemInviteCode(code);
      if (couple == null && mounted) {
        setState(() => _error = 'Code not found or already used.');
      }
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.contains('PERMISSION_DENIED')
          ? 'Invalid code. Make sure you typed it correctly.'
          : msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A0820), Color(0xFF0D0408)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const AnimatedLogo(size: 52).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),
                  const SizedBox(height: 20),
                  Text('Connect\nwith your\nperson.',
                      style: Theme.of(context).textTheme.displayLarge)
                      .animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 8),
                  Text('Share a 6-letter code to pair your worlds.',
                      style: Theme.of(context).textTheme.bodyMedium)
                      .animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 40),
                  if (_generatedCode != null)
                    _CodeDisplay(code: _generatedCode!)
                  else if (_showJoin)
                    _JoinView(
                      controller: _codeController,
                      loading: _loading,
                      error: _error,
                      onRedeem: _redeemCode,
                    )
                  else
                    _ChoiceView(
                      loading: _loading,
                      onCreate: _createCode,
                      onJoin: () => setState(() => _showJoin = true),
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

// ── Choice ────────────────────────────────────────────────────────────────

class _ChoiceView extends StatelessWidget {
  final bool loading;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  const _ChoiceView({required this.loading, required this.onCreate, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OptionCard(
          icon: Icons.add_link_rounded,
          title: 'Create Invite Code',
          subtitle: 'Generate a code and share it',
          gradient: const [Color(0xFFFF6B8A), Color(0xFFFF8C42)],
          onTap: loading ? null : onCreate,
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
        const SizedBox(height: 16),
        _OptionCard(
          icon: Icons.vpn_key_rounded,
          title: 'Enter a Code',
          subtitle: 'Your partner already created one',
          gradient: const [Color(0xFF9B7EC8), Color(0xFF6B9BD2)],
          onTap: onJoin,
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),
        if (loading) ...[
          const SizedBox(height: 32),
          const Center(child: CircularProgressIndicator(color: AppColors.rose)),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback? onTap;
  const _OptionCard({required this.icon, required this.title, required this.subtitle,
      required this.gradient, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.4),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Code Display ──────────────────────────────────────────────────────────

class _CodeDisplay extends StatelessWidget {
  final String code;
  const _CodeDisplay({required this.code});

  Future<void> _shareWhatsApp(BuildContext context, String code) async {
    final link = 'twohearts:///pair?code=$code';
    final text = Uri.encodeComponent(
      'Join me on Two Hearts 💕\n\n'
      'Tap this link to connect automatically:\n$link\n\n'
      'Or open Two Hearts → Pair → Enter Code: $code',
    );

    final waUri = Uri.parse('whatsapp://send?text=$text');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri);
    } else {
      // WhatsApp not installed — fall back to system share sheet
      final shareUri = Uri.parse('https://wa.me/?text=$text');
      await launchUrl(shareUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Share this code',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.rose, AppColors.coral],
            ).createShader(bounds),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 44, fontWeight: FontWeight.bold,
                letterSpacing: 10, color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // WhatsApp share button
          GestureDetector(
            onTap: () => _shareWhatsApp(context, code),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF25D366).withValues(alpha: 0.4),
                      blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text('Share via WhatsApp',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Copy code button
          GradientButton(
            label: 'Copy Code',
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Code copied!'),
                  backgroundColor: AppColors.bgCard,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 8, height: 8,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose)),
              SizedBox(width: 10),
              Text('Waiting for your partner…',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.9, 0.9)).fadeIn();
  }
}

// ── Join View ─────────────────────────────────────────────────────────────

class _JoinView extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onRedeem;
  const _JoinView({required this.controller, required this.loading,
      this.error, required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enter code', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32, letterSpacing: 10,
              fontWeight: FontWeight.bold, color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(counterText: '', hintText: '······'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          GradientButton(label: 'Connect ♡', onTap: onRedeem, loading: loading),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}
