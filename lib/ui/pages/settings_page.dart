import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/common/theme.dart' as app_theme;
import 'package:flutter_application_1/logic/rendering_method.dart';
import 'package:flutter_application_1/logic/physics_algorithm.dart';


import 'package:flutter_application_1/ui/common/color_picker_content.dart' as color_picker_content;

/// A typedef for a function that builds the graph display widget.
/// This allows the parent (HomePage) to control graph generation and pass the display logic.
typedef GraphDisplayBuilder = Widget Function(RenderingMethod selectedRenderingMethod);

/// A typedef for a function that builds a parameter card.
/// This allows the parent (HomePage) to provide a consistent card style.
typedef ParameterCardBuilder = Widget Function({required Widget child});

/// Callback for generating a graph with specified parameters.
typedef GenerateGraphCallback = VoidCallback;

/// Callback for updating physics parameters.
typedef UpdatePhysicsParametersCallback = void Function({
  required double stiffness,
  required double repulsion,
  required double damping,
  required double idealLength,
  required bool clockwiseFlow,
  required double barnesHutTheta,
  required RenderingMethod renderingMethod,
  required PhysicsAlgorithm physicsAlgorithm,
  required bool useQuadtree,
});

class SettingsPage extends ConsumerStatefulWidget {
  final String infoPanelText;
  final GraphDisplayBuilder graphDisplayBuilder;
  final ParameterCardBuilder parameterCardBuilder;

  // Callbacks to update parent state
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<ColorScheme> onColorSchemeChanged;
  final GenerateGraphCallback onGenerateGraphRequested;
  final UpdatePhysicsParametersCallback onUpdatePhysicsParameters;

  const SettingsPage({
    super.key,
    required this.infoPanelText,
    required this.graphDisplayBuilder,
    required this.parameterCardBuilder,
    required this.onFilterChanged,
    required this.onGenerateGraphRequested,
    required this.onColorSchemeChanged,
    required this.onUpdatePhysicsParameters,
    required this.nodeCount,
    required this.connectionProbability,
  });

  final int nodeCount;
  final double connectionProbability;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _filterController;

  late final TextEditingController _stiffnessController;
  late final TextEditingController _repulsionController;
  late final TextEditingController _dampingController;
  late final TextEditingController _idealLengthController;
  late final TextEditingController _barnesHutThetaController;

  bool _clockwiseFlow = false;
  bool _useQuadtree = false;

  RenderingMethod _selectedRenderingMethod = RenderingMethod.batched;
  PhysicsAlgorithm _selectedPhysicsAlgorithm = PhysicsAlgorithm.BarnesHut;

  double _totalLinks = 0.0; // New variable

  @override
  void initState() {
    super.initState();

    _filterController = TextEditingController();
    _filterController.addListener(() {
      widget.onFilterChanged(_filterController.text);
    });

    _stiffnessController = TextEditingController(text: '0.005');
    _repulsionController = TextEditingController(text: '2000.0');
    _dampingController = TextEditingController(text: '0.8');
    _idealLengthController = TextEditingController(text: '200.0');
    _barnesHutThetaController = TextEditingController(text: '0.5');

    _clockwiseFlow = false;
    _useQuadtree = false;

    _selectedRenderingMethod = RenderingMethod.batched;
    _selectedPhysicsAlgorithm = PhysicsAlgorithm.BarnesHut;

    _calculateTotalLinks(); // Initial calculation
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeCount != widget.nodeCount ||
        oldWidget.connectionProbability != widget.connectionProbability) {
      _calculateTotalLinks(); // Recalculate if nodeCount or connectionProbability changes
    }
  }

  void _calculateTotalLinks() {
    setState(() {
      _totalLinks = widget.nodeCount * widget.connectionProbability * 0.5;
    });
  }

  @override
  void dispose() {
    _filterController.dispose();

    _stiffnessController.dispose();
    _repulsionController.dispose();
    _dampingController.dispose();
    _idealLengthController.dispose();
    _barnesHutThetaController.dispose();
    super.dispose();
  }



  void _updatePhysicsParameters() {
    widget.onUpdatePhysicsParameters(
      stiffness: double.tryParse(_stiffnessController.text) ?? 0.005,
      repulsion: double.tryParse(_repulsionController.text) ?? 2000.0,
      damping: double.tryParse(_dampingController.text) ?? 0.8,
      idealLength: double.tryParse(_idealLengthController.text) ?? 200.0,
      clockwiseFlow: _clockwiseFlow,
      barnesHutTheta: double.tryParse(_barnesHutThetaController.text) ?? 0.5,
      renderingMethod: _selectedRenderingMethod,
      physicsAlgorithm: _selectedPhysicsAlgorithm,
      useQuadtree: _useQuadtree,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [_buildSettingsSidebar(), _buildSettingsMainContent()],
    );
  }

  Widget _buildSettingsSidebar() {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: app_theme.graphBackground,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.parameterCardBuilder(
              child: Text(
                'Controls',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: app_theme.textPrimary,
                  fontWeight: FontWeight.w800, // Expressive bold
                ),
              ),
            ),
            const SizedBox(height: 20),
            widget.parameterCardBuilder(
              child: Text(
                'Total Links (Estimated): ${_totalLinks.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: app_theme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: Center(
                child: SegmentedButton<RenderingMethod>(
                  segments: const [
                    ButtonSegment(value: RenderingMethod.detailed, label: Text('Detailed')),
                    ButtonSegment(value: RenderingMethod.batched, label: Text('Batched')),
                  ],
                  selected: {_selectedRenderingMethod},
                  onSelectionChanged: (Set<RenderingMethod> newSelection) {
                    setState(() {
                      _selectedRenderingMethod = newSelection.first;
                    });
                    _updatePhysicsParameters();
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: Center(
                child: SegmentedButton<PhysicsAlgorithm>(
                  segments: const [
                    ButtonSegment(value: PhysicsAlgorithm.ForceDirected, label: Text('Force Directed')),
                    ButtonSegment(value: PhysicsAlgorithm.BarnesHut, label: Text('Barnes-Hut')),
                  ],
                  selected: {_selectedPhysicsAlgorithm},
                  onSelectionChanged: (Set<PhysicsAlgorithm> newSelection) {
                    setState(() {
                      _selectedPhysicsAlgorithm = newSelection.first;
                      if (_selectedPhysicsAlgorithm != PhysicsAlgorithm.BarnesHut) {
                        _useQuadtree = false;
                      }
                    });
                    _updatePhysicsParameters();
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final Color? newColor = await showModalBottomSheet<Color>(
                      context: context,
                      isScrollControlled: true, // Allows content to determine height
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(28.0)),
                      ),
                      builder: (BuildContext context) {
                        return color_picker_content.ColorPickerContent();
                      },
                    );
                    if (newColor != null) {
                      final newColorScheme = ColorScheme.fromSeed(
                        seedColor: newColor,
                        brightness: Brightness.light,
                        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
                      );
                      widget.onColorSchemeChanged(newColorScheme);
                      widget.onGenerateGraphRequested();
                    }
                  },
                  child: const Text('Change Color Palette'),
                ),
              ),
            ),


            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: SwitchListTile(
                title: Text('Clockwise Flow',
                    style: TextStyle(color: app_theme.textPrimary)),
                value: _clockwiseFlow,
                onChanged: (value) {
                  setState(() {
                    _clockwiseFlow = value;
                  });
                  _updatePhysicsParameters();
                },
              ),
            ),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: SwitchListTile(
                title: Text('Use Quadtree Optimization',
                    style: TextStyle(color: app_theme.textPrimary)),
                value: _useQuadtree,
                onChanged: (_selectedPhysicsAlgorithm == PhysicsAlgorithm.BarnesHut)
                    ? (value) {
                        setState(() {
                          _useQuadtree = value;
                        });
                        _updatePhysicsParameters();
                      }
                    : null, // Disable if not BarnesHut
              ),
            ),
            // Removed old DisplayMethod DropdownButton
            if (_selectedPhysicsAlgorithm == PhysicsAlgorithm.BarnesHut) ...[
              const SizedBox(height: 10),
              widget.parameterCardBuilder(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Barnes-Hut Theta: ${(double.tryParse(_barnesHutThetaController.text) ?? 0.5).toStringAsFixed(2)}',
                        style: TextStyle(color: app_theme.textPrimary)),
                    Slider(
                      value: double.tryParse(_barnesHutThetaController.text) ?? 0.5,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      onChanged: (value) {
                        setState(() {
                           _barnesHutThetaController.text = value.toStringAsFixed(2);
                        });
                        _updatePhysicsParameters();
                      },
                    ),
                  ],
                ),
              ),
            ],




            const SizedBox(height: 10),
             widget.parameterCardBuilder(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stiffness'),
                  Slider(
                    value: double.tryParse(_stiffnessController.text) ?? 0.005,
                    min: 0.001,
                    max: 0.02,
                    divisions: 19,
                    label: (double.tryParse(_stiffnessController.text) ?? 0.005).toStringAsFixed(3),
                    onChanged: (double value) {
                      setState(() {
                        _stiffnessController.text = value.toStringAsFixed(3);
                      });
                    },
                    onChangeEnd: (value) {
                      _updatePhysicsParameters();
                    },
                  ),
                  Text(
                    'Current value: ${(double.tryParse(_stiffnessController.text) ?? 0.005).toStringAsFixed(3)}',
                    style: TextStyle(color: app_theme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Repulsion'),
                  Slider(
                    value: double.tryParse(_repulsionController.text) ?? 2000.0,
                    min: 100.0,
                    max: 10000.0,
                    divisions: 99,
                    label: (double.tryParse(_repulsionController.text) ?? 2000.0).toStringAsFixed(0),
                    onChanged: (double value) {
                      setState(() {
                        _repulsionController.text = value.toStringAsFixed(0);
                      });
                    },
                    onChangeEnd: (value) {
                      _updatePhysicsParameters();
                    },
                  ),
                  Text(
                    'Current value: ${(double.tryParse(_repulsionController.text) ?? 2000.0).toStringAsFixed(0)}',
                    style: TextStyle(color: app_theme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Damping'),
                  Slider(
                    value: double.tryParse(_dampingController.text) ?? 0.8,
                    min: 0.1,
                    max: 0.99,
                    divisions: 89,
                    label: (double.tryParse(_dampingController.text) ?? 0.8).toStringAsFixed(2),
                    onChanged: (double value) {
                      setState(() {
                        _dampingController.text = value.toStringAsFixed(2);
                      });
                    },
                    onChangeEnd: (value) {
                      _updatePhysicsParameters();
                    },
                  ),
                  Text(
                    'Current value: ${(double.tryParse(_dampingController.text) ?? 0.8).toStringAsFixed(2)}',
                    style: TextStyle(color: app_theme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ideal Length'),
                  Slider(
                    value: double.tryParse(_idealLengthController.text) ?? 200.0,
                    min: 10.0,
                    max: 500.0,
                    divisions: 49,
                    label: (double.tryParse(_idealLengthController.text) ?? 200.0).toStringAsFixed(0),
                    onChanged: (double value) {
                      setState(() {
                        _idealLengthController.text = value.toStringAsFixed(0);
                      });
                    },
                    onChangeEnd: (value) {
                      _updatePhysicsParameters();
                    },
                  ),
                  Text(
                    'Current value: ${(double.tryParse(_idealLengthController.text) ?? 200.0).toStringAsFixed(0)}',
                    style: TextStyle(color: app_theme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Barnes-Hut Theta'),
                  Slider(
                    value: double.tryParse(_barnesHutThetaController.text) ?? 0.5,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: (double.tryParse(_barnesHutThetaController.text) ?? 0.5).toStringAsFixed(1),
                    onChanged: (double value) {
                      setState(() {
                        _barnesHutThetaController.text = value.toStringAsFixed(1);
                      });
                    },
                    onChangeEnd: (value) {
                      _updatePhysicsParameters();
                    },
                  ),
                  Text(
                    'Current value: ${(double.tryParse(_barnesHutThetaController.text) ?? 0.5).toStringAsFixed(1)}',
                    style: TextStyle(color: app_theme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            widget.parameterCardBuilder(
              child: Row(
                children: [
                  const Text('Clockwise Flow'),
                  const Spacer(),
                  Switch(
                    value: _clockwiseFlow,
                    onChanged: (value) {
                      setState(() {
                        _clockwiseFlow = value;
                        // These will be refactored in the next step
                      });
                    },
                  ),
                ],
              ),
            ),


          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMainContent() {
    return Expanded(
      child: Padding(
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
                child: widget.graphDisplayBuilder(_selectedRenderingMethod),
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
                widget.infoPanelText,
                style: TextStyle(color: app_theme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}