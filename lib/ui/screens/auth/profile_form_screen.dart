import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../services/account/account_service.dart';
import '../../theme/app_theme.dart';
import 'auth_screens.dart';
import 'auth_widgets.dart';
import 'location_fields.dart';

/// Nome de usuário e local: completar o cadastro (quem entrou pelo Google ou pelo código antigo)
/// ou editar o perfil a partir da tela da conta ([editing]).
class ProfileFormScreen extends StatefulWidget {
  final AccountService account;
  final bool editing;
  const ProfileFormScreen({super.key, required this.account, this.editing = false});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  late final TextEditingController _username = TextEditingController(text: widget.account.account?.username ?? '');
  LocationChoice? _location;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_username.text.trim().isEmpty) {
      setState(() => _error = l10n.authErrorUsername);
      return;
    }
    if (_location == null) {
      setState(() => _error = l10n.authErrorLocation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.account.updateProfile(username: _username.text, location: _location!);
      if (mounted && widget.editing) Navigator.of(context).pop();
      return;
    } catch (e) {
      _error = authErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account.account;
    return AuthScaffold(
      title: widget.editing ? l10n.accountEditProfile : l10n.profileCompleteTitle,
      children: [
        if (!widget.editing) ...[
          Text(l10n.profileCompleteBody, style: const TextStyle(color: Colors.white70, height: 1.45)),
          if (a != null) ...[
            const SizedBox(height: 6),
            Text(a.email, style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 20),
        ],
        UsernameField(account: widget.account, controller: _username, current: a?.username),
        const SizedBox(height: 16),
        LocationFields(account: widget.account, initial: a, onChanged: (l) => _location = l),
        const SizedBox(height: 20),
        AuthPrimaryButton(label: l10n.profileSave, onPressed: _save, busy: _busy),
        AuthErrorText(_error),
        if (!widget.editing) ...[
          const SizedBox(height: 24),
          TextButton(
            onPressed: _busy ? null : widget.account.signOut,
            child: Text(l10n.accountSignOut, style: const TextStyle(color: Colors.white54)),
          ),
        ],
      ],
    );
  }
}
