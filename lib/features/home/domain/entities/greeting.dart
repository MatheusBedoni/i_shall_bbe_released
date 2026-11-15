/// Entidade de domínio: objeto de negócio puro, sem dependência de Flutter,
/// JSON ou qualquer detalhe de infraestrutura.
final class Greeting {
  const Greeting({required this.message, required this.createdAt});

  final String message;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Greeting &&
          other.message == message &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(message, createdAt);

  @override
  String toString() => 'Greeting(message: $message, createdAt: $createdAt)';
}
