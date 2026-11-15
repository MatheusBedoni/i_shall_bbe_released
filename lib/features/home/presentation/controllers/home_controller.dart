import 'package:flutter/foundation.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/get_greeting.dart';
import 'home_state.dart';

/// Controller da tela (gerenciamento de estado com [ChangeNotifier]).
///
/// Depende apenas de use cases. Pode ser trocado por Bloc/Riverpod sem
/// alterar domínio ou data.
final class HomeController extends ChangeNotifier {
  HomeController({required this.getGreeting});

  final GetGreeting getGreeting;

  HomeState _state = const HomeInitial();
  HomeState get state => _state;

  Future<void> loadGreeting() async {
    _emit(const HomeLoading());
    final result = await getGreeting(const NoParams());
    _emit(
      result.fold(
        (failure) => HomeError(failure.message),
        (greeting) => HomeLoaded(greeting),
      ),
    );
  }

  void _emit(HomeState state) {
    _state = state;
    notifyListeners();
  }
}
