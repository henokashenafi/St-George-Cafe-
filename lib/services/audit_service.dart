import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:st_george_pos/services/pos_repository.dart';
import 'package:st_george_pos/providers/pos_providers.dart';

class AuditService {
  final PosRepository _repo;
  final Ref _ref;

  AuditService(this._repo, this._ref);

  Future<void> log(String action, {String? details}) async {
    final user = _ref.read(authProvider);
    final userId = user?.id;

    // Log to database (or web storage)
    await _repo.addAuditLog(userId, action, details: details);
  }
}

final auditServiceProvider = Provider<AuditService>((ref) {
  final repo = ref.watch(posRepositoryProvider);
  return AuditService(repo, ref);
});
