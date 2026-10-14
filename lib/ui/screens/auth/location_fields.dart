import 'dart:async';
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../services/account/account_service.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

/// País, estado/província (quando o país tem) e cidade, cada um escolhido numa lista com busca.
/// Avisa [onChanged] com o local completo, ou `null` enquanto falta alguma escolha.
class LocationFields extends StatefulWidget {
  final AccountService account;
  final ValueChanged<LocationChoice?> onChanged;

  /// Local atual (edição do perfil).
  final WaxClubAccount? initial;

  const LocationFields({super.key, required this.account, required this.onChanged, this.initial});

  @override
  State<LocationFields> createState() => _LocationFieldsState();
}

class _LocationFieldsState extends State<LocationFields> {
  GeoCountry? _country;
  GeoState? _state;
  GeoCity? _city;
  List<GeoState> _states = const [];

  @override
  void initState() {
    super.initState();
    _restoreInitial();
  }

  /// Edição do perfil: reconstrói as escolhas a partir dos códigos guardados na conta.
  Future<void> _restoreInitial() async {
    final a = widget.initial;
    if (a == null || a.countryCode == null || a.cityId == null) return;
    try {
      final countries = await widget.account.countries();
      final country = countries.where((c) => c.code == a.countryCode).firstOrNull;
      if (country == null || !mounted) return;
      final states = country.hasStates ? await widget.account.states(country.code) : const <GeoState>[];
      if (!mounted) return;
      setState(() {
        _country = country;
        _states = states;
        _state = states.where((s) => s.code == a.stateCode).firstOrNull;
        _city = GeoCity(a.cityId!, a.city ?? '', a.stateCode ?? '');
      });
      _notify();
    } catch (_) {}
  }

  void _notify() {
    final ok = _country != null && _city != null && (!_country!.hasStates || _state != null);
    widget.onChanged(ok ? LocationChoice(country: _country!, state: _state, city: _city!) : null);
  }

  Future<void> _pickCountry() async {
    final picked = await showSearchPicker<GeoCountry>(
      context: context,
      title: l10n.signUpCountry,
      load: (q) async {
        final all = await widget.account.countries();
        final t = q.trim().toLowerCase();
        return t.isEmpty ? all : all.where((c) => c.name.toLowerCase().contains(t)).toList();
      },
      label: (c) => c.name,
    );
    if (picked == null || picked.code == _country?.code) return;
    setState(() {
      _country = picked;
      _state = null;
      _city = null;
      _states = const [];
    });
    _notify();
    if (picked.hasStates) {
      try {
        final states = await widget.account.states(picked.code);
        if (mounted && _country?.code == picked.code) setState(() => _states = states);
      } catch (_) {}
    }
  }

  Future<void> _pickState() async {
    if (_country == null) return;
    final states = _states.isNotEmpty ? _states : await widget.account.states(_country!.code);
    if (!mounted) return;
    final picked = await showSearchPicker<GeoState>(
      context: context,
      title: l10n.signUpState,
      load: (q) async {
        final t = q.trim().toLowerCase();
        return t.isEmpty ? states : states.where((s) => s.name.toLowerCase().contains(t)).toList();
      },
      label: (s) => s.name,
    );
    if (picked == null || picked.code == _state?.code) return;
    setState(() {
      _states = states;
      _state = picked;
      _city = null;
    });
    _notify();
  }

  Future<void> _pickCity() async {
    final country = _country;
    if (country == null || (country.hasStates && _state == null)) return;
    final picked = await showSearchPicker<GeoCity>(
      context: context,
      title: l10n.signUpCity,
      hint: l10n.signUpCityHint,
      remote: true,
      load: (q) => widget.account.cities(country.code, stateCode: _state?.code, query: q),
      label: (c) => c.name,
    );
    if (picked == null) return;
    setState(() => _city = picked);
    _notify();
  }

  Widget _selector({required String label, String? value, String? disabledHint, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: InputDecorator(
          isEmpty: value == null,
          decoration: authField(label, suffix: const Icon(Icons.arrow_drop_down, color: Colors.white60)).copyWith(
            enabled: enabled,
            hintText: enabled ? null : disabledHint,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
          child: value == null ? null : Text(value, style: authFieldText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsState = _country?.hasStates ?? false;
    final cityReady = _country != null && (!needsState || _state != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _selector(label: l10n.signUpCountry, value: _country?.name, onTap: _pickCountry),
        if (needsState)
          _selector(
            label: l10n.signUpState,
            value: _state?.name,
            onTap: _pickState,
          ),
        _selector(
          label: l10n.signUpCity,
          value: _city?.name,
          disabledHint: _country == null ? l10n.signUpPickCountryFirst : l10n.signUpPickStateFirst,
          onTap: cityReady ? _pickCity : null,
        ),
        Text(l10n.signUpLocationWhy, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

/// Lista com busca numa folha que sobe da base da tela. [remote]: a busca vai ao servidor (com atraso curto).
Future<T?> showSearchPicker<T>({
  required BuildContext context,
  required String title,
  required Future<List<T>> Function(String query) load,
  required String Function(T) label,
  String? hint,
  bool remote = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _SearchPickerSheet<T>(title: title, load: load, label: label, hint: hint, remote: remote),
  );
}

class _SearchPickerSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function(String query) load;
  final String Function(T) label;
  final String? hint;
  final bool remote;
  const _SearchPickerSheet({required this.title, required this.load, required this.label, this.hint, required this.remote});

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  final TextEditingController _query = TextEditingController();
  List<T> _items = const [];
  bool _loading = true;
  bool _failed = false;
  Timer? _debounce;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(widget.remote ? const Duration(milliseconds: 300) : Duration.zero, () => _run(q));
  }

  Future<void> _run(String q) async {
    final id = ++_requestId;
    setState(() => _loading = true);
    try {
      final items = await widget.load(q);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(widget.title,
                  style: const TextStyle(color: AppTheme.cream, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                autofocus: true,
                style: authFieldText,
                onChanged: _onQuery,
                decoration: authField(widget.hint ?? l10n.signUpSearch,
                    suffix: const Icon(Icons.search, color: Colors.white60)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.orange))
                  : _failed
                      ? Center(child: Text(l10n.accountErrorNetwork, style: const TextStyle(color: Colors.white70)))
                      : _items.isEmpty
                          ? Center(child: Text(l10n.signUpNoResults, style: const TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (_, i) => ListTile(
                                title: Text(widget.label(_items[i]), style: const TextStyle(color: AppTheme.cream)),
                                onTap: () => Navigator.of(context).pop(_items[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
