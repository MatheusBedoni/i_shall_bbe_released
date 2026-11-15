import 'package:flutter/material.dart';

import '../../domain/entities/app_user.dart';

/// Decide entre a tela de login e o app autenticado conforme o estado de auth.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authState,
    required this.initialUser,
    required this.signedOut,
    required this.signedIn,
  });

  final Stream<AppUser?> authState;
  final AppUser? initialUser;
  final Widget signedOut;
  final Widget Function(AppUser user) signedIn;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: authState,
      initialData: initialUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null ? signedOut : signedIn(user);
      },
    );
  }
}
