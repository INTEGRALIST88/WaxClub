import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/account/account_service.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import 'collection_screen.dart';

/// Conta WaxClub: entrar com o código enviado ao e-mail, ver a sincronização, sair ou apagar a conta.
class AccountScreen extends StatefulWidget {
  final AccountService account;
  const AccountScreen({super.key, required this.account});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String? _codeSentTo;
  bool _busy = false;
  String? _error;

  AccountService get _account => widget.account;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  static String messageFor(AccountApiException e) {
    switch (e.code) {
      case 'invalid_email': // l10n-ignore
        return l10n.accountErrorEmail;
      case 'invalid_code': // l10n-ignore
        return l10n.accountErrorCode;
      case 'code_expired': // l10n-ignore
        return l10n.accountErrorExpired;
      case 'too_many_requests': // l10n-ignore
        return l10n.accountErrorTooMany;
      case 'network': // l10n-ignore
        return l10n.accountErrorNetwork;
      default:
        return l10n.accountErrorGeneric;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AccountApiException catch (e) {
      _error = messageFor(e);
    } catch (_) {
      _error = l10n.accountErrorGeneric;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendCode() => _run(() async {
        final email = _email.text.trim();
        await _account.requestCode(email);
        _code.clear();
        _codeSentTo = email;
      });

  Future<void> _signIn() => _run(() async {
        await _account.verifyCode(_codeSentTo!, _code.text);
        _codeSentTo = null;
        _code.clear();
      });

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
    if (ok == true) await _run(_account.deleteAccount);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _account,
      builder: (context, _) => Scaffold(
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
                      if (_account.isSignedIn) ..._signedIn() else ..._signedOut(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _field(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.orange, width: 2),
        ),
      );

  Widget _primary(String label, VoidCallback? onPressed) => FilledButton(
        onPressed: _busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );

  List<Widget> _signedOut() {
    final sent = _codeSentTo;
    return [
      const Icon(Icons.cloud_sync_outlined, size: 64, color: AppTheme.cream),
      const SizedBox(height: 12),
      Text(l10n.accountIntro, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.45)),
      const SizedBox(height: 24),
      if (sent == null) ...[
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          style: const TextStyle(color: AppTheme.cream),
          decoration: _field(l10n.accountEmailLabel),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 16),
        _primary(l10n.accountSendCode, _sendCode),
      ] else ...[
        Text(l10n.accountCodeSent(sent), style: const TextStyle(color: AppTheme.cream, height: 1.45)),
        const SizedBox(height: 16),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.cream, fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w800),
          decoration: _field(l10n.accountCodeLabel).copyWith(counterText: ''),
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: 16),
        _primary(l10n.accountSignIn, _signIn),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: _busy ? null : _sendCode, child: Text(l10n.accountResend)),
            TextButton(
              onPressed: _busy ? null : () => setState(() => _codeSentTo = null),
              child: Text(l10n.accountChangeEmail),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _signedIn() {
    final a = _account.account!;
    final last = _account.lastSyncAt;
    final syncLine = _account.isSyncing
        ? l10n.accountSyncing
        : last == null
            ? l10n.accountNeverSynced
            : l10n.accountLastSync(CollectionScreenFormat.when(last));
    return [
      const Icon(Icons.cloud_done_outlined, size: 64, color: AppTheme.cream),
      const SizedBox(height: 12),
      Text(l10n.accountSignedInAs, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 4),
      Text(a.email,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.cream, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_account.isSyncing ? Icons.sync : Icons.check_circle_outline, color: AppTheme.cream, size: 20),
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
      _primary(l10n.accountSyncNow, _account.isSyncing ? null : () => _account.sync()),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: _busy ? null : () => _run(_account.signOut),
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
