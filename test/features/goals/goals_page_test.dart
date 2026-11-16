import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/theme/app_theme.dart';
import 'package:i_shall_be_released/core/utils/money.dart';
import 'package:i_shall_be_released/features/goals/domain/entities/goal.dart';
import 'package:i_shall_be_released/features/goals/domain/usecases/goal_usecases.dart';
import 'package:i_shall_be_released/features/goals/presentation/controllers/goals_controller.dart';
import 'package:i_shall_be_released/features/goals/presentation/pages/goals_page.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset_transaction.dart';
import 'package:i_shall_be_released/features/portfolio/domain/usecases/portfolio_usecases.dart';
import 'package:i_shall_be_released/features/portfolio/presentation/controllers/portfolio_controller.dart';

import '../portfolio/fakes/in_memory_portfolio_repository.dart';
import 'fakes/in_memory_goal_repository.dart';

void main() {
  late InMemoryGoalRepository goalsRepo;
  late InMemoryPortfolioRepository portfolioRepo;
  late GoalsController goals;
  late PortfolioController portfolio;

  setUp(() async {
    goalsRepo = InMemoryGoalRepository();
    portfolioRepo = InMemoryPortfolioRepository();
    // Um ativo de renda fixa (sem cotação) valendo R$ 4.000.
    final asset = (await portfolioRepo.addAsset(const Asset(
      id: '',
      ticker: 'TESOURO-SELIC',
      name: 'Tesouro Selic 2029',
      assetClass: AssetClass.fixedIncome,
    )))
        .valueOrNull!;
    await portfolioRepo.addTransaction(AssetTransaction(
      id: '',
      assetId: asset.id,
      type: TransactionType.buy,
      quantity: 4000,
      unitPrice: 1,
      date: DateTime(2026, 1, 10),
    ));

    goals = GoalsController(
      watchGoals: WatchGoals(goalsRepo),
      addGoal: AddGoal(goalsRepo),
      updateGoal: UpdateGoal(goalsRepo),
      deleteGoal: DeleteGoal(goalsRepo),
      computeSnapshots: const ComputeGoalSnapshots(),
    );
    final quotes = FakeQuoteRepository();
    portfolio = PortfolioController(
      watchAssets: WatchAssets(portfolioRepo),
      watchTransactions: WatchTransactions(portfolioRepo),
      watchDividends: WatchDividends(portfolioRepo),
      addAsset: AddAsset(portfolioRepo),
      updateAsset: UpdateAsset(portfolioRepo),
      deleteAsset: DeleteAsset(portfolioRepo),
      addTransaction: AddTransaction(portfolioRepo),
      updateTransaction: UpdateTransaction(portfolioRepo),
      deleteTransaction: DeleteTransaction(portfolioRepo),
      addDividend: AddDividend(portfolioRepo),
      updateDividend: UpdateDividend(portfolioRepo),
      deleteDividend: DeleteDividend(portfolioRepo),
      getQuotes: GetQuotes(quotes),
      searchTickers: SearchTickers(quotes),
      computePositions: const ComputePositions(),
    );
  });

  tearDown(() {
    goals.dispose();
    portfolio.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: GoalsPage(controller: goals, portfolio: portfolio),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('cria meta vinculada a um ativo e abre o detalhe', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester);
    expect(find.text('Nenhuma meta ainda'), findsOneWidget);

    await tester.tap(find.text('Nova meta'));
    await tester.pumpAndSettle();
    expect(find.text('Vincular investimentos'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Reserva');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor da meta'), '10000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Aporte mensal'), '500');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Rentabilidade a.a.'), '0');
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    // Com vínculo, o campo manual muda de rótulo e o resumo aparece.
    expect(find.text('Saldo fora da carteira (opcional)'), findsOneWidget);
    expect(find.textContaining('carteira ${Money.format(4000)}'), findsOneWidget);

    await tester.tap(find.text('Criar meta'));
    await tester.pumpAndSettle();

    expect(find.text('Reserva'), findsOneWidget);
    expect(find.text('${Money.format(4000)} de ${Money.format(10000)}'), findsOneWidget);
    expect(find.text('TESOURO-SELIC'), findsOneWidget);
    // 4000 + 12 × 500 = 10000 → 1 ano.
    expect(find.text('Previsão: 1 ano'), findsOneWidget);
    expect(goalsRepo.goals.single.linkedAssetIds, hasLength(1));

    await tester.tap(find.text('Reserva'));
    await tester.pumpAndSettle();
    expect(find.text('Investimentos vinculados'), findsOneWidget);
    expect(find.text('Projeção'), findsOneWidget);
    expect(find.text('Faltam ${Money.format(6000)}'), findsOneWidget);
    expect(find.textContaining('TESOURO-SELIC · Tesouro Selic 2029'), findsOneWidget);
  });

  testWidgets('excluir meta pelo detalhe volta para a lista', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await goalsRepo.addGoal(const Goal(
      id: '',
      name: 'Viagem',
      targetAmount: 5000,
      currentAmount: 5000,
      monthlyContribution: 0,
      annualRate: 0,
    ));
    await pump(tester);
    expect(find.text('Meta atingida'), findsOneWidget);

    await tester.tap(find.text('Viagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Excluir meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma meta ainda'), findsOneWidget);
    expect(goalsRepo.goals, isEmpty);
  });
}
