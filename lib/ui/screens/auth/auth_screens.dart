import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app_info.dart';
import '../../../l10n/l10n.dart';
import '../../../services/account/account_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/retro_text.dart';
import 'auth_widgets.dart';
import 'location_fields.dart';

/// Volta para a raiz depois de entrar: o [AuthGate] troca para o app.
void _backToGate(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

/// Primeira tela do app sem conta: entrar com e-mail e senha (ou Google), criar conta, esqueci a senha.
class SignInScreen extends StatefulWidget {
  final AccountService account;

  /// Login com Google no aparelho; devolve o idToken (null = cancelado). Sem ele, o botão não aparece.
  final Future<String?> Function()? googleSignIn;

  const SignInScreen({super.key, required this.account, this.googleSignIn});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = l10n.authErrorRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.account.login(_email.text, _password.text);
    } on AccountApiException catch (e) {
      if (e.code == 'email_not_verified' && mounted) { // l10n-ignore
        setState(() => _busy = false);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(account: widget.account, email: _email.text.trim()),
        ));
        return;
      }
      _error = authErrorMessage(e);
    } catch (e) {
      _error = authErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _google() async {
    if (_busy || widget.googleSignIn == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await widget.googleSignIn!();
      if (token != null) await widget.account.loginWithGoogle(token);
    } catch (e) {
      _error = authErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showLogo: true,
      children: [
        Center(child: RetroText(l10n.authWelcome, fontSize: 30, maxLines: 2, textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        Text(l10n.authSubtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
        const SizedBox(height: 24),
        if (widget.googleSignIn != null) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : _google,
            icon: const Icon(Icons.account_circle_outlined),
            label: Text(l10n.authContinueWithGoogle, style: const TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cream,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppTheme.cream),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              const Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l10n.authOr, style: const TextStyle(color: Colors.white54)),
              ),
              const Expanded(child: Divider(color: Colors.white24)),
            ]),
          ),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          style: authFieldText,
          decoration: authField(l10n.accountEmailLabel),
        ),
        const SizedBox(height: 12),
        PasswordField(controller: _password, label: l10n.authPassword, onSubmitted: (_) => _signIn()),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(account: widget.account, initialEmail: _email.text.trim()),
                    )),
            child: Text(l10n.authForgotPassword),
          ),
        ),
        AuthPrimaryButton(label: l10n.accountSignIn, onPressed: _signIn, busy: _busy),
        AuthErrorText(_error),
        const SizedBox(height: 28),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.authNoAccount, style: const TextStyle(color: Colors.white70)),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SignUpScreen(account: widget.account),
                      )),
              child: Text(l10n.authCreateAccount, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('$kAppName $kAppVersion', // l10n-ignore
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white30, fontSize: 11)),
      ],
    );
  }
}

/// Campo do nome de usuário com a conferência de disponibilidade enquanto digita.
class UsernameField extends StatefulWidget {
  final AccountService account;
  final TextEditingController controller;

  /// Nome atual do próprio usuário (edição): não aparece como "ocupado".
  final String? current;

  const UsernameField({super.key, required this.account, required this.controller, this.current});

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  Timer? _debounce;
  bool? _available; // null = ainda não conferido ou inválido
  bool _invalid = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _available = null;
      _invalid = false;
    });
    final v = value.trim().toLowerCase();
    if (v.isEmpty || v == widget.current) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final ok = await widget.account.usernameAvailable(v);
        if (!mounted || widget.controller.text.trim().toLowerCase() != v) return;
        setState(() {
          _invalid = ok == null;
          _available = ok;
        });
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    String? helper = l10n.signUpUsernameHint;
    Widget? suffix;
    if (_invalid) {
      helper = l10n.authErrorUsername;
      suffix = const Icon(Icons.error_outline, color: AppTheme.orange);
    } else if (_available == false) {
      helper = l10n.signUpUsernameTaken;
      suffix = const Icon(Icons.close, color: AppTheme.orange);
    } else if (_available == true) {
      helper = l10n.signUpUsernameAvailable;
      suffix = const Icon(Icons.check, color: Colors.lightGreenAccent);
    }
    return TextField(
      controller: widget.controller,
      autocorrect: false,
      enableSuggestions: false,
      style: authFieldText,
      onChanged: _onChanged,
      decoration: authField(l10n.signUpUsername, helper: helper, suffix: suffix).copyWith(prefixText: '@'),
    );
  }
}

/// Cadastro: nome de usuário, e-mail, senha e local; depois confirma o e-mail com o código.
class SignUpScreen extends StatefulWidget {
  final AccountService account;
  const SignUpScreen({super.key, required this.account});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  LocationChoice? _location;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_username.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = l10n.authErrorRequired);
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = l10n.authErrorWeakPassword);
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
      await widget.account.register(
        email: _email.text,
        password: _password.text,
        username: _username.text,
        location: _location!,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VerifyEmailScreen(account: widget.account, email: _email.text.trim()),
      ));
      return;
    } catch (e) {
      _error = authErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: l10n.signUpTitle,
      children: [
        UsernameField(account: widget.account, controller: _username),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          style: authFieldText,
          decoration: authField(l10n.accountEmailLabel),
        ),
        const SizedBox(height: 12),
        PasswordField(controller: _password, label: l10n.authPassword, helper: l10n.signUpPasswordHint),
        const SizedBox(height: 16),
        LocationFields(account: widget.account, onChanged: (l) => _location = l),
        const SizedBox(height: 20),
        AuthPrimaryButton(label: l10n.authCreateAccount, onPressed: _submit, busy: _busy),
        AuthErrorText(_error),
      ],
    );
  }
}

/// Código de 6 dígitos enviado ao e-mail no cadastro (ou no login de conta ainda não confirmada).
class VerifyEmailScreen extends StatefulWidget {
  final AccountService account;
  final String email;
  const VerifyEmailScreen({super.key, required this.account, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.account.verifyEmail(widget.email, _code.text);
      if (mounted) _backToGate(context);
      return;
    } catch (e) {
      _error = authErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.account.resendVerification(widget.email);
      _info = l10n.verifyResent;
      _code.clear();
    } catch (e) {
      _error = authErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: l10n.verifyTitle,
      children: [
        const Icon(Icons.mark_email_unread_outlined, size: 64, color: AppTheme.cream),
        const SizedBox(height: 12),
        Text(l10n.verifyBody(widget.email),
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.45)),
        const SizedBox(height: 20),
        _CodeField(controller: _code, onSubmitted: (_) => _confirm()),
        const SizedBox(height: 16),
        AuthPrimaryButton(label: l10n.verifyConfirm, onPressed: _confirm, busy: _busy),
        TextButton(onPressed: _busy ? null : _resend, child: Text(l10n.accountResend)),
        if (_info != null) Text(_info!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.cream)),
        AuthErrorText(_error),
      ],
    );
  }
}

class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  const _CodeField({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.cream, fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w800),
        decoration: authField(l10n.accountCodeLabel).copyWith(counterText: ''),
        onSubmitted: onSubmitted,
      );
}

/// "Esqueci a senha": e-mail → código + senha nova → entra na conta.
class ForgotPasswordScreen extends StatefulWidget {
  final AccountService account;
  final String initialEmail;
  const ForgotPasswordScreen({super.key, required this.account, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _sentTo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      _error = authErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _send() => _run(() async {
        await widget.account.forgotPassword(_email.text);
        _sentTo = _email.text.trim();
      });

  Future<void> _save() => _run(() async {
        if (_password.text.length < 8) throw const AccountApiException('weak_password', 422); // l10n-ignore
        await widget.account.resetPassword(_sentTo!, _code.text, _password.text);
        if (mounted) _backToGate(context);
      });

  @override
  Widget build(BuildContext context) {
    final sent = _sentTo;
    return AuthScaffold(
      title: l10n.forgotTitle,
      children: [
        if (sent == null) ...[
          Text(l10n.forgotBody, style: const TextStyle(color: Colors.white70, height: 1.45)),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: authFieldText,
            decoration: authField(l10n.accountEmailLabel),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(label: l10n.accountSendCode, onPressed: _send, busy: _busy),
        ] else ...[
          Text(l10n.forgotCodeSent(sent), style: const TextStyle(color: AppTheme.cream, height: 1.45)),
          const SizedBox(height: 16),
          _CodeField(controller: _code),
          const SizedBox(height: 12),
          PasswordField(controller: _password, label: l10n.forgotNewPassword, helper: l10n.signUpPasswordHint),
          const SizedBox(height: 16),
          AuthPrimaryButton(label: l10n.forgotSave, onPressed: _save, busy: _busy),
          TextButton(onPressed: _busy ? null : _send, child: Text(l10n.accountResend)),
        ],
        AuthErrorText(_error),
      ],
    );
  }
}
