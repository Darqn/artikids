import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

DatabaseFactory get taskDatabaseFactory => databaseFactoryFfiWeb;

Future<String> taskDirectory() async => '';

Future<String?> readLegacyTasks(String directory) async => null;

Future<void> removeLegacyTasks(String directory) async {}
