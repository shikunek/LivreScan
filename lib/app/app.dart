import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class LivreScanApp extends StatelessWidget {
  const LivreScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LivreScan',
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
