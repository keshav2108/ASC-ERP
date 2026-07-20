import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AscManagerApp(),
    ),
  );
}

class AscManagerApp extends StatelessWidget {
  const AscManagerApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASC Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}
