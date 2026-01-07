import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/ui/common/error_watcher.dart'; // Import errorListProvider
import 'package:flutter_application_1/ui/common/theme.dart' as app_theme;


class ErrorDebugPanel extends ConsumerWidget {
  const ErrorDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(errorListProvider);

    return Card(
      margin: const EdgeInsets.all(16.0),
      color: app_theme.colorScheme.errorContainer, // Use error container color
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Runtime Errors (${errors.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: app_theme.colorScheme.onErrorContainer,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => ref.read(errorListProvider.notifier).clearErrors(),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      app_theme.colorScheme.error, // Use error color for clear button
                    ),
                    foregroundColor: WidgetStateProperty.all(
                      app_theme.colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: errors.isEmpty
                  ? Center(
                      child: Text(
                        'No runtime errors yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: app_theme.colorScheme.onErrorContainer.withAlpha(((app_theme.colorScheme.onErrorContainer.a * 0.7).round()).clamp(0, 255)),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: errors.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            errors[index],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: app_theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}