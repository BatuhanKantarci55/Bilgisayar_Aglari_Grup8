import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:flutter_application_1/ui/common/theme.dart' as app_theme;
import 'package:flutter_application_1/ui/common/error_watcher.dart'; // Import error watcher
import 'package:flutter_application_1/ui/common/error_debug_panel.dart'; // Import ErrorDebugPanel
import 'package:flutter_application_1/ui/common/script_output_panel.dart'; // Import the new ScriptOutputPanel
import 'package:flutter_application_1/logic/graph_repository.dart'; // Add this import

class DeveloperPage extends ConsumerStatefulWidget {
  final ValueChanged<String> onScriptOutputChanged;
  final Function(Future<void> Function())? onScript4ExecutorReady; // New callback
  final String sourceNodeId; // New parameter
  final String targetNodeId; // New parameter
  final double demandMbps; // New parameter

  const DeveloperPage({
    super.key,
    required this.onScriptOutputChanged,
    this.onScript4ExecutorReady,
    this.sourceNodeId = '', // Provide default value
    this.targetNodeId = '', // Provide default value
    this.demandMbps = 0.0, // Provide default value
  });

  @override
  ConsumerState<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends ConsumerState<DeveloperPage> {
  String _scriptOutput = 'No script output yet.';
  bool _isLoading = false;
  late final TextEditingController _scriptPathController1;
  late final TextEditingController _scriptPathController2;
  late final TextEditingController _scriptPathController3;
  late final TextEditingController _scriptPathController4;
  late final TextEditingController _executableDirController; // New controller for executable directory
  late final TextEditingController _demandFilePathController; // New controller for demand file path

  @override
  void initState() {
    super.initState();
    ref.read(errorWatcherProvider); // Initialize ErrorWatcher
    _scriptPathController1 = TextEditingController(text: '\"C:\\Programming\\Projects\\Flutter_NetGraph\\flutter_application_1\\scripts\\algorithms\\genetics.py\"');
    _scriptPathController2 = TextEditingController(text: 'C:\\Programming\\Projects\\Flutter_NetGraph\\flutter_application_1\\scripts\\algorithms\\aco.py');
    _scriptPathController3 = TextEditingController(text: '"C:\\Programming\\Projects\\Flutter_NetGraph\\flutter_application_1\\scripts\\hello_world.py"');
    _scriptPathController4 = TextEditingController(text: '"C:\\Programming\\Projects\\Flutter_NetGraph\\flutter_application_1\\scripts\\algorithms\\network_manager.py"');
    _executableDirController = TextEditingController(text: 'C:\\Programming\\Projects\\Flutter_NetGraph\\flutter_application_1\\scripts\\algorithms\\.venv\\Scripts\\python.exe'); // Initialize controller for executable directory
    _demandFilePathController = TextEditingController(text: './scripts/data/demand.csv'); // Initialize demand file path controller

    // Pass the runScript4 function to the parent when ready
    widget.onScript4ExecutorReady?.call(runScript4);
  }

  // Public method to expose script 4 execution
  Future<void> runScript4() async {
    await _runPythonScript(_scriptPathController4);
  }

  @override
  void dispose() {
    _scriptPathController1.dispose();
    _scriptPathController2.dispose();
    _scriptPathController3.dispose();
    _scriptPathController4.dispose(); // Dispose new controller
    _executableDirController.dispose(); // Dispose controller for executable directory
    _demandFilePathController.dispose(); // Dispose demand file path controller
    super.dispose();
  }

  /// Blueprint method to execute a Python script with robust error handling and path management.
  /// Returns a ProcessResult containing stdout, stderr, and exitCode.
  /// The working directory for the Python script is set to the script's parent directory.
  Future<ProcessResult> _executePythonScript(String scriptPath) async {
    // 1. SANITIZATION: Remove quotes that might have been pasted in.
    String rawPath = scriptPath.trim();
    if (rawPath.startsWith('"') && rawPath.endsWith('"')) {
      rawPath = rawPath.substring(1, rawPath.length - 1);
    }
    final cleanPath = rawPath.replaceAll(r'\\', r'\');
    
    final scriptFile = File(cleanPath);

    if (!await scriptFile.exists()) {
      ref.read(errorListProvider.notifier).addError('ERROR: Script file not found at: $cleanPath');
      return ProcessResult(1, 1, '', 'ERROR: Script file not found at: $cleanPath');
    }

    final pythonExecutable = _executableDirController.text;

    if (Platform.isWindows) {
      return await Process.run(
        'cmd', 
        ['/c', pythonExecutable, scriptFile.path],
        runInShell: true, 
        workingDirectory: scriptFile.parent.path, 
      );
    } else {
      return await Process.run(
        pythonExecutable, 
        [scriptFile.path],
        runInShell: true,
        workingDirectory: scriptFile.parent.path,
      );
    }
  }

  Future<void> _runPythonScript(TextEditingController controller) async {
    setState(() {
      _isLoading = true;
      _scriptOutput = 'Initializing script execution...';
      widget.onScriptOutputChanged(_scriptOutput);
    });

    try {
      final scriptPath = controller.text;
      final result = await _executePythonScript(scriptPath);

      setState(() {
        _scriptOutput = 'Script execution finished.\n'
            'Exit Code: ${result.exitCode}\n\n'
            'STDOUT:\n${result.stdout}\n'
            'STDERR:\n${result.stderr}';
        widget.onScriptOutputChanged(_scriptOutput);

        if (result.exitCode != 0) {
          final errorDetails = 'Script Error (Exit Code: ${result.exitCode}):\n'
              'STDOUT:\n${result.stdout}\n'
              'STDERR:\n${result.stderr}';
          ref.read(errorListProvider.notifier).addError(errorDetails);
        }
      });

      // Special handling for Script Path 3
      if (controller == _scriptPathController3) {
        final file = File('C:\\Programming\\Projects\\Flutter_NetGraph\\flutter_application_1\\scripts\\hello.txt');
        if (await file.exists()) {
          final content = await file.readAsString();
          setState(() {
            _scriptOutput += '\n\n--- Content of hello.txt ---\n$content';
            widget.onScriptOutputChanged(_scriptOutput);
          });
        } else {
          setState(() {
            _scriptOutput += '\n\n--- Error: hello.txt not found ---';
            widget.onScriptOutputChanged(_scriptOutput);
          });
        }
      }

    } catch (e, st) {
      ref.read(errorListProvider.notifier).addError('CRITICAL EXCEPTION during script execution: $e\n$st');
      setState(() {
        _scriptOutput = 'CRITICAL EXCEPTION during script execution. Check error panel.';
        widget.onScriptOutputChanged(_scriptOutput);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentDirectory() async {
    setState(() {
      _isLoading = true;
      _scriptOutput = 'Checking current directory...';
      widget.onScriptOutputChanged(_scriptOutput);
    });

    try {
      final currentDirectory = Directory.current.path;
      setState(() {
        _scriptOutput = 'Current Directory:\n$currentDirectory';
        widget.onScriptOutputChanged(_scriptOutput);
      });
    } catch (e, st) {
      ref.read(errorListProvider.notifier).addError('Error checking current directory: $e\n$st');
      setState(() {
        _scriptOutput = 'Error checking current directory. Check error panel.';
        widget.onScriptOutputChanged(_scriptOutput);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildScriptExecutionSection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Script Execution',
            style: TextStyle(fontSize: 18, color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _executableDirController,
            decoration: const InputDecoration(
              labelText: 'Python Executable (e.g., python or python.exe)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _scriptPathController1,
            decoration: const InputDecoration(
              labelText: 'Script Path 1',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _runPythonScript(_scriptPathController1),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isLoading ? 'Running...' : 'Run Script 1'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.primaryContainer,
              ),
              foregroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.onPrimaryContainer,
              ),
              shape: WidgetStateProperty.all(const StadiumBorder()),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
              textStyle: WidgetStateProperty.all(
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              animationDuration: const Duration(milliseconds: 250),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _scriptPathController2,
            decoration: const InputDecoration(
              labelText: 'Script Path 2',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _runPythonScript(_scriptPathController2),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isLoading ? 'Running...' : 'Run Script 2'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.primaryContainer,
              ),
              foregroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.onPrimaryContainer,
              ),
              shape: WidgetStateProperty.all(const StadiumBorder()),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
              textStyle: WidgetStateProperty.all(
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              animationDuration: const Duration(milliseconds: 250),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _scriptPathController3,
            decoration: const InputDecoration(
              labelText: 'Script Path 3',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _runPythonScript(_scriptPathController3),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isLoading ? 'Running...' : 'Run Script 3'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.primaryContainer,
              ),
              foregroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.onPrimaryContainer,
              ),
              shape: WidgetStateProperty.all(const StadiumBorder()),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
              textStyle: WidgetStateProperty.all(
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              animationDuration: const Duration(milliseconds: 250),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _scriptPathController4,
            decoration: const InputDecoration(
              labelText: 'Script Path 4',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading ? null : () => _runPythonScript(_scriptPathController4),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_isLoading ? 'Running...' : 'Run Script 4'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.primaryContainer,
              ),
              foregroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.onPrimaryContainer,
              ),
              shape: WidgetStateProperty.all(const StadiumBorder()),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
              textStyle: WidgetStateProperty.all(
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              animationDuration: const Duration(milliseconds: 250),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryInfoSection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Directory Info',
            style: TextStyle(fontSize: 18, color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          // Removed Script Path 1, 2, and 3 TextFields
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading ? null : _checkCurrentDirectory,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.folder_open),
            label: Text(_isLoading ? 'Checking...' : 'Check Current Directory'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.secondaryContainer,
              ),
              foregroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.onSecondaryContainer,
              ),
              shape: WidgetStateProperty.all(const StadiumBorder()),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
              textStyle: WidgetStateProperty.all(
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              animationDuration: const Duration(milliseconds: 250),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDemandCsv() async {
    setState(() {
      _isLoading = true;
      _scriptOutput = 'Exporting demand data...';
      widget.onScriptOutputChanged(_scriptOutput);
    });

    try {
      final graphRepository = ref.read(graphRepositoryProvider);

      // Update GraphRepository parameters from widget properties
      graphRepository.updateGenerationParameters(
        sourceNodeId: widget.sourceNodeId,
        targetNodeId: widget.targetNodeId,
        demandMbps: widget.demandMbps,
      );

      await graphRepository.exportDemandFile();

      setState(() {
        _scriptOutput = 'Demand data exported successfully to ${_demandFilePathController.text}';
        widget.onScriptOutputChanged(_scriptOutput);
      });
    } catch (e, st) {
      ref.read(errorListProvider.notifier).addError('Error exporting demand data: $e\n$st');
      setState(() {
        _scriptOutput = 'Error exporting demand data. Check error panel.';
        widget.onScriptOutputChanged(_scriptOutput);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPlaceholderSection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Placeholder Section',
            style: TextStyle(fontSize: 18, color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _demandFilePathController,
            decoration: const InputDecoration(
              labelText: 'Demand File Path (for export)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: app_theme.textPrimary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading ? null : _exportDemandCsv,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isLoading ? 'Exporting...' : 'Export Demand CSV'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.tertiaryContainer,
              ),
              foregroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.onTertiaryContainer,
              ),
              shape: WidgetStateProperty.all(const StadiumBorder()),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
              textStyle: WidgetStateProperty.all(
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              animationDuration: const Duration(milliseconds: 250),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              // Placeholder action
              setState(() {
                _scriptOutput = 'Placeholder button pressed!';
                widget.onScriptOutputChanged(_scriptOutput);
              });
            },
            icon: const Icon(Icons.build),
            label: const Text('Placeholder Action'),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.tertiaryContainer,
              ),
              foregroundColor: WidgetStateProperty.all(
                app_theme.colorScheme.onTertiaryContainer,
              ),
              shape: WidgetStateProperty.all(const StadiumBorder()),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
              textStyle: WidgetStateProperty.all(
                Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              animationDuration: const Duration(milliseconds: 250),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Only three functional sections now
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Developer Page',
              style: TextStyle(fontSize: 24, color: app_theme.textPrimary),
            ),
          ),

          // Display script output and error panel side-by-side
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ScriptOutputPanel(scriptOutput: _scriptOutput), // Use the new ScriptOutputPanel
                ),
                const SizedBox(width: 8), // Spacing between the two panels
                Expanded(
                  child: const ErrorDebugPanel(), // ErrorDebugPanel now manages its own Card and Padding
                ),
              ],
            ),
          ),
          const SizedBox(height: 10), // Reduced spacing
          TabBar(
            labelColor: app_theme.colorScheme.primary, // Active tab color
            unselectedLabelColor: app_theme.colorScheme.onSurface, // Inactive tab color
            indicatorColor: app_theme.colorScheme.primary, // Indicator color
            tabs: const [
              Tab(text: 'Script Exec'),
              Tab(text: 'Dir Info'),
              Tab(text: 'Placeholder'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildScriptExecutionSection(context), // Section 1
                _buildDirectoryInfoSection(context),   // Section 2
                _buildPlaceholderSection(context),     // Section 3
              ],
            ),
          ),
        ],
      ),
    );
  }
}