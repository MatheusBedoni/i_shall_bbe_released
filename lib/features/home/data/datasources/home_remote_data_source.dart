import '../../../../core/error/exceptions.dart';
import '../models/greeting_model.dart';

/// Fonte de dados remota. Lança exceções ([ServerException]); quem converte
/// em [Failure] é o repositório.
abstract interface class HomeRemoteDataSource {
  Future<GreetingModel> fetchGreeting();
}

/// Implementação de exemplo. Substitua pela chamada HTTP real
/// (dio, http, etc.) quando o backend existir.
final class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  const HomeRemoteDataSourceImpl();

  @override
  Future<GreetingModel> fetchGreeting() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      return GreetingModel.fromJson({
        'message': 'I shall be released',
        'created_at': DateTime.now().toIso8601String(),
      });
    } on Object catch (e) {
      throw ServerException(e.toString());
    }
  }
}
