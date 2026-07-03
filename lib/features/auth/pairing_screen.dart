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
  bool _codeLoading = false;
  bool _joinLoading = false;
  String? _generatedCode;
  final _joinCtrl = TextEditingController();
  String? _joinError;
  bool _showJoin = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _joinCtrl.text = widget.initialCode!;
      _showJoin = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _createCode());
    }
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _createCode() async {
    setState(() { _codeLoading = true; });
    try {
      final code = await FirestoreService().createInviteCode();
      if (mounted) setState(() => _generatedCode = code);
    } catch (e) {
      if (mounted) setState(() => _generatedCode = null);
    } finally {
      if (mounted) setState(() => _codeLoading = false);
    }
  }

  Future<void> _redeemCode() async {
    final code = _joinCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _joinError = 'Enter the 6-letter code');
      return;
    }
    setState(() { _joinLoading = true; _joinError = null; });
    try {
      final couple = await FirestoreService().redeemInviteCode(code);
      if (couple == null && mounted) {
        setState(() => _joinError = 'Code not found or already used.');
      }
    } catch (e) {
      final msg = e.toString();
      setState(() => _joinError = msg.contains('PERMISSION_DENIED')
          ? 'Invalid code. Make sure you typed it correctly.'
          : msg);
    } finally {
      if (mounted) setState(() => _joinLoading = false);
    }
  }

  Future<void> _shareWhatsApp(String code) async {
    final link = 'twohearts:///pair?code=$code';
    final text = Uri.encodeComponent(
      'Join me on Two Hearts 💕\n\n'
      'Sign up at the app, then tap this link to connect:\n$link\n\n'
      'Or open Two Hearts → Pair → Enter Code: $code',
    );
    final waUri = Uri.parse('whatsapp://send?text=$text');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri);
    } else {
      await launchUrl(Uri.parse('https://wa.me/?text=$text'),
          mode: LaunchMode.externalApplication);
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
                colors: [Color(0xFF2A0820), Color(0xFF0D0408), Color(0xFF120610)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Decorative glow
          Positioned(
            top: -40,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.rose.withValues(alpha: 0.07),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const AnimatedLogo(size: 48).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),
                  const SizedBox(height: 20),
                  Text('Connect\nyour worlds.',
                      style: Theme.of(context).textTheme.displayLarge)
                      .animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 8),
                  Text(
                    'Both partners sign up, then connect with a code.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 32),

                  // ── Step indicators ───────────────────────────────────
                  _StepBanner().animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 28),

                  // ── Your invite code ──────────────────────────────────
                  Text(
                    'YOUR INVITE CODE',
                    style: TextStyle(
                      color: AppColors.rose.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 10),
                  _MyCodeSection(
                    loading: _codeLoading,
                    code: _generatedCode,
                    onShare: _generatedCode != null
                        ? () => _shareWhatsApp(_generatedCode!)
                        : null,
                    onCopy: _generatedCode != null
                        ? () {
                            Clipboard.setData(
                                ClipboardData(text: _generatedCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Code copied!'),
                                backgroundColor: AppColors.bgCard,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        : null,
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.08),

                  const SizedBox(height: 28),

                  // ── Divider ───────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR YOUR PARTNER SHARED THEIRS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.1))),
                    ],
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 20),

                  // ── Enter partner's code ──────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _showJoin = !_showJoin),
                    child: Row(
                      children: [
                        Text(
                          'Enter your partner\'s code',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _showJoin
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 380.ms),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: _showJoin
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _JoinSection(
                              controller: _joinCtrl,
                              loading: _joinLoading,
                              error: _joinError,
                              onRedeem: _redeemCode,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step banner ───────────────────────────────────────────────────────────────

class _StepBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.rose.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _Step(num: '1', text: 'You sign up — you\'re here now ✓'),
          const SizedBox(height: 8),
          _Step(num: '2', text: 'Your partner signs up too'),
          const SizedBox(height: 8),
          _Step(num: '3', text: 'Share the code below so they can connect'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String num;
  final String text;
  const _Step({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.rose.withValues(alpha: 0.2),
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: AppColors.rose,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ── My code section ───────────────────────────────────────────────────────────

class _MyCodeSection extends StatelessWidget {
  final bool loading;
  final String? code;
  final VoidCallback? onShare;
  final VoidCallback? onCopy;

  const _MyCodeSection({
    required this.loading,
    required this.code,
    this.onShare,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (loading)
            const SizedBox(
              height: 60,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.rose),
              ),
            )
          else if (code != null)
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [AppColors.rose, AppColors.coral],
              ).createShader(b),
              child: Text(
                code!,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  color: Colors.white,
                ),
              ),
            )
          else
            const Text(
              'Could not generate code.\nCheck your connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          const SizedBox(height: 8),
          if (code != null)
            const Text(
              'Share this with your partner',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          const SizedBox(height: 20),
          if (code != null) ...[
            GestureDetector(
              onTap: onShare,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF25D366).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 17),
                    SizedBox(width: 8),
                    Text('Share via WhatsApp',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GradientButton(label: 'Copy Code', onTap: onCopy ?? () {}),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.rose)),
                SizedBox(width: 10),
                Text('Waiting for your partner…',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Join section ──────────────────────────────────────────────────────────────

class _JoinSection extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onRedeem;

  const _JoinSection({
    required this.controller,
    required this.loading,
    this.error,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Partner's code",
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              letterSpacing: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
                counterText: '', hintText: '······'),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!,
                style:
                    const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 18),
          GradientButton(
              label: 'Connect ♡', onTap: onRedeem, loading: loading),
        ],
      ),
    );
  }
}
