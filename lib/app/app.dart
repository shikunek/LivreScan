import 'package:flutter/material.dart';

import 'router.dart';

class LivreScanApp extends StatelessWidget {
  const LivreScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LivreScan',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: appRouter,
    );
  }
}
