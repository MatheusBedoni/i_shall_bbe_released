// PLACEHOLDER — substitua este arquivo rodando, na raiz do projeto:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// O comando gera um `DefaultFirebaseOptions` real com as chaves do seu
// projeto Firebase. Enquanto isso não acontece, o app exibe uma tela de
// configuração em vez de quebrar.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase não configurado. Rode `flutterfire configure` na raiz do '
      'projeto para gerar lib/firebase_options.dart.',
    );
  }
}
