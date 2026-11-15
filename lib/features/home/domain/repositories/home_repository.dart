import '../../../../core/utils/result.dart';
import '../entities/greeting.dart';

/// Contrato do repositório. Vive no domínio e é implementado na camada data.
/// O domínio depende apenas desta abstração (Dependency Inversion).
abstract interface class HomeRepository {
  Future<Result<Greeting>> getGreeting();
}
