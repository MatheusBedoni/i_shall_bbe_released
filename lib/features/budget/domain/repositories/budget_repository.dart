import '../../../../core/utils/result.dart';
import '../entities/allocation_rule.dart';
import '../entities/budget_entry.dart';
import '../entities/budget_period.dart';

/// Contrato de persistência do orçamento. O usuário corrente é resolvido pela
/// implementação (camada data), nunca pelo domínio.
abstract interface class BudgetRepository {
  /// Emite os lançamentos do período em tempo real.
  Stream<Result<List<BudgetEntry>>> watchEntries(BudgetPeriod period);

  /// Adiciona um lançamento. O `id` é gerado pela implementação.
  Future<Result<BudgetEntry>> addEntry(BudgetEntry entry);

  Future<Result<void>> updateEntry(BudgetEntry entry);

  Future<Result<void>> deleteEntry(String entryId);

  /// Copia os lançamentos de um período para outro (ex.: repetir mês anterior).
  Future<Result<int>> copyEntries({
    required BudgetPeriod from,
    required BudgetPeriod to,
  });

  /// Emite a regra de alocação; usa o padrão quando ainda não foi salva.
  Stream<Result<AllocationRule>> watchAllocationRule();

  Future<Result<void>> saveAllocationRule(AllocationRule rule);
}
