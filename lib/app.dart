import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme.dart'; // ✅ NEW
import 'route_logger.dart';
import 'package:flutter/foundation.dart';
import 'debug_errors.dart';

class HelpConnectApp extends StatelessWidget {
  const HelpConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ NEW: Use boot route instead of login
      initialRoute: AppRoutes.boot,

      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [RouteLogger()],

      // ✅ NEW: apply theme
      theme: HelpConnectTheme.light,
      // In debug, inject an overlay banner that shows runtime errors
      builder: (context, child) {
        if (!kDebugMode) return child!;
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            const IgnorePointer(ignoring: false, child: DebugErrorBanner()),
          ],
        );
      },
    );
  }
}