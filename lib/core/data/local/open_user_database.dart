import 'package:sembast/sembast.dart';

import 'open_user_database_io.dart'
    if (dart.library.js_interop) 'open_user_database_web.dart' as impl;

/// Abre (ou cria) o banco local do usuário [uid] no armazenamento da
/// plataforma: arquivo no diretório de suporte do app em mobile/desktop,
/// IndexedDB na web.
Future<Database> openUserDatabase(String uid) => impl.openUserDatabase(uid);
