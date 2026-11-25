import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

DatabaseFactory get taskDatabaseFactory => databaseFactorySqflitePlugin;

Future<String> taskDirectory() async => (await const MethodChannel(
  'artikids/storage',
).invokeMethod<String>('documents'))!;

Future<String?> readLegacyTasks(String directory) async {
  final file = File('$directory/tasks.json');
  return await file.exists() ? await file.readAsString() : null;
}

Future<void> removeLegacyTasks(String directory) async {
  final file = File('$directory/tasks.json');
  if (await file.exists()) await file.delete();
}
