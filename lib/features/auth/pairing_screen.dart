import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firestore_service.dart';
import '../../core/firebase/models.dart';
import '../../core/theme/app_theme.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _loading = false;
  String? _generatedCode;
  final _codeController = TextEditingController();
  String? _error;
  bool _showJoin = false;

  Future<void> _createCode() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = FirestoreService();
      // create user doc first if needed
      final user = FirebaseAuth.instance.currentUser!;
      await svc.createUser(UserModel(
        uid: user.uid,
        displayName: user.displayName ?? user.email!.split('@').first,
        email: user.email!,
      ));
      final code = await svc.createInviteCode();
      setState(() { _generatedCode = code; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _redeemCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() { _error = 'Enter the 6-character code'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final svc = FirestoreService();
      await svc.createUser(UserModel(
        uid: user.uid,
        displayName: user.displayName ?? user.email!.split('@').first,
        email: user.email!,
      ));
      final couple = await svc.redeemInviteCode(code);
      if (couple == null) {
        setState(() { _error = 'Code not found or already used.'; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.defaultAccent;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connect\nwith your\nperson.', style: Theme.of(context).textTheme.displayLarge)
                  .animate().fadeIn().slideX(begin: -0.1),
              const SizedBox(height: 8),
              Text('Two hearts. One private space.',
                  style: Theme.of(context).textTheme.bodyMedium)
                  .animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 40),
              if (_generatedCode == null && !_showJoin) ...[
                _BigButton(
                  icon: Icons.add_link,
                  label: 'Create Invite Code',
                  subtitle: 'Share the code with your partner',
                  accent: accent,
                  onTap: _loading ? null : _createCode,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 16),
                _BigButton(
                  icon: Icons.vpn_key_outlined,
                  label: 'Enter a Code',
                  subtitle: 'Your partner already created one',
                  accent: accent,
                  onTap: () => setState(() => _showJoin = true),
                ).animate().fadeIn(delay: 400.ms),
              ],
              if (_generatedCode != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text('Your invite code', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Text(
                        _generatedCode!,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied!')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Code'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Waiting for your partner to join…',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ).animate().scale(begin: const Offset(0.9, 0.9)).fadeIn(),
              ],
              if (_showJoin && _generatedCode == null) ...[
                Text('Enter the code from your partner:', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Invite Code'),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _redeemCode,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Connect'),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              if (_loading && _generatedCode == null && !_showJoin) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.warmGray),
          ],
        ),
      ),
    );
  }
}
