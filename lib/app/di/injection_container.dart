import '../../features/home/data/datasources/home_remote_data_source.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_greeting.dart';
import '../../features/home/presentation/controllers/home_controller.dart';

/// Composition root: o único lugar que conhece as implementações concretas.
///
/// Feito à mão para não depender de pacotes; pode ser migrado para `get_it`
/// ou `riverpod` sem mudar nenhuma outra camada.
final class InjectionContainer {
  InjectionContainer._();

  static InjectionContainer? _instance;
  static InjectionContainer get instance => _instance ??= InjectionContainer._();

  // ---- Home: data ----
  late final HomeRemoteDataSource homeRemoteDataSource =
      const HomeRemoteDataSourceImpl();

  late final HomeRepository homeRepository =
      HomeRepositoryImpl(remoteDataSource: homeRemoteDataSource);

  // ---- Home: domain ----
  late final GetGreeting getGreeting = GetGreeting(homeRepository);

  // ---- Home: presentation (factories, uma instância por tela) ----
  HomeController newHomeController() => HomeController(getGreeting: getGreeting);

  /// Útil em testes para começar com um grafo limpo.
  static void reset() => _instance = null;
}
