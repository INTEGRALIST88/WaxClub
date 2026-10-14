import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/account/account_service.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import 'auth/auth_widgets.dart';
import 'auth/profile_form_screen.dart';
import 'collection_screen.dart';

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
            title: Text(l10n.accountTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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

  List<Widget> _profile(WaxClubAccount a) {
    final last = _account.lastSyncAt;
    final syncLine = _account.isSyncing
        ? l10n.accountSyncing
        : last == null
            ? l10n.accountNeverSynced
            : l10n.accountLastSync(CollectionScreenFormat.when(last));
    return [
      const Icon(Icons.account_circle_outlined, size: 64, color: AppTheme.cream),
      const SizedBox(height: 8),
      if (a.username != null)
        Text('@${a.username}', // l10n-ignore
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.cream, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(a.email, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
      if (a.locationLabel.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.place_outlined, size: 16, color: Colors.white54),
            const SizedBox(width: 4),
            Flexible(child: Text(a.locationLabel, style: const TextStyle(color: Colors.white54))),
          ],
        ),
      ],
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
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_account.isSyncing ? Icons.sync : Icons.cloud_done_outlined, color: AppTheme.cream, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(syncLine, style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w600))),
              ],
            ),
            if (_account.lastSyncError != null && !_account.isSyncing) ...[
              const SizedBox(height: 8),
              Text(l10n.accountSyncFailed, style: const TextStyle(color: AppTheme.orange)),
            ],
            const SizedBox(height: 8),
            Text(l10n.accountSyncInfo, style: const TextStyle(color: Colors.white60, height: 1.4, fontSize: 13)),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AuthPrimaryButton(label: l10n.accountSyncNow, onPressed: _account.isSyncing ? null : () => _account.sync()),
      const SizedBox(height: 8),
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
      const SizedBox(height: 24),
      TextButton(
        onPressed: _busy ? null : _confirmDelete,
        style: TextButton.styleFrom(foregroundColor: Colors.white54),
        child: Text(l10n.accountDelete),
      ),
    ];
  }
}
