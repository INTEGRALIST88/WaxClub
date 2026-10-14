import 'package:flutter/material.dart';
import '../../widgets/retro_text.dart';
import '../../../l10n/l10n.dart';
import '../../../services/account/account_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/wood.dart';

/// Mensagem para o usuário a partir do erro da API.
String authErrorMessage(Object error) {
  if (error is! AccountApiException) return l10n.accountErrorGeneric;
  switch (error.code) {
    case 'invalid_email': // l10n-ignore
      return l10n.accountErrorEmail;
    case 'invalid_credentials': // l10n-ignore
      return l10n.authErrorCredentials;
    case 'no_password': // l10n-ignore
      return l10n.authErrorNoPassword;
    case 'email_taken': // l10n-ignore
      return l10n.authErrorEmailTaken;
    case 'weak_password': // l10n-ignore
      return l10n.authErrorWeakPassword;
    case 'invalid_username': // l10n-ignore
      return l10n.authErrorUsername;
    case 'username_taken': // l10n-ignore
      return l10n.signUpUsernameTaken;
    case 'invalid_country': // l10n-ignore
    case 'invalid_state': // l10n-ignore
    case 'invalid_city': // l10n-ignore
      return l10n.authErrorLocation;
    case 'invalid_code': // l10n-ignore
      return l10n.accountErrorCode;
    case 'code_expired': // l10n-ignore
      return l10n.accountErrorExpired;
    case 'too_many_requests': // l10n-ignore
      return l10n.accountErrorTooMany;
    case 'too_many_attempts': // l10n-ignore
      return l10n.authErrorTooManyAttempts;
    case 'network': // l10n-ignore
      return l10n.accountErrorNetwork;
    default:
      return l10n.accountErrorGeneric;
  }
}

/// Fundo de madeira com o conteúdo centralizado e rolável (telas de login e cadastro).
class AuthScaffold extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final bool showLogo;

  const AuthScaffold({super.key, this.title, required this.children, this.showLogo = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: title == null
          ? null
          : AppBar(
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.cream,
              title: RetroText(title!, fontSize: 28, depth: 3),
            ),
      body: Stack(
        children: [
          const Positioned.fill(child: WoodBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
                  children: [
                    if (showLogo) ...[
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset('assets/icon/app_icon.png', width: 120, height: 120),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration authField(String label, {String? helper, Widget? suffix}) => InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      helperStyle: const TextStyle(color: Colors.white54),
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: AppTheme.surface,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.orange, width: 2),
      ),
    );

const TextStyle authFieldText = TextStyle(color: AppTheme.cream);

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  const AuthPrimaryButton({super.key, required this.label, this.onPressed, this.busy = false});

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      );
}

class AuthErrorText extends StatelessWidget {
  final String? message;
  const AuthErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(message!, style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w600)),
        );
}

/// Campo de senha com o botão de mostrar/ocultar.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final ValueChanged<String>? onSubmitted;
  const PasswordField({super.key, required this.controller, required this.label, this.helper, this.onSubmitted});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        style: authFieldText,
        onSubmitted: widget.onSubmitted,
        decoration: authField(
          widget.label,
          helper: widget.helper,
          suffix: IconButton(
            tooltip: l10n.authShowPassword,
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white60),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}
