import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme.dart';

class HelpConnectApp extends StatelessWidget {
  const HelpConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HelpConnect',
      debugShowCheckedModeBanner: false,
      theme: HelpConnectTheme.light,
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}