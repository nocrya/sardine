import 'package:flutter/material.dart';
import 'package:sardine/app.dart';
import 'package:sardine/core/di/dependency_injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const SardineApp());
}
