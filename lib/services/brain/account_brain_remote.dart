import '../account/account_service.dart';
import 'brain_chips.dart';
import 'brain_service.dart';

/// Cópia das chaves do WaxBrain na conta WaxClub (API `/v1/brain`, criptografadas no servidor).
class AccountBrainRemote implements BrainRemote {
  final AccountService account;
  AccountBrainRemote(this.account);

  @override
  bool get available => account.isSignedIn;

  @override
  Future<List<({String id, String hint})>?> list() => account.brainList();

  @override
  Future<String?> key(String id) => account.brainKey(id);

  @override
  Future<void> put(String id, String key, int position, BrainKeyStatus status) =>
      account.brainPut(id, key, position, status.name);

  @override
  Future<void> delete(String id) => account.brainDelete(id);

  @override
  Future<void> order(List<String> ids) => account.brainOrder(ids);
}
