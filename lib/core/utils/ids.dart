import 'dart:math';

const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
final _random = Random.secure();

/// Gera um id aleatório no mesmo formato dos ids automáticos do Firestore
/// (20 caracteres alfanuméricos). Gerar o id no cliente permite criar o
/// documento localmente, offline, e enviá-lo depois com o mesmo id.
String newDocId([int length = 20]) => String.fromCharCodes(
      List.generate(
        length,
        (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
      ),
    );
