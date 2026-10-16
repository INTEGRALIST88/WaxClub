import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'brain_chips.dart';

/// Um chip encaixado no WaxBrain (a chave fica só no cofre do celular e, criptografada, na conta).
class PluggedChip {
  final String id;
  final String key;
  final BrainKeyStatus status;
  final DateTime? checkedAt;

  const PluggedChip({required this.id, required this.key, this.status = BrainKeyStatus.ok, this.checkedAt});

  BrainChip? get chip => BrainChip.byId(id);
  String get hint => BrainChip.hintOf(key);

  PluggedChip copyWith({BrainKeyStatus? status, DateTime? checkedAt}) =>
      PluggedChip(id: id, key: key, status: status ?? this.status, checkedAt: checkedAt ?? this.checkedAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'status': status.name,
        if (checkedAt != null) 'checkedAt': checkedAt!.toIso8601String(),
      };

  factory PluggedChip.fromJson(Map<String, dynamic> j) => PluggedChip(
        id: j['id'] as String,
        key: j['key'] as String,
        status: BrainKeyStatus.parse(j['status'] as String?),
        checkedAt: DateTime.tryParse(j['checkedAt'] as String? ?? ''),
      );
}

/// Onde as chaves ficam no celular (cofre do Android); em testes, na memória.
abstract class BrainKeyStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class SecureBrainKeyStore implements BrainKeyStore {
  static const _key = 'waxbrain_chips';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (e) {
      debugPrint('[WaxBrain] Falha ao ler o cofre: $e');
      return null;
    }
  }

  @override
  Future<void> write(String? value) async {
    try {
      value == null ? await _storage.delete(key: _key) : await _storage.write(key: _key, value: value);
    } catch (e) {
      debugPrint('[WaxBrain] Falha ao gravar o cofre: $e');
    }
  }
}

class MemoryBrainKeyStore implements BrainKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
}

/// Cópia das chaves na conta WaxClub (servidor, criptografadas). Implementada pela conta; sem conta ou com
/// o servidor sem a senha de criptografia, o WaxBrain funciona só no celular.
abstract class BrainRemote {
  bool get available;

  /// Chips guardados na conta (id → final da chave), na ordem; nulo se a cópia na conta está desligada.
  Future<List<({String id, String hint})>?> list();
  Future<String?> key(String id);
  Future<void> put(String id, String key, int position, BrainKeyStatus status);
  Future<void> delete(String id);
  Future<void> order(List<String> ids);
}

/// WaxBrain: as chaves de IA do usuário (BYOK). Os plugins de IA usam o primeiro chip pronto, na ordem.
class BrainService extends ChangeNotifier {
  final BrainKeyStore _store;
  final http.Client _client;
  BrainRemote? _remote;

  BrainService({BrainKeyStore? store, http.Client? client})
      : _store = store ?? SecureBrainKeyStore(),
        _client = client ?? http.Client();

  final List<PluggedChip> _plugged = [];
  bool _loaded = false;
  Future<void>? _loading;

  /// Chips encaixados, na ordem de prioridade.
  List<PluggedChip> get plugged => List.unmodifiable(_plugged);
  bool get isLoaded => _loaded;
  bool get hasChip => _plugged.isNotEmpty;
  bool isPlugged(String id) => _plugged.any((p) => p.id == id);

  /// Primeiro chip que pode ser usado agora (pronto, ou ainda não testado por falta de internet).
  PluggedChip? get activeChip {
    for (final p in _plugged) {
      if (p.status == BrainKeyStatus.ok || p.status == BrainKeyStatus.offline) return p;
    }
    return null;
  }

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final raw = await _store.read();
    if (raw != null) {
      try {
        _plugged
          ..clear()
          ..addAll([
            for (final j in (jsonDecode(raw) as List<dynamic>).whereType<Map<String, dynamic>>())
              if (BrainChip.byId(j['id'] as String? ?? '') != null) PluggedChip.fromJson(j),
          ]);
      } catch (e) {
        debugPrint('[WaxBrain] Cofre ilegível, recomeçando: $e');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() => _store.write(jsonEncode([for (final p in _plugged) p.toJson()]));

  /// Liga a cópia na conta e junta os dois lados: chips só na conta descem para o celular; chips só no
  /// celular sobem para a conta.
  Future<void> attachRemote(BrainRemote remote) async {
    _remote = remote;
    await load();
    await syncWithRemote();
  }

  void detachRemote() => _remote = null;

  Future<void> syncWithRemote() async {
    final remote = _remote;
    if (remote == null || !remote.available) return;
    try {
      final onServer = await remote.list();
      if (onServer == null) return; // cópia na conta desligada no servidor
      var changed = false;
      for (final s in onServer) {
        if (isPlugged(s.id) || BrainChip.byId(s.id) == null) continue;
        final key = await remote.key(s.id);
        if (key == null || key.isEmpty) continue;
        _plugged.add(PluggedChip(id: s.id, key: key));
        changed = true;
      }
      final serverIds = onServer.map((s) => s.id).toSet();
      for (var i = 0; i < _plugged.length; i++) {
        final p = _plugged[i];
        if (!serverIds.contains(p.id)) await remote.put(p.id, p.key, i, p.status);
      }
      if (changed) {
        await _save();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[WaxBrain] Sincronização com a conta falhou (segue no celular): $e');
    }
  }

  /// Testa a chave no provedor com uma chamada gratuita (lista de modelos), sem gastar cota de IA.
  Future<BrainKeyStatus> check(BrainChip chip, String key) async {
    try {
      final res = await _client
          .get(chip.checkUrl(key), headers: {'Accept': 'application/json', ...chip.checkHeaders(key)})
          .timeout(const Duration(seconds: 15));
      return statusForHttp(res.statusCode);
    } catch (e) {
      debugPrint('[WaxBrain] Teste da chave ${chip.id} sem resposta: $e');
      return BrainKeyStatus.offline;
    }
  }

  /// Código HTTP do teste → situação do chip.
  static BrainKeyStatus statusForHttp(int code) {
    if (code >= 200 && code < 300) return BrainKeyStatus.ok;
    if (code == 429 || code == 402) return BrainKeyStatus.limit;
    if (code == 400 || code == 401 || code == 403) return BrainKeyStatus.invalid;
    return BrainKeyStatus.offline;
  }

  /// Encaixa (ou troca) a chave de um chip depois de testá-la. Chave recusada não é encaixada.
  Future<BrainKeyStatus> plug(BrainChip chip, String key) async {
    final k = key.trim();
    final status = await check(chip, k);
    if (status == BrainKeyStatus.invalid) return status;
    final entry = PluggedChip(id: chip.id, key: k, status: status, checkedAt: DateTime.now());
    final i = _plugged.indexWhere((p) => p.id == chip.id);
    if (i >= 0) {
      _plugged[i] = entry;
    } else {
      _plugged.add(entry);
    }
    await _save();
    notifyListeners();
    final position = _plugged.indexWhere((p) => p.id == chip.id);
    unawaited(_remoteDo((r) => r.put(chip.id, k, position, status)));
    return status;
  }

  /// Desencaixa: apaga a chave do celular e da conta.
  Future<void> unplug(String id) async {
    _plugged.removeWhere((p) => p.id == id);
    await _save();
    notifyListeners();
    unawaited(_remoteDo((r) => r.delete(id)));
  }

  /// Nova ordem de prioridade (arrastar).
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _plugged.length) return;
    final item = _plugged.removeAt(oldIndex);
    _plugged.insert(newIndex.clamp(0, _plugged.length), item);
    await _save();
    notifyListeners();
    final ids = [for (final p in _plugged) p.id];
    unawaited(_remoteDo((r) => r.order(ids)));
  }

  /// Testa de novo um chip encaixado (ex.: amarelo de limite, no dia seguinte).
  Future<BrainKeyStatus> recheck(String id) async {
    final i = _plugged.indexWhere((p) => p.id == id);
    final chip = BrainChip.byId(id);
    if (i < 0 || chip == null) return BrainKeyStatus.offline;
    final status = await check(chip, _plugged[i].key);
    _plugged[i] = _plugged[i].copyWith(status: status, checkedAt: DateTime.now());
    await _save();
    notifyListeners();
    return status;
  }

  /// Ao abrir o app: testa de novo os chips marcados como recusados ou no limite há mais de [age] — um limite
  /// por minuto, ou um erro de um pedido só, não deve deixar o chip desligado para sempre.
  Future<void> recheckStale({Duration age = const Duration(minutes: 30)}) async {
    await load();
    for (final p in List.of(_plugged)) {
      if (p.status == BrainKeyStatus.ok) continue;
      final at = p.checkedAt;
      if (at != null && DateTime.now().difference(at) < age) continue;
      await recheck(p.id);
    }
  }

  /// Situação vista ao usar o chip (ex.: limite do dia atingido durante uma tradução).
  Future<void> markStatus(String id, BrainKeyStatus status) async {
    final i = _plugged.indexWhere((p) => p.id == id);
    if (i < 0 || _plugged[i].status == status) return;
    _plugged[i] = _plugged[i].copyWith(status: status, checkedAt: DateTime.now());
    await _save();
    notifyListeners();
  }

  /// Apaga tudo do celular (ex.: sair da conta). A cópia na conta continua.
  Future<void> clearLocal() async {
    _plugged.clear();
    await _store.write(null);
    notifyListeners();
  }

  Future<void> _remoteDo(Future<void> Function(BrainRemote r) op) async {
    final r = _remote;
    if (r == null || !r.available) return;
    try {
      await op(r);
    } catch (e) {
      debugPrint('[WaxBrain] Conta não atualizada (fica no celular): $e');
    }
  }
}
