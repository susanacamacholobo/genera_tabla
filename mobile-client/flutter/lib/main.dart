import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_configuration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(Software1App(configuration: AppConfiguration.fromEnvironment()));
}
