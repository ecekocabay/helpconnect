import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'app.dart';
import 'amplifyconfiguration.dart';
import 'debug_errors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) DebugErrors.initHooks();

  await _configureAmplify();

  runApp(const HelpConnectApp());
}

Future<void> _configureAmplify() async {
  // Hot restart on iOS can try to register the plugin twice which crashes the app.
  try {
    await Amplify.addPlugin(AmplifyAuthCognito());
  } on AmplifyAlreadyConfiguredException {
    debugPrint('ℹ️ Amplify plugin already added, skipping.');
  } catch (e) {
    debugPrint('⚠️ Amplify addPlugin error: $e');
    return;
  }

  if (Amplify.isConfigured) {
    debugPrint('ℹ️ Amplify already configured. Skipping configure call.');
    return;
  }

  try {
    await Amplify.configure(amplifyconfig);
    debugPrint('✅ Amplify configured');
  } on AmplifyAlreadyConfiguredException {
    debugPrint('ℹ️ Amplify already configured at native layer.');
  } catch (e) {
    debugPrint('⚠️ Amplify configure error: $e');
  }
}
