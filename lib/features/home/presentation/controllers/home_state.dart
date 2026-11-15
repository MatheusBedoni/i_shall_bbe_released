import '../../domain/entities/greeting.dart';

/// Estado imutável da tela. A UI faz `switch` exaustivo sobre ele.
sealed class HomeState {
  const HomeState();
}

final class HomeInitial extends HomeState {
  const HomeInitial();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeLoaded extends HomeState {
  const HomeLoaded(this.greeting);
  final Greeting greeting;
}

final class HomeError extends HomeState {
  const HomeError(this.message);
  final String message;
}
