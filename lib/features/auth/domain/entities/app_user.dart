/// Usuário autenticado, visto pelo domínio. Independente do Firebase.
final class AppUser {
  const AppUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, email, displayName);
}
