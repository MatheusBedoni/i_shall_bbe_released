import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/streams.dart';
import '../entities/asset.dart';
import '../entities/asset_transaction.dart';
import '../entities/contribution.dart';
import '../entities/dividend.dart';
import '../repositories/portfolio_repository.dart';

export 'compute_positions.dart';
export 'quote_usecases.dart';

// ----------------------------------------------------------------- Ativos

final class WatchAssets {
  const WatchAssets(this._repo);
  final PortfolioRepository _repo;
  Stream<Result<List<Asset>>> call() => _repo.watchAssets();
}

final class AddAsset implements UseCase<Asset, Asset> {
  const AddAsset(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<Asset>> call(Asset asset) async {
    final invalid = validateAsset(asset);
    if (invalid != null) return Error(invalid);
    return _repo.addAsset(normalizeAsset(asset));
  }
}

final class UpdateAsset implements UseCase<void, Asset> {
  const UpdateAsset(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<void>> call(Asset asset) async {
    final invalid = validateAsset(asset);
    if (invalid != null) return Error(invalid);
    return _repo.updateAsset(normalizeAsset(asset));
  }
}

final class DeleteAsset implements UseCase<void, String> {
  const DeleteAsset(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<void>> call(String assetId) => _repo.deleteAsset(assetId);
}

// ------------------------------------------------------------- Transações

final class WatchTransactions {
  const WatchTransactions(this._repo);
  final PortfolioRepository _repo;
  Stream<Result<List<AssetTransaction>>> call() => _repo.watchTransactions();
}

final class AddTransaction
    implements UseCase<AssetTransaction, AssetTransaction> {
  const AddTransaction(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<AssetTransaction>> call(AssetTransaction tx) async {
    final invalid = validateTransaction(tx);
    if (invalid != null) return Error(invalid);
    return _repo.addTransaction(tx);
  }
}

final class UpdateTransaction implements UseCase<void, AssetTransaction> {
  const UpdateTransaction(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<void>> call(AssetTransaction tx) async {
    final invalid = validateTransaction(tx);
    if (invalid != null) return Error(invalid);
    return _repo.updateTransaction(tx);
  }
}

final class DeleteTransaction implements UseCase<void, String> {
  const DeleteTransaction(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<void>> call(String txId) => _repo.deleteTransaction(txId);
}

// -------------------------------------------------------------- Proventos

final class WatchDividends {
  const WatchDividends(this._repo);
  final PortfolioRepository _repo;
  Stream<Result<List<Dividend>>> call() => _repo.watchDividends();
}

final class AddDividend implements UseCase<Dividend, Dividend> {
  const AddDividend(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<Dividend>> call(Dividend dividend) async {
    final invalid = validateDividend(dividend);
    if (invalid != null) return Error(invalid);
    return _repo.addDividend(dividend);
  }
}

final class UpdateDividend implements UseCase<void, Dividend> {
  const UpdateDividend(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<void>> call(Dividend dividend) async {
    final invalid = validateDividend(dividend);
    if (invalid != null) return Error(invalid);
    return _repo.updateDividend(dividend);
  }
}

final class DeleteDividend implements UseCase<void, String> {
  const DeleteDividend(this._repo);
  final PortfolioRepository _repo;

  @override
  Future<Result<void>> call(String dividendId) =>
      _repo.deleteDividend(dividendId);
}

// ---------------------------------------------------------------- Aportes

/// Emite todas as compras da carteira já associadas ao seu ativo, ordenadas
/// da mais recente para a mais antiga. É o que o orçamento mensal consome
/// para saber quanto foi investido em cada mês.
final class WatchContributions {
  const WatchContributions(this._repo);
  final PortfolioRepository _repo;

  Stream<Result<List<Contribution>>> call() => combineLatest2(
        _repo.watchAssets(),
        _repo.watchTransactions(),
        (assetsResult, txsResult) => switch ((assetsResult, txsResult)) {
          (Error(:final failure), _) => Error<List<Contribution>>(failure),
          (_, Error(:final failure)) => Error<List<Contribution>>(failure),
          (Success(value: final assets), Success(value: final txs)) =>
            Success(buildContributions(assets: assets, transactions: txs)),
        },
      );

  static List<Contribution> buildContributions({
    required List<Asset> assets,
    required List<AssetTransaction> transactions,
  }) {
    final byId = {for (final a in assets) a.id: a};
    final list = <Contribution>[];
    for (final tx in transactions) {
      if (tx.type != TransactionType.buy) continue;
      final asset = byId[tx.assetId];
      if (asset == null) continue;
      list.add(Contribution(transaction: tx, asset: asset));
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}

// -------------------------------------------------------------- Validação

Failure? validateAsset(Asset asset) {
  if (asset.ticker.trim().isEmpty) {
    return const ValidationFailure('Informe o código do ativo.');
  }
  if (asset.name.trim().isEmpty) {
    return const ValidationFailure('Informe o nome do ativo.');
  }
  return null;
}

Asset normalizeAsset(Asset asset) => asset.copyWith(
      ticker: asset.ticker.trim().toUpperCase(),
      name: asset.name.trim(),
    );

Failure? validateTransaction(AssetTransaction tx) {
  if (tx.assetId.isEmpty) {
    return const ValidationFailure('Selecione um ativo.');
  }
  if (!_positive(tx.quantity)) {
    return const ValidationFailure('A quantidade deve ser maior que zero.');
  }
  if (!_positive(tx.unitPrice)) {
    return const ValidationFailure('O preço deve ser maior que zero.');
  }
  if (tx.fees < 0 || tx.fees.isNaN || tx.fees.isInfinite) {
    return const ValidationFailure('As taxas não podem ser negativas.');
  }
  return null;
}

Failure? validateDividend(Dividend dividend) {
  if (dividend.assetId.isEmpty) {
    return const ValidationFailure('Selecione um ativo.');
  }
  if (!_positive(dividend.amount)) {
    return const ValidationFailure('O valor deve ser maior que zero.');
  }
  return null;
}

bool _positive(double v) => v > 0 && !v.isNaN && !v.isInfinite;
