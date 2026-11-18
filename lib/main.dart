import 'package:flutter/material.dart';

import 'app.dart';
import 'data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await session.restore();
  runApp(JasTipGo(session: session));
}
