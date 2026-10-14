import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/account/account_service.dart';
import '../../services/plugins/plugin_catalog.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import '../widgets/retro_text.dart';
import 'auth/auth_widgets.dart';
import 'collection_screen.dart';

/// Botão da nuvem em My Collection: sincronização da coleção com a conta WaxClub e a conexão com o
/// Discogs (plugin C1). Sair e apagar a conta ficam no Perfil (botão de usuário da tela principal).
class SyncScreen extends StatelessWidget {
  final AccountService account;

  /// Plugin C1 (Discogs); sem ele, o cartão do Discogs não aparece.
  final PluginConnection? discogs;

  const SyncScreen({super.key, required this.account, this.discogs});

  Widget _card({required Widget icon, required String title, required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [icon, const SizedBox(width: 10), Expanded(child: RetroText(title, fontSize: 22, depth: 2))]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[account, if (discogs != null) discogs!.listenable];
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final last = account.lastSyncAt;
        final syncLine = account.isSyncing
            ? l10n.accountSyncing
            : last == null
                ? l10n.accountNeverSynced
                : l10n.accountLastSync(CollectionScreenFormat.when(last));
        final d = discogs;
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.cream,
            title: RetroText(l10n.syncTitle, fontSize: 28, depth: 3),
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
                        _card(
                          icon: Image.asset('assets/images/btn_cloud.png', width: 40, height: 40),
                          title: l10n.syncAccountTitle,
                          children: [
                            Row(
                              children: [
                                Icon(account.isSyncing ? Icons.sync : Icons.check_circle_outline,
                                    color: AppTheme.cream, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(syncLine,
                                      style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            if (account.lastSyncError != null && !account.isSyncing) ...[
                              const SizedBox(height: 8),
                              Text(l10n.accountSyncFailed, style: const TextStyle(color: AppTheme.orange)),
                            ],
                            const SizedBox(height: 8),
                            Text(l10n.accountSyncInfo,
                                style: const TextStyle(color: Colors.white60, height: 1.4, fontSize: 13)),
                            const SizedBox(height: 14),
                            AuthPrimaryButton(
                              label: l10n.accountSyncNow,
                              onPressed: account.isSyncing ? null : () => account.sync(),
                            ),
                          ],
                        ),
                        if (d != null) ...[
                          const SizedBox(height: 16),
                          _card(
                            icon: Icon(d.isConnected() ? Icons.link : Icons.link_off,
                                color: PluginCategory.connections.color, size: 30),
                            title: l10n.syncDiscogsTitle,
                            children: [
                              if (!d.isEnabled())
                                Text(l10n.syncDiscogsPluginOff,
                                    style: const TextStyle(color: Colors.white70, height: 1.4))
                              else if (d.isConnected())
                                Text(l10n.connectedAs(d.accountName() ?? l10n.yourAccount),
                                    style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w600))
                              else ...[
                                Text(l10n.syncDiscogsNotConnected,
                                    style: const TextStyle(color: Colors.white70, height: 1.4)),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => d.connect(),
                                  icon: const Icon(Icons.login),
                                  label: Text(l10n.syncDiscogsConnect),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: PluginCategory.connections.color,
                                    minimumSize: const Size.fromHeight(46),
                                    side: BorderSide(color: PluginCategory.connections.color),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
}
