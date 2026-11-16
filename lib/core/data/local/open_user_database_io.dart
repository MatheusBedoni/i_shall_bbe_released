import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openUserDatabase(String uid) async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'local_db', 'user_$uid.db');
  return databaseFactoryIo.openDatabase(path);
}
