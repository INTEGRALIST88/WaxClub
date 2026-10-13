import 'package:flutter/widgets.dart';
import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// Acesso aos textos traduzidos da interface (arquivos `lib/l10n/app_*.arb`).
/// Inglês é o idioma padrão; os plugins de idioma acrescentarão outros arquivos `.arb`.
class L10n {
  L10n._();

  static AppLocalizations _current = lookupAppLocalizations(const Locale('en'));

  /// Textos do idioma atual para quem está fora da árvore de widgets (motor, serviços).
  static AppLocalizations get current => _current;

  /// Chamado pelo app quando o idioma muda; idioma sem tradução fica em inglês.
  static void update(Locale locale) {
    final supported = AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);
    _current = lookupAppLocalizations(supported ? locale : const Locale('en'));
  }
}

/// Atalho para os textos do idioma atual (telas, motor e serviços).
AppLocalizations get l10n => L10n.current;

extension L10nContext on BuildContext {
  /// Textos traduzidos no contexto atual (inglês quando o app não registrou as traduções, ex.: testes).
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations) ?? L10n.current;
}
