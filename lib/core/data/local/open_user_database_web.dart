import 'package:sembast_web/sembast_web.dart';

Future<Database> openUserDatabase(String uid) =>
    databaseFactoryWeb.openDatabase('isbr_user_$uid');
