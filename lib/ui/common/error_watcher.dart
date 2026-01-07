import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final errorListProvider = StateNotifierProvider<ErrorNotifier, List<String>>((ref) {
  return ErrorNotifier();
});

class ErrorNotifier extends StateNotifier<List<String>> {
  ErrorNotifier() : super([]);

  void addError(String error) {
    state = [...state, error];
  }

  void clearErrors() {
    state = [];
  }
}

class ErrorWatcher {
  final Ref ref;

  ErrorWatcher(this.ref) {
    _initErrorMonitoring();
  }
void _initErrorMonitoring() {
    // Capture Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      ref.read(errorListProvider.notifier).addError(details.toStringShort());
    };

    // Capture errors from the platform dispatcher
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      ref.read(errorListProvider.notifier).addError('Platform Error: $error\n$stack');
      return true; // Indicates that the error has been handled
    };
  }
}

final errorWatcherProvider = Provider<ErrorWatcher>((ref) {
  return ErrorWatcher(ref);
});
