import 'package:flutter/material.dart';
import '../widgets/retro_text.dart';
import '../../l10n/l10n.dart';
import '../../services/account/account_service.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import 'auth/auth_widgets.dart';
import 'auth/profile_form_screen.dart';

/// Conta WaxClub: perfil, sincronização da coleção, editar perfil, sair ou apagar a conta.
class AccountScreen extends StatefulWidget {
  final AccountService account;
  const AccountScreen({super.key, required this.account});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;
  String? _error;

  AccountService get _account => widget.account;

  /// Ao sair ou apagar a conta, volta para a raiz: o app mostra a tela de login.
  Future<void> _leave(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final nav = Navigator.of(context);
      await action();
      nav.popUntil((r) => r.isFirst);
      return;
    } catch (e) {
      _error = authErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text(l10n.accountDeleteConfirmTitle, style: const TextStyle(color: AppTheme.cream)),
        content: Text(l10n.accountDeleteConfirmBody, style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.orange),
            child: Text(l10n.accountDeleteConfirm),
          ),
        ],
      ),
    );
    if (ok == true) await _leave(_account.deleteAccount);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _account,
      builder: (context, _) {
        final a = _account.account;
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.cream,
            title: RetroText(l10n.profileTitle, fontSize: 28, depth: 3),
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: WoodBackground()),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (a != null) ..._profile(a),
                        AuthErrorText(_error),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppTheme.wood),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13.5)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(color: AppTheme.cream, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  /// Dados do cadastro; embaixo, sair e apagar a conta (com confirmação).
  List<Widget> _profile(WaxClubAccount a) {
    final signIn = a.google && a.hasPassword
        ? l10n.profileSignInBoth
        : a.google
            ? l10n.profileSignInGoogle
            : l10n.profileSignInEmail;
    return [
      Center(
        child: Image.asset('assets/images/btn_user.png', width: 84, height: 84),
      ),
      const SizedBox(height: 8),
      if (a.username != null)
        Center(child: RetroText('@${a.username}', fontSize: 30, depth: 3)), // l10n-ignore
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            if (a.username != null) _infoRow(Icons.alternate_email, l10n.profileUsername, a.username!),
            _infoRow(Icons.mail_outline, l10n.accountEmailLabel, a.email),
            if (a.locationLabel.isNotEmpty) _infoRow(Icons.place_outlined, l10n.profileLocation, a.locationLabel),
            _infoRow(Icons.login, l10n.profileSignIn, signIn),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton.icon(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileFormScreen(account: _account, editing: true),
                  )),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: Text(l10n.accountEditProfile),
        ),
      ),
      const SizedBox(height: 28),
      OutlinedButton(
        onPressed: _busy ? null : () => _leave(_account.signOut),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.cream,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppTheme.wood),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(l10n.accountSignOut),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _busy ? null : _confirmDelete,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.orange,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppTheme.rust),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(l10n.accountDelete),
      ),
    ];
  }
}
