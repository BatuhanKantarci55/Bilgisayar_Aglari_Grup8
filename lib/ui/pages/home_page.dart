import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/logic/graph_network.dart';
import 'package:flutter_application_1/logic/graph_repository.dart';
import 'package:flutter_application_1/ui/graph/graph_widget.dart';
import 'package:flutter_application_1/ui/common/theme.dart'
    as app_theme; // Keep for app_theme.colorSchemeNotifier
import 'package:flutter_application_1/logic/rendering_method.dart';
import 'package:flutter_application_1/logic/physics_algorithm.dart';
import 'package:flutter_application_1/ui/pages/settings_page.dart'; // Import the new SettingsPage
import 'package:flutter_application_1/ui/pages/developer_page.dart';
import 'dart:io'; // Added for file operations
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:flutter_application_1/logic/file_read.dart'; // Import for FileRead
import 'dart:math' as math; // Import for math.min
import 'package:flutter_application_1/ui/common/error_watcher.dart'; // Import error watcher


enum SelectionMode { source, target }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;
  late final TextEditingController _filterController;
  late final TextEditingController _nodeCountController;
  late final TextEditingController _connectionProbabilityController;

  late final TextEditingController _sourceNodeController;
  late final TextEditingController _targetNodeController;
  late final TextEditingController _bandwidthFilterController;

  String _infoPanelText = 'Info Panel: Output and logs will appear here.';
  double _sliderValue1 = 1.0 / 3.0;
  double _sliderValue2 = 1.0 / 3.0;
  double _sliderValue3 = 1.0 / 3.0;
  double _bandwidthSliderValue = 100.0; // Initial value for bandwidth slider

  String _selectedDropdownValue = 'Genetics Algorithm'; // New variable for dropdown
  late final ValueNotifier<String> _dropdownValueNotifier; // Notifier for dropdown value
  bool _generateGraphRequested = false; // New flag to indicate graph generation request

  Node? _sourceNode; // Handled locally for UI selection
  Node? _targetNode; // Handled locally for UI selection
  SelectionMode _selectionMode = SelectionMode.source;

  late final TextEditingController _paramXController; // New controller for param_X
  late final TextEditingController _paramYController; // New controller for param_Y
  late final TextEditingController _paramZController; // New controller for param_Z
  
  late final TextEditingController _paramAController; // New controller for param_A
  late final TextEditingController _paramBController; // New controller for param_B
  late final TextEditingController _paramCController; // New controller for param_C
  late final TextEditingController _paramDController; // New controller for param_D
  late final TextEditingController _paramEController; // New controller for param_E
  late final TextEditingController _paramFController; // New controller for param_F

  String? aco_algo_path; // New variable for ACO Algorithm path
  String? genetic_algo_path; // New variable for Genetic Algorithm path
  String? genetic_output_location; // New variable for Genetic Algorithm output location
  String? genetic_path_location; // New variable for Genetic Algorithm path location
  String? aco_output_location; // New variable for ACO Algorithm output location
  String? aco_path_location; // New variable for ACO Algorithm path location
  String? py_exec; // New variable for Python executable path

  Function()? _runScript4Executor; // New field to store the script executor

  // New helper function to execute Python scripts from HomePage
  Future<void> _runPythonScriptFromHome(String scriptPath, String executablePath) async {
    _updateInfoPanelText('Executing script: $scriptPath...');
    try {
      // 1. SANITIZATION: Remove quotes that might have been pasted in.
      String rawPath = scriptPath.trim();
      if (rawPath.startsWith('"') && rawPath.endsWith('"')) {
        rawPath = rawPath.substring(1, rawPath.length - 1);
      }
      final cleanScriptPath = rawPath.replaceAll(r'\\', r'\');

      String rawExecutablePath = executablePath.trim();
      if (rawExecutablePath.startsWith('"') && rawExecutablePath.endsWith('"')) {
        rawExecutablePath = rawExecutablePath.substring(1, rawExecutablePath.length - 1);
      }
      final cleanExecutablePath = rawExecutablePath.replaceAll(r'\\', r'\');
      
      final scriptFile = File(cleanScriptPath);

      if (!await scriptFile.exists()) {
        final errorMessage = 'ERROR: Script file not found at: $cleanScriptPath';
        _updateInfoPanelText(errorMessage);
        ref.read(errorListProvider.notifier).addError(errorMessage);
        return;
      }

      ProcessResult result;
      if (Platform.isWindows) {
        result = await Process.run(
          'cmd', 
          ['/c', cleanExecutablePath, scriptFile.path],
          runInShell: true, 
          workingDirectory: scriptFile.parent.path, 
        );
      } else {
        result = await Process.run(
          cleanExecutablePath, 
          [scriptFile.path],
          runInShell: true,
          workingDirectory: scriptFile.parent.path,
        );
      }

      final String output = 'Script executed: ${scriptFile.path}\n'
                            'Exit Code: ${result.exitCode}\n'
                            'STDOUT:\n${result.stdout}\n'
                            'STDERR:\n${result.stderr}';
      _updateInfoPanelText(output);

      if (result.exitCode != 0) {
        final errorMessage = 'Script ${scriptFile.path} finished with errors (Exit Code: ${result.exitCode}).\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}';
        _updateInfoPanelText(errorMessage);
        ref.read(errorListProvider.notifier).addError(errorMessage);
      }
    } catch (e, st) {
      final errorMessage = 'CRITICAL EXCEPTION during script execution $scriptPath: $e\n$st';
      _updateInfoPanelText(errorMessage);
      ref.read(errorListProvider.notifier).addError(errorMessage);
    }
  }





  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
    _filterController.addListener(() {
      setState(() {
        _infoPanelText = 'Filter set to: ${_filterController.text}';
      });
    });

    _nodeCountController = TextEditingController(text: '250');
    _connectionProbabilityController = TextEditingController(text: '0.40');




    _sourceNodeController = TextEditingController();
    _targetNodeController = TextEditingController();
    _bandwidthFilterController = TextEditingController(text: '500'); // Initialize with a default value
    _bandwidthSliderValue = 500.0; // Initial value for bandwidth slider
    _dropdownValueNotifier = ValueNotifier<String>(_selectedDropdownValue);

    _paramXController = TextEditingController(text: '80');
    _paramYController = TextEditingController(text: '100');
    _paramZController = TextEditingController(text: '0.3');

    _paramAController = TextEditingController(text: '30');
    _paramBController = TextEditingController(text: '50');
    _paramCController = TextEditingController(text: '1.0');
    _paramDController = TextEditingController(text: '2.0');
    _paramEController = TextEditingController(text: '0.1');
    _paramFController = TextEditingController(text: '100.0');

    final String currentPath = Directory.current.path;
    aco_algo_path = '$currentPath/scripts/algorithms/aco.py';
    genetic_algo_path = '$currentPath/scripts/algorithms/genetics.py';
    genetic_output_location = '$currentPath/scripts/data/genetic_output.csv';
    genetic_path_location = '$currentPath/scripts/data/genetic_path.csv';
    aco_output_location = '$currentPath/scripts/data/aco_output.csv';
    aco_path_location = '$currentPath/scripts/data/aco_path.csv';
    py_exec = '$currentPath/scripts/algorithms/.venv/Scripts/python.exe';
  }

  void _updateInfoPanelText(String newText) {
    setState(() {
      _infoPanelText = newText;
    });
  }

  Future<void> _exportAlgorithmParameters() async {
    // This function will have multiple intermediate calls to _updateInfoPanelText.
    // The final output of the CSV files will overwrite everything else, as per user request.

    final String currentPath = Directory.current.path;
    String content = 'parametre,deger\n';
    String fileName = '';
    String successMessage = '';
    String scriptToExecute = '';
    String algoName = '';
    String pathFileToHighlight = '';

    // Common Parameters
    content += 'kaynak,${_sourceNodeController.text}\n';
    content += 'hedef,${_targetNodeController.text}\n';
    content += 'agirlik_delay,${_sliderValue1.toStringAsFixed(2)}\n';
    content += 'agirlik_reliability,${_sliderValue2.toStringAsFixed(2)}\n';
    content += 'agirlik_cost,${_sliderValue3.toStringAsFixed(2)}\n';

    if (_selectedDropdownValue == 'Genetics Algorithm') {
      fileName = 'genetic_input.csv';
      successMessage = 'Genetic Algorithm parameters exported successfully to $fileName';
      algoName = 'Genetics';
      scriptToExecute = genetic_algo_path!;
      pathFileToHighlight = genetic_path_location!;
      content += 'populasyon,${_paramXController.text}\n';
      content += 'nesil,${_paramYController.text}\n';
      content += 'mutasyon,${_paramZController.text}\n';
    } else if (_selectedDropdownValue == 'ACO Algorithm') {
      fileName = 'aco_input.csv';
      successMessage = 'ACO Algorithm parameters exported successfully to $fileName';
      algoName = 'ACO';
      scriptToExecute = aco_algo_path!;
      pathFileToHighlight = aco_path_location!;
      content += 'karinca_sayisi,${_paramAController.text}\n';
      content += 'iterasyon,${_paramBController.text}\n';
      content += 'alfa,${_paramCController.text}\n';
      content += 'beta,${_paramDController.text}\n';
      content += 'buharlasma,${_paramEController.text}\n';
      content += 'q_degeri,${_paramFController.text}\n';
    } else {
      _updateInfoPanelText('No algorithm selected for export.');
      return;
    }

    _updateInfoPanelText('Executing $algoName algorithm...');

    try {
      File outputFile = File('$currentPath/scripts/data/$fileName');
      await outputFile.writeAsString(content);
      _updateInfoPanelText(successMessage);

      // This function internally calls _updateInfoPanelText
      if (py_exec != null && scriptToExecute.isNotEmpty) {
        await _runPythonScriptFromHome(scriptToExecute, py_exec!);
      } else {
        _updateInfoPanelText('Error: Python executable or script path not set.');
      }
    } catch (e) {
      _updateInfoPanelText('Error exporting algorithm parameters to $fileName: $e');
    }

    // --- Path Highlighting Logic (also calls _updateInfoPanelText) ---
    final String pathFilePath = pathFileToHighlight;
    _updateInfoPanelText('Attempting to highlight path from $pathFilePath...');
    try {
      final List<String> pathNodeIds = await FileRead.readPathCsv(pathFilePath);
      if (pathNodeIds.isEmpty) {
        _updateInfoPanelText('Warning: $pathFilePath is empty or contains no node IDs.');
        ref.read(graphRepositoryProvider).setPath(null);
      } else {
        final currentGraph = ref.read(graphRepositoryProvider).graph;
        if (currentGraph == null) {
          _updateInfoPanelText('Error: No graph loaded to highlight path on.');
          ref.read(graphRepositoryProvider).setPath(null);
        } else {
          final List<Node> pathNodes = [];
          for (final nodeId in pathNodeIds) {
            final node = currentGraph.nodes.firstWhereOrNull((n) => n.id == nodeId || n.id == 'node_$nodeId');
            if (node != null) {
              pathNodes.add(node);
            } else {
              _updateInfoPanelText('Warning: Node with ID $nodeId from $pathFilePath not found in current graph.');
            }
          }
          if (pathNodes.isNotEmpty) {
            ref.read(graphRepositoryProvider).setPath(pathNodes);
            _updateInfoPanelText('Path highlighted successfully with ${pathNodes.length} nodes from $pathFilePath.');
          } else {
            _updateInfoPanelText('No valid nodes from $pathFilePath were found in the current graph to highlight.');
            ref.read(graphRepositoryProvider).setPath(null);
          }
        }
      }
    } catch (e) {
      _updateInfoPanelText('Error highlighting path from $pathFilePath: $e');
      ref.read(graphRepositoryProvider).setPath(null);
    }

    // --- Final Output Display (Rewritten from scratch for robustness) ---
    _updateInfoPanelText('Algorithm script finished. Reading output files...');
    await Future.delayed(const Duration(milliseconds: 200)); // Short delay just in case.

    final resultBuffer = StringBuffer();
    final String algoLowerName = algoName.replaceAll(' Algorithm', '').toLowerCase();

    // 1. Process the Path file (*_path.csv)
    final String pathOutputFileName = '${algoLowerName}_path.csv';
    final String pathOutputFilePath = '$currentPath/scripts/data/$pathOutputFileName';
    final pathOutputFile = File(pathOutputFilePath);

    _updateInfoPanelText('Looking for path file: $pathOutputFilePath');
    await Future.delayed(const Duration(milliseconds: 100));

    if (await pathOutputFile.exists()) {
      _updateInfoPanelText('Path file found. Reading visited nodes...');
      try {
        List<String> visitedNodeIds = await FileRead.readPathCsv(pathOutputFilePath);
        if (visitedNodeIds.isNotEmpty) {
          String visitedNodesLine = visitedNodeIds.map((id) => id.replaceFirst('node_', '')).join(' -> ');
          resultBuffer.writeln('Visited Nodes: $visitedNodesLine');
          resultBuffer.writeln(); // Add a blank line for spacing
        } else {
          resultBuffer.writeln('Visited Nodes: (File was empty)');
          resultBuffer.writeln();
        }
      } catch (e) {
        _updateInfoPanelText('Error reading path file: $e');
        await Future.delayed(const Duration(milliseconds: 1000));
        resultBuffer.writeln('Visited Nodes: (Error reading file)');
        resultBuffer.writeln();
      }
    } else {
      _updateInfoPanelText('ERROR: Path file not found at $pathOutputFilePath');
      await Future.delayed(const Duration(milliseconds: 1000)); // Give user time to see error
      resultBuffer.writeln('Visited Nodes: (File not found)');
      resultBuffer.writeln();
    }

    // 2. Process the Algorithm output file (*_output.csv)
    final String algorithmOutputFileName = '${algoLowerName}_output.csv';
    final String algorithmOutputFilePath = '$currentPath/scripts/data/$algorithmOutputFileName';
    final algorithmOutputFile = File(algorithmOutputFilePath);

    _updateInfoPanelText('Looking for output file: $algorithmOutputFilePath');
    await Future.delayed(const Duration(milliseconds: 100));

    if (await algorithmOutputFile.exists()) {
      _updateInfoPanelText('Output file found. Reading content...');
      try {
        String algorithmOutputContent = await FileRead.readCsvContentAsString(algorithmOutputFilePath);
        resultBuffer.writeln('Algorithm Output ($algorithmOutputFileName):');
        resultBuffer.writeln(algorithmOutputContent);
      } catch (e) {
        _updateInfoPanelText('Error reading output file: $e');
        await Future.delayed(const Duration(milliseconds: 1000));
        resultBuffer.writeln('Algorithm Output ($algorithmOutputFileName): (Error reading file)');
      }
    } else {
      _updateInfoPanelText('ERROR: Output file not found at $algorithmOutputFilePath');
      await Future.delayed(const Duration(milliseconds: 1000));
      resultBuffer.writeln('Algorithm Output ($algorithmOutputFileName): (File not found)');
    }

    // 3. Display the final combined output
    _updateInfoPanelText(resultBuffer.toString());
  }

  Future<void> _exportDemandData() async {
    final String currentPath = Directory.current.path;
    const String fileName = 'demand.csv';
    String content = 'source,target,demand\n';

    final String sourceNodeId = _sourceNodeController.text.isNotEmpty ? _sourceNodeController.text : 'N/A';
    final String targetNodeId = _targetNodeController.text.isNotEmpty ? _targetNodeController.text : 'N/A';
    final String bandwidth = _bandwidthFilterController.text.isNotEmpty ? _bandwidthFilterController.text : '0.0';

    content += '$sourceNodeId,$targetNodeId,$bandwidth\n';

    try {
      File outputFile = File('$currentPath/scripts/data/$fileName');
      await outputFile.writeAsString(content);
      _updateInfoPanelText('Demand data exported successfully to $fileName');
    } catch (e) {
      _updateInfoPanelText('Error exporting demand data to $fileName: $e');
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    _nodeCountController.dispose();
    _connectionProbabilityController.dispose();

    _sourceNodeController.dispose();
    _targetNodeController.dispose();
    _bandwidthFilterController.dispose(); // Dispose the new controller
    _dropdownValueNotifier.dispose();
    _paramXController.dispose(); // Dispose param_X controller
    _paramYController.dispose(); // Dispose param_Y controller
    _paramZController.dispose(); // Dispose param_Z controller
    _paramAController.dispose(); // Dispose param_A controller
    _paramBController.dispose(); // Dispose param_B controller
    _paramCController.dispose(); // Dispose param_C controller
    _paramDController.dispose(); // Dispose param_D controller
    _paramEController.dispose(); // Dispose param_E controller
    _paramFController.dispose(); // Dispose param_F controller
    super.dispose();
  }

  void _handleNodeSelection(Node node) {
    setState(() {
      if (_selectionMode == SelectionMode.source) {
        _sourceNode = node;
        _sourceNodeController.text = node.id.split('_').last;
        _infoPanelText = 'Source node set to: ${node.id}';
      } else {
        _targetNode = node;
        _targetNodeController.text = node.id.split('_').last;
        _infoPanelText = 'Target node set to: ${node.id}';
      }
    });
  }

  void _generateGraph() {
    debugPrint('[_generateGraph] Function called.');
    final graphRepository = ref.read(graphRepositoryProvider);
    graphRepository.updateGenerationParameters(
      nodeCount: int.tryParse(_nodeCountController.text) ?? 50,
      connectionProbability: double.tryParse(_connectionProbabilityController.text) ?? 0.01,
      bandwidth: double.tryParse(_bandwidthFilterController.text) ?? 100.0,
      sourceNodeId: _sourceNode?.id ?? '', // Pass source node ID
      targetNodeId: _targetNode?.id ?? '', // Pass target node ID
      demandMbps: double.tryParse(_bandwidthFilterController.text) ?? 0.0, // Pass bandwidth as demand
    );
    setState(() {
      _generateGraphRequested = true; // Set flag to request graph generation
    });
    // This will trigger a rebuild of the graph display area, where the actual generateGraph call will happen.
    // No direct call to graphRepository.generateGraph() here anymore.
  }

  void _updatePhysicsParameters({
    required double stiffness,
    required double repulsion,
    required double damping,
    required double idealLength,
    required bool clockwiseFlow,
    required double barnesHutTheta,
    required RenderingMethod renderingMethod,
    required PhysicsAlgorithm physicsAlgorithm,
    required bool useQuadtree,
  }) {
    final graphRepository = ref.read(graphRepositoryProvider);
    graphRepository.updatePhysicsParameters(
      stiffness: stiffness,
      repulsion: repulsion,
      damping: damping,
      idealLength: idealLength,
      clockwiseFlow: clockwiseFlow,
      barnesHutTheta: barnesHutTheta,
      renderingMethod: renderingMethod,
      physicsAlgorithm: physicsAlgorithm,
      useQuadtree: useQuadtree,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Network Graph'),
              backgroundColor: app_theme.colorScheme.surface,
            )
          : null,
      drawer: isMobile && _selectedIndex == 0
          ? Drawer(child: _buildSidebar())
          : null,
      body: Container(
        color: app_theme.colorScheme.surface,
        child: Row(
          children: [
            _buildSideNav(),
            if (!isMobile && _selectedIndex == 0) _buildSidebar(),
            _buildPageContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    return Expanded(
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMainContent(),
          SettingsPage(
            infoPanelText: _infoPanelText,
            graphDisplayBuilder: (selectedDisplayMethod) => _buildGraphDisplay(selectedDisplayMethod),
            parameterCardBuilder: _buildParameterCard,
            onFilterChanged: (text) =>
                setState(() => _infoPanelText = 'Filter set to: $text'),
            onGenerateGraphRequested: _generateGraph,
            onColorSchemeChanged: (colorScheme) =>
                app_theme.colorSchemeNotifier.value = colorScheme,
            onUpdatePhysicsParameters: ({
              required double stiffness,
              required double repulsion,
              required double damping,
              required double idealLength,
              required bool clockwiseFlow,
              required double barnesHutTheta,
              required RenderingMethod renderingMethod,
              required PhysicsAlgorithm physicsAlgorithm,
              required bool useQuadtree,
            }) {
              _updatePhysicsParameters(
                stiffness: stiffness,
                repulsion: repulsion,
                damping: damping,
                idealLength: idealLength,
                clockwiseFlow: clockwiseFlow,
                barnesHutTheta: barnesHutTheta,
                renderingMethod: renderingMethod,
                physicsAlgorithm: physicsAlgorithm,
                useQuadtree: useQuadtree,
              );
            },
            nodeCount: int.tryParse(_nodeCountController.text) ?? 0, // Pass node count
            connectionProbability: double.tryParse(_connectionProbabilityController.text) ?? 0.0, // Pass connection probability
          ),
          DeveloperPage(
            onScriptOutputChanged: _updateInfoPanelText,
            onScript4ExecutorReady: (executor) {
              _runScript4Executor = executor;
            },
            sourceNodeId: _sourceNodeController.text.isNotEmpty ? 'node_${_sourceNodeController.text}' : '',
            targetNodeId: _targetNodeController.text.isNotEmpty ? 'node_${_targetNodeController.text}' : '',
            demandMbps: double.tryParse(_bandwidthFilterController.text) ?? 0.0,
          ),
        ],
      ),
    );
  }

  Widget _buildSideNav() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      labelType: NavigationRailLabelType.all,
      backgroundColor: app_theme.sideNavBackground,
      indicatorColor: app_theme.colorScheme.primary,
      selectedIconTheme: IconThemeData(color: app_theme.colorScheme.onPrimary),
      unselectedIconTheme: IconThemeData(color: app_theme.textPrimary),
      selectedLabelTextStyle: TextStyle(color: app_theme.colorScheme.primary),
      unselectedLabelTextStyle: TextStyle(color: app_theme.textPrimary),
      destinations: const <NavigationRailDestination>[
        NavigationRailDestination(icon: Icon(Icons.home), label: Text('Home')),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.code),
          label: Text('Developer'),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: app_theme.graphBackground,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView( // Added SingleChildScrollView here
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildParameterCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Graph Config',
                      style: TextStyle(
                          color: app_theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nodeCountController,
                    decoration: const InputDecoration(
                      labelText: 'Number of Nodes',
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _nodeCountController,
                    builder: (context, value, child) {
                      return Text(
                        'Current value: ${value.text}',
                        style: TextStyle(color: app_theme.textPrimary),
                      );
                    },
                  ),
                  const SizedBox(height: 20), // Added spacing
                  const Text('Connection Probability'),
                  Slider(
                    value: double.tryParse(_connectionProbabilityController.text) ?? 0.01,
                    min: 0.01,
                    max: 1.00,
                    divisions: 99, // From 0.01 to 1.00, with 0.01 increments
                    label: (double.tryParse(_connectionProbabilityController.text) ?? 0.01).toStringAsFixed(2),
                    onChanged: (double value) {
                      setState(() {
                        _connectionProbabilityController.text = value.toStringAsFixed(2);
                      });
                    },
                  ),
                  Text(
                    'Current value: ${(double.tryParse(_connectionProbabilityController.text) ?? 0.01).toStringAsFixed(2)}',
                    style: TextStyle(color: app_theme.textPrimary),
                  ),
                  const SizedBox(height: 20), // Added spacing
                  Center(
                    child: FilledButton.icon(
                      onPressed: _generateGraph,
                      icon: const Icon(Icons.auto_graph_rounded),
                      label: const Text('Generate Graph'),
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Separator
            _buildParameterCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'Path Selection',
                      style: TextStyle(
                          color: app_theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: FittedBox(
                      child: ToggleButtons(
                        isSelected: [
                          _selectionMode == SelectionMode.source,
                          _selectionMode == SelectionMode.target,
                        ],
                        onPressed: (index) {
                          setState(() {
                            _selectionMode = index == 0
                                ? SelectionMode.source
                                : SelectionMode.target;
                          });
                        },
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('Source'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('Target'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Click a node on the graph or enter its ID below.',
                    style: TextStyle(color: app_theme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sourceNodeController,
                    decoration: const InputDecoration(
                      labelText: 'Source Node ID',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 5',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (value) {
                      if (ref.read(graphRepositoryProvider).graph == null) return;
                      try {
                        final node = ref.read(graphRepositoryProvider).graph!.nodes.firstWhere(
                          (n) => n.id == 'node_$value',
                        );
                        setState(() {
                          _sourceNode = node;
                          _infoPanelText = 'Source node set to: ${node.id}';
                        });
                      } catch (e) {
                        setState(() {
                          _infoPanelText = 'Node with ID $value not found.';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _targetNodeController,
                    decoration: const InputDecoration(
                      labelText: 'Target Node ID',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 12',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (value) {
                      if (ref.read(graphRepositoryProvider).graph == null) return;
                      try {
                        final node = ref.read(graphRepositoryProvider).graph!.nodes.firstWhere(
                          (n) => n.id == 'node_$value',
                        );
                        setState(() {
                          _targetNode = node;
                          _infoPanelText = 'Target node set to: ${node.id}';
                        });
                      } catch (e) {
                        setState(() {
                          _infoPanelText = 'Node with ID $value not found.';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Bandwidth Filter',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Slider(
                    value: _bandwidthSliderValue.clamp(100.0, 1000.0),
                    min: 100.0,
                    max: 1000.0,
                    divisions: 900, // 1000 - 100 = 900 divisions for unit increments
                    label: _bandwidthSliderValue.round().toString(),
                    onChanged: (double newValue) {
                      setState(() {
                        _bandwidthSliderValue = newValue;
                        _bandwidthFilterController.text = newValue.round().toString();
                      });
                    },
                  ),
                  TextField(
                    controller: _bandwidthFilterController,
                    decoration: const InputDecoration(
                      labelText: 'Bandwidth (Mbps)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 100',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (value) {
                      setState(() {
                        _bandwidthSliderValue = double.tryParse(value) ?? 100.0;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildParameterCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Weights',
                      style: TextStyle(
                          color: app_theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Delay Weight: ${_sliderValue1.toStringAsFixed(2)}',
                      style: TextStyle(color: app_theme.textPrimary)),
                  Slider(
                    value: _sliderValue1,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    label: _sliderValue1.toStringAsFixed(2),
                    onChanged: (double newValue) {
                      setState(() {
                        _sliderValue1 = newValue;

                        double oldRemainingSum = _sliderValue2 + _sliderValue3;
                        double newRemainingSum = 1.0 - _sliderValue1;

                        if (oldRemainingSum == 0.0) {
                          if (newRemainingSum > 0.0) {
                            _sliderValue2 = newRemainingSum / 2;
                            _sliderValue3 = newRemainingSum / 2;
                          } else {
                            _sliderValue2 = 0.0;
                            _sliderValue3 = 0.0;
                          }
                        } else {
                          double ratio = newRemainingSum / oldRemainingSum;
                          _sliderValue2 = (_sliderValue2 * ratio).clamp(0.0, 1.0);
                          _sliderValue3 = (_sliderValue3 * ratio).clamp(0.0, 1.0);
                        }

                        double currentSum = _sliderValue1 + _sliderValue2 + _sliderValue3;
                        if (currentSum != 1.0) {
                          double adjustment = (1.0 - currentSum) / 2;
                          _sliderValue2 += adjustment;
                          _sliderValue3 += adjustment;
                        }

                        _sliderValue2 = _sliderValue2.clamp(0.0, 1.0);
                        _sliderValue3 = _sliderValue3.clamp(0.0, 1.0);

                        double finalSum = _sliderValue1 + _sliderValue2 + _sliderValue3;
                        if (finalSum != 1.0 && finalSum > 0) {
                           _sliderValue1 = (_sliderValue1 / finalSum).clamp(0.0, 1.0);
                           _sliderValue2 = (_sliderValue2 / finalSum).clamp(0.0, 1.0);
                           _sliderValue3 = (_sliderValue3 / finalSum).clamp(0.0, 1.0);
                        } else if (finalSum == 0) {
                           _sliderValue1 = 1.0/3.0;
                           _sliderValue2 = 1.0/3.0;
                           _sliderValue3 = 1.0/3.0;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('Reliability Weight: ${_sliderValue2.toStringAsFixed(2)}',
                      style: TextStyle(color: app_theme.textPrimary)),
                  Slider(
                    value: _sliderValue2,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    label: _sliderValue2.toStringAsFixed(2),
                    onChanged: (double newValue) {
                      setState(() {

                        _sliderValue2 = newValue;

                        double oldRemainingSum = _sliderValue1 + _sliderValue3;
                        double newRemainingSum = 1.0 - _sliderValue2;

                        if (oldRemainingSum == 0.0) {
                          if (newRemainingSum > 0.0) {
                            _sliderValue1 = newRemainingSum / 2;
                            _sliderValue3 = newRemainingSum / 2;
                          } else {
                            _sliderValue1 = 0.0;
                            _sliderValue3 = 0.0;
                          }
                        } else {
                          double ratio = newRemainingSum / oldRemainingSum;
                          _sliderValue1 = (_sliderValue1 * ratio).clamp(0.0, 1.0);
                          _sliderValue3 = (_sliderValue3 * ratio).clamp(0.0, 1.0);
                        }

                        double currentSum = _sliderValue1 + _sliderValue2 + _sliderValue3;
                        if (currentSum != 1.0) {
                          double adjustment = (1.0 - currentSum) / 2;
                          _sliderValue1 += adjustment;
                          _sliderValue3 += adjustment;
                        }

                        _sliderValue1 = _sliderValue1.clamp(0.0, 1.0);
                        _sliderValue3 = _sliderValue3.clamp(0.0, 1.0);

                        double finalSum = _sliderValue1 + _sliderValue2 + _sliderValue3;
                        if (finalSum != 1.0 && finalSum > 0) {
                           _sliderValue1 = (_sliderValue1 / finalSum).clamp(0.0, 1.0);
                           _sliderValue2 = (_sliderValue2 / finalSum).clamp(0.0, 1.0);
                           _sliderValue3 = (_sliderValue3 / finalSum).clamp(0.0, 1.0);
                        } else if (finalSum == 0) {
                           _sliderValue1 = 1.0/3.0;
                           _sliderValue2 = 1.0/3.0;
                           _sliderValue3 = 1.0/3.0;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('Resource Weight: ${_sliderValue3.toStringAsFixed(2)}',
                      style: TextStyle(color: app_theme.textPrimary)),
                  Slider(
                    value: _sliderValue3,
                    min: 0.0,
                    max: 1.0,
                    divisions: 100,
                    label: _sliderValue3.toStringAsFixed(2),
                    onChanged: (double newValue) {
                      setState(() {

                        _sliderValue3 = newValue;

                        double oldRemainingSum = _sliderValue1 + _sliderValue2;
                        double newRemainingSum = 1.0 - _sliderValue3;

                        if (oldRemainingSum == 0.0) {
                          if (newRemainingSum > 0.0) {
                            _sliderValue1 = newRemainingSum / 2;
                            _sliderValue2 = newRemainingSum / 2;
                          } else {
                            _sliderValue1 = 0.0;
                            _sliderValue2 = 0.0;
                          }
                        } else {
                          double ratio = newRemainingSum / oldRemainingSum;
                          _sliderValue1 = (_sliderValue1 * ratio).clamp(0.0, 1.0);
                          _sliderValue2 = (_sliderValue2 * ratio).clamp(0.0, 1.0);
                        }

                        double currentSum = _sliderValue1 + _sliderValue2 + _sliderValue3;
                        if (currentSum != 1.0) {
                          double adjustment = (1.0 - currentSum) / 2;
                          _sliderValue1 += adjustment;
                          _sliderValue2 += adjustment;
                        }

                        _sliderValue1 = _sliderValue1.clamp(0.0, 1.0);
                        _sliderValue2 = _sliderValue2.clamp(0.0, 1.0);

                        double finalSum = _sliderValue1 + _sliderValue2 + _sliderValue3;
                        if (finalSum != 1.0 && finalSum > 0) {
                           _sliderValue1 = (_sliderValue1 / finalSum).clamp(0.0, 1.0);
                           _sliderValue2 = (_sliderValue2 / finalSum).clamp(0.0, 1.0);
                           _sliderValue3 = (_sliderValue3 / finalSum).clamp(0.0, 1.0);
                        } else if (finalSum == 0) {
                           _sliderValue1 = 1.0/3.0;
                           _sliderValue2 = 1.0/3.0;
                           _sliderValue3 = 1.0/3.0;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildParameterCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Path Finding Algorithm',
                      style: TextStyle(
                          color: app_theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedDropdownValue,
                    items: <String>['Genetics Algorithm', 'ACO Algorithm']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedDropdownValue = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_selectedDropdownValue == 'Genetics Algorithm')
                    Column(
                      children: [
                        TextField(
                          controller: _paramXController,
                          decoration: const InputDecoration(
                            labelText: 'Population (int)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 80',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _paramYController,
                          decoration: const InputDecoration(
                            labelText: 'Number of Generations (int)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 100',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _paramZController,
                          decoration: const InputDecoration(
                            labelText: 'Mutation (double)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 0.3',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                          onChanged: (value) {
                            final parsedValue = double.tryParse(value);
                            if (parsedValue != null) {
                              final clampedValue = parsedValue.clamp(0.0, 1.0);
                              if (clampedValue != parsedValue) {
                                _paramZController.value = TextEditingValue(
                                  text: clampedValue.toString(),
                                  selection: TextSelection.collapsed(offset: clampedValue.toString().length),
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  if (_selectedDropdownValue == 'ACO Algorithm')
                    Column(
                      children: [
                        TextField(
                          controller: _paramAController,
                          decoration: const InputDecoration(
                            labelText: 'Number of Ants (int)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 30',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _paramBController,
                          decoration: const InputDecoration(
                            labelText: 'Iteration Count (int)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 50',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _paramCController,
                          decoration: const InputDecoration(
                            labelText: 'Alpha (double)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 1.0',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _paramDController,
                          decoration: const InputDecoration(
                            labelText: 'Beta (double)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 2.0',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _paramEController,
                          decoration: const InputDecoration(
                            labelText: 'Evaporation (double)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 0.1',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _paramFController,
                          decoration: const InputDecoration(
                            labelText: 'Q Value (double)',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., 100.0',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  Center(
                    child: FilledButton.tonal(
                      onPressed: _exportAlgorithmParameters, // Call the new method
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow),
                          SizedBox(width: 8),
                          Text('Run The Algorithm'),
                        ],
                      ),
                      style: ButtonStyle(
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
                        _buildParameterCard(
                          child: Center(
                            child: FilledButton.icon(
                              onPressed: () async {
                                _updateInfoPanelText('Loading graph from CSV files...');
                                try {
                                  // Then, run Script 4 using the callback
                                  if (_runScript4Executor != null) {
                                    await _runScript4Executor!();
                                    _updateInfoPanelText('Script 4 executed. Loading graph from CSV files...');
                                  } else {
                                    _updateInfoPanelText('Script 4 executor not ready.');
                                  }
            
                                  final String currentPath = Directory.current.path;
                                  final String nodesFilePath = '$currentPath/scripts/data/nodes.csv';
                                  final String edgesFilePath = '$currentPath/scripts/data/edges.csv';
            
                                  // Get current screen size for initial node placement
                                  final Size screenSize = MediaQuery.of(context).size;
            
                                                            await ref.read(graphRepositoryProvider).loadGraphFromCsvFiles(
                                                                  nodesFilePath,
                                                                  edgesFilePath: edgesFilePath, // Pass as named parameter
                                                                  width: screenSize.width,
                                                                  height: screenSize.height,
                                                                );
                                  // Add this debug print to check graph status after loading
                                  final loadedGraph = ref.read(graphRepositoryProvider).graph;
                                  if (loadedGraph != null) {
                                    // debugPrint('GraphRepository: Graph is NOT null after loading. Nodes: ${loadedGraph.nodes.length}, Links: ${loadedGraph.links.length}');
                                    // Print IDs of a few loaded nodes to verify format
                                    for (int i = 0; i < math.min(loadedGraph.nodes.length, 5); i++) {
                                      // debugPrint('Loaded Node ID ${i}: ${loadedGraph.nodes[i].id}');
                                    }
                                  } else {
                                    // debugPrint('GraphRepository: Graph IS null after loading.');
                                  }

                                  _updateInfoPanelText('Script 4 executed, and graph loaded successfully from nodes.csv and edges.csv.');
                                } catch (e) {
                                  _updateInfoPanelText('Error during script execution or loading graph from CSV: $e');
                                }
                              },
                              icon: const Icon(Icons.star), // Changed icon to differentiate
                              label: const Text('Load Graph from CSV'),
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  app_theme.colorScheme.tertiaryContainer, // Changed color to differentiate
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
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildParameterCard(
                          child: Center(
                            child: FilledButton.icon(
                              onPressed: () async {
                                _updateInfoPanelText('Attempting to highlight path from path.csv...');
                                try {
                                  final String currentPath = Directory.current.path;
                                  final String pathCsvFilePath = '$currentPath/scripts/data/path.csv';
            
                                  final List<String> pathNodeIds = await FileRead.readPathCsv(pathCsvFilePath);
                                  
                                  if (pathNodeIds.isEmpty) {
                                    _updateInfoPanelText('No node IDs found in path.csv or file is empty.');
                                    ref.read(graphRepositoryProvider).setPath(null); // Clear any existing path
                                    return;
                                  }
            
                                  final currentGraph = ref.read(graphRepositoryProvider).graph;
                                  if (currentGraph == null) {
                                    _updateInfoPanelText('Error: No graph loaded to highlight a path on.');
                                    return;
                                  }
            
                                  final List<Node> pathNodes = [];
                                  for (final nodeId in pathNodeIds) {
                                    final node = currentGraph.nodes.firstWhereOrNull((n) => n.id == nodeId);
                                    if (node != null) {
                                      pathNodes.add(node);
                                    } else {
                                      _updateInfoPanelText('Warning: Node with ID $nodeId from path.csv not found in current graph.');
                                    }
                                  }
            
                                  if (pathNodes.isNotEmpty) {
                                    ref.read(graphRepositoryProvider).setPath(pathNodes);
                                    _updateInfoPanelText('Path highlighted successfully with ${pathNodes.length} nodes from path.csv.');
                                  } else {
                                    _updateInfoPanelText('No valid nodes from path.csv were found in the current graph to highlight.');
                                    ref.read(graphRepositoryProvider).setPath(null); // Clear any existing path
                                  }
            
                                } catch (e) {
                                  _updateInfoPanelText('Error highlighting path from path.csv: $e');
                                  ref.read(graphRepositoryProvider).setPath(null); // Ensure path is cleared on error
                                }
                              },
                              icon: const Icon(Icons.route), // Changed icon to differentiate
                              label: const Text('Highlight Path from CSV'),
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  app_theme.colorScheme.tertiaryContainer, // Changed color to differentiate
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
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildParameterCard(
                          child: Center(
                            child: FilledButton.tonal(
                              onPressed: _exportDemandData, // Call the new method
                              child: const Text('Export Demand Data'),
                              style: ButtonStyle(
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
                          ),
                        ),
                        const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // This method was previously removed but is required by SettingsPage
  // and potentially other parts of HomePage.
  Widget _buildParameterCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: app_theme.cardBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }



  // Centralized graph generation and display logic
  Widget _buildGraphDisplay(RenderingMethod selectedRenderingMethod) {
    final graphRepository = ref.watch(graphRepositoryProvider); // Watch for changes
    final graph = graphRepository.graph;

    return LayoutBuilder(builder: (context, constraints) {
            if (_generateGraphRequested) {
              // We defer graph generation until we have actual layout constraints.
              // This ensures the FlatQuadTree is initialized with correct dimensions.
              Future.microtask(() async {
                if (mounted) { // Ensure widget is still in the tree before calling async code
                  await ref.read(graphRepositoryProvider).generateGraph(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  );
                  // Re-check mounted after the async gap before calling setState
                  if (mounted) {
                    setState(() {
                      _generateGraphRequested = false; // Reset the flag after generation
                    });
                  }
                }
              });
              // Show a loading indicator or placeholder while graph is being generated
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(app_theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      graph == null ? 'Generating initial graph...' : 'Re-generating graph...',
                      style: TextStyle(color: app_theme.textPrimary),
                    ),
                  ],
                ),
              );
            } else if (graph == null) { // If no graph and not requested, show prompt
              return Center(
                  child: Text(
                      'Press "Generate Graph" to create a graph.',
                      style: TextStyle(color: app_theme.textPrimary),
                  ),
              );
            }
      // If graph is not null and no new generation is requested, display the graph
      return GraphWidget(
        graph: graph,
        physicsAlgorithm: graphRepository.physicsAlgorithm,
        renderingMethod: selectedRenderingMethod,
        sourceNode: _sourceNode,
        targetNode: _targetNode,
        onNodeSelected: _handleNodeSelection,
        path: graphRepository.path,
      );
    });
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Top: Topology Area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: app_theme.graphBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _buildGraphDisplay(ref.watch(graphRepositoryProvider).renderingMethod),
            ),
          ),
          const SizedBox(height: 16),
          // Bottom: Info Panel
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: app_theme.infoPanelBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _infoPanelText,
              style: TextStyle(color: app_theme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}


