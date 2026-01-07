import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/common/theme.dart' as app_theme;

class ScriptOutputPanel extends StatelessWidget {
  final String scriptOutput;

  const ScriptOutputPanel({super.key, required this.scriptOutput});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0), // Consistent margin with ErrorDebugPanel
      color: app_theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Consistent padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align title
              children: [
                Text(
                  'Script Output',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: app_theme.textPrimary, // Use primary text color
                  ),
                ),
                // No clear button requested for script output
              ],
            ),
            const Divider(), // Add a divider below the title
            Expanded( // Wrap the scrollable content in Expanded
              child: SingleChildScrollView(
                child: Text(
                  scriptOutput,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith( // Consistent text style
                    color: app_theme.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
