import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugErrors {
  static final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  static void initHooks() {
    if (!kDebugMode) return;

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      lastError.value = _format(details.exceptionAsString(), details.stack);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      lastError.value = _format(error.toString(), stack);
      return false; // allow default handling too
    };
  }

  static String _format(String error, StackTrace? stack) {
    final s = stack?.toString() ?? '';
    return '${DateTime.now().toIso8601String()}\n$error\n$s';
  }
}

class DebugErrorBanner extends StatelessWidget {
  const DebugErrorBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return ValueListenableBuilder<String?>(
      valueListenable: DebugErrors.lastError,
      builder: (context, value, _) {
        if (value == null || value.isEmpty) return const SizedBox.shrink();
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Material(
                elevation: 8,
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: value));
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    if (messenger != null) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Copied error to clipboard')),
                      );
                    }
                  },
                  onTap: () => DebugErrors.lastError.value = null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Runtime error (tap to dismiss, long-press to copy):',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
