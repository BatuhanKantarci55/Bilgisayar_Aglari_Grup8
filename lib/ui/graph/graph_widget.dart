import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_application_1/logic/isolate_messages.dart';
import 'package:flutter_application_1/logic/physics_algorithm.dart';
import 'package:flutter_application_1/logic/rendering_method.dart';
import 'package:flutter_application_1/logic/graph_network.dart';
import 'package:flutter_application_1/logic/graph_repository.dart';
import 'package:flutter_application_1/ui/common/theme.dart' as app_theme;

class GraphWidget extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  final GraphNetwork graph; // Changed type
  final PhysicsAlgorithm physicsAlgorithm;
  final RenderingMethod renderingMethod;
  final Node? sourceNode;
  final Node? targetNode;
  final ValueChanged<Node>? onNodeSelected;
  final List<Node>? path;

  const GraphWidget({
    super.key,
    required this.graph,
    required this.physicsAlgorithm,
    required this.renderingMethod,
    this.sourceNode,
    this.targetNode,
    this.onNodeSelected,
    this.path,
  });

  @override
  ConsumerState<GraphWidget> createState() => GraphWidgetState(); // Changed type
}

class GraphWidgetState extends ConsumerState<GraphWidget>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController; // Re-added, now initialized from repo
  late final FocusNode _focusNode; // Added FocusNode

  Float64List _nodePositions = Float64List(0); // Holds the latest positions from the isolate
  List<List<int>> _links = []; // Holds the link structure
  List<Node> _graphNodes = []; // Holds the latest graph nodes for consistent data
  Node? _draggedNode; // Not yet implemented with isolate messaging
  bool _allowPan = true;
  bool _hasInitializedView = false;
  double _width = 0;
  double _height = 0;

  ui.FragmentProgram? _linkFragmentProgram;
  ui.FragmentShader? _linkShader;

  GraphRepository? _graphRepository;

  @override
  void initState() {
    super.initState();
    _graphRepository = ref.read(graphRepositoryProvider); // Access the repository first
    _transformationController = _graphRepository!.transformationController; // Get the controller
    _focusNode = FocusNode();

    _loadShaders(); // New method to load shaders

    // Listen to changes from GraphRepository
    _graphRepository = ref.read(graphRepositoryProvider);
    _graphRepository!.addListener(_updateGraphState);
  }

  Future<void> _loadShaders() async {
    try {
      _linkFragmentProgram = await ui.FragmentProgram.fromAsset('shaders/link_shader.frag');
      _linkShader = _linkFragmentProgram!.fragmentShader();
      // Trigger a rebuild once the shader is loaded
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Handle shader loading errors gracefully
      // debugPrint('Error loading shader: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initial update based on current state of GraphRepository
    _updateGraphState();
  }

  void _updateGraphState() {
    final graphRepo = ref.read(graphRepositoryProvider);
    final currentGraph = graphRepo.graph;

    if (currentGraph != null) {
      setState(() {
        _nodePositions = currentGraph.toPositionsFloat64List();
        _links = currentGraph.toLinksList();
        _graphNodes = currentGraph.nodes; // Update _graphNodes here
        if (!_hasInitializedView && currentGraph.nodes.isNotEmpty) {
          _fitGraphToView();
          _hasInitializedView = true;
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant GraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If graph instance changes, re-subscribe or re-initialize
    if (widget.graph != oldWidget.graph) {
      _hasInitializedView = false;
    }
  }

  @override
  void dispose() {
    _graphRepository?.removeListener(_updateGraphState);
    _focusNode.dispose();
    // FragmentProgram and FragmentShader are automatically managed when no longer referenced.
    // Explicit dispose is not generally needed for them if they are part of a widget's lifecycle.
    _linkFragmentProgram = null;
    _linkShader = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the graphRepositoryProvider for changes
    final graphRepo = ref.watch(graphRepositoryProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_width != constraints.maxWidth || _height != constraints.maxHeight) {
          _width = constraints.maxWidth;
          _height = constraints.maxHeight; // Corrected from constraints.height
          // Notify the repository about dimension changes
          graphRepo.updateDimensions(_width, _height);
        }

        return KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (KeyEvent event) {
            // Optional: Log keyboard events for debugging
            // print('KeyboardListener: ${event.runtimeType} - ${event.logicalKey.debugName}');
            if (event is KeyDownEvent) {
              // Consume the event to prevent it from propagating further
              // if it's causing issues.
              // For now, we just consume it. More sophisticated handling can be added later.
            }
          },
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: _transformationController,
                panEnabled: _allowPan,
                scaleEnabled: _allowPan,
                minScale: 0.01,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: GestureDetector(
                  onTapUp: (details) {
                    if (_draggedNode != null) return;
                    final node = _findNodeAt(details.localPosition, graphRepo.graph);
                    if (node != null) {
                        widget.onNodeSelected?.call(node);
                    }
                  },
                  onPanStart: (details) {
                    final node = _findNodeAt(details.localPosition, graphRepo.graph);
                    if (node != null) {
                      _draggedNode = node;
                      _allowPan = false;
                      setState(() {});
                    }
                  },
                  onPanUpdate: (details) {
                    if (_draggedNode != null) {
                      _draggedNode!.position = CustomPoint(
                        _draggedNode!.position.x + details.delta.dx,
                        _draggedNode!.position.y + details.delta.dy,
                      );
                      // Send update to physics isolate
                      final graphRepo = ref.read(graphRepositoryProvider);
                      final nodeIndex = graphRepo.graph!.nodes.indexOf(_draggedNode!);
                      if (nodeIndex != -1) {
                        graphRepo.sendCommand(UpdateNodePositionCommand(
                          nodeIndex: nodeIndex,
                          newX: _draggedNode!.position.x,
                          newY: _draggedNode!.position.y,
                        ));
                      }
                    }
                  },
                  onPanEnd: (details) {
                    if (_draggedNode != null) {
                      _draggedNode = null;
                      _allowPan = true;
                      setState(() {});
                    }
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: GraphPainter(
                        nodePositions: _nodePositions,
                        links: _links,
                        graphNodes: _graphNodes, // Pass the synchronized _graphNodes
                        renderingMethod: widget.renderingMethod,
                        draggedNode: _draggedNode,
                        sourceNode: widget.sourceNode,
                        targetNode: widget.targetNode,
                        path: widget.path,
                        colorScheme: app_theme.colorScheme,
                        transformationController: _transformationController,
                        linkShader: _linkShader, // Pass the shader here
                      ),
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  color: app_theme.textPrimary,
                  tooltip: 'Center View',
                  onPressed: _fitGraphToView,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _fitGraphToView() {
    if (_nodePositions.isEmpty || _width == 0 || _height == 0) return;

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (int i = 0; i < _nodePositions.length; i += 2) {
      minX = min(minX, _nodePositions[i]);
      minY = min(minY, _nodePositions[i + 1]);
      maxX = max(maxX, _nodePositions[i]);
      maxY = max(maxY, _nodePositions[i + 1]);
    }

    final graphWidth = maxX - minX;
    final graphHeight = maxY - minY;

    if (graphWidth == 0 || graphHeight == 0) return;

    final targetScale =
        min(_width / graphWidth, _height / graphHeight) * 0.9;
    final graphCenterX = (minX + maxX) / 2;
    final graphCenterY = (minY + maxY) / 2;
    final widgetCenterX = _width / 2;
    final widgetCenterY = _height / 2;

    final translateX = widgetCenterX - (graphCenterX * targetScale);
    final translateY = widgetCenterY - (graphCenterY * targetScale);

    _transformationController.value = Matrix4.compose(
      Vector3(translateX, translateY, 0),
      Quaternion.identity(),
      Vector3(targetScale, targetScale, 1),
    );
  }

  Node? _findNodeAt(Offset position, GraphNetwork? graph) {
    if (graph == null || graph.nodes.isEmpty || _nodePositions.isEmpty) return null;
    final touchRadius =
        15.0 / _transformationController.value.getMaxScaleOnAxis();

    Node? closestNode;
    double minDistanceSq = double.infinity;

    for (int i = 0; i < _nodePositions.length; i += 2) {
      final nodePosition = Offset(_nodePositions[i], _nodePositions[i + 1]);
      final distanceSq = (position - nodePosition).distanceSquared;
      if (distanceSq < minDistanceSq) {
        minDistanceSq = distanceSq;
        closestNode = graph.nodes[i ~/ 2]; // Map back to original node object
      }
    }

    if (minDistanceSq < touchRadius * touchRadius) {
      return closestNode;
    }
    return null;
  }
}

class GraphPainter extends CustomPainter {
  final Float64List nodePositions; // Raw positions from logic
  final List<List<int>> links; // Raw links (indices)
  final List<Node> graphNodes; // Original nodes for properties
  final RenderingMethod renderingMethod;
  final Node? draggedNode;
  final Node? sourceNode;
  final Node? targetNode;
  final List<Node>? path;
  final ColorScheme colorScheme;
  final TransformationController transformationController;
  final ui.FragmentShader? linkShader; // New parameter for the shader

  final Paint _shadowPaint;
  final Paint _borderPaint;
  final Paint _simpleLinkPaint;
  final Paint _nodePaint = Paint();
  final Paint _linkPaint = Paint();
  final Paint _batchedNodePaint;
  final Paint _batchedLinkPaint;

  // OPTIMIZED BUFFERS
  late final Float32List _linePositions;
  late final Float32List _float32NodePositions;

  GraphPainter({
    required this.nodePositions,
    required this.links,
    required this.graphNodes,
    required this.renderingMethod,
    this.draggedNode,
    this.sourceNode,
    this.targetNode,
    this.path,
    required this.colorScheme,
    required this.transformationController,
    this.linkShader, // Initialize the new parameter
  })  : _shadowPaint = Paint()
          ..color = const Color.fromARGB(38, 0, 0, 0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        _borderPaint = Paint()
          ..color = colorScheme.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
        _simpleLinkPaint = Paint()
          ..color = colorScheme.outlineVariant
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
        _batchedNodePaint = Paint()
          ..color = colorScheme.primary
          ..strokeWidth = 5.0 // Controls visual size of points in batch mode
          ..strokeCap = StrokeCap.round,
        _batchedLinkPaint = Paint()
          ..color = colorScheme.outlineVariant
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round {

    _precomputeGeometry();
  }

  void _precomputeGeometry() {
    // 1. Convert Nodes to Float32 for rendering compatibility
    _float32NodePositions = Float32List.fromList(nodePositions);


    // Assert that the number of coordinates matches the number of nodes.
    // Each node has an x and y coordinate, so positions list should be twice the node count.
    assert(_float32NodePositions.length == graphNodes.length * 2,
        'Mismatch between node positions list length and graphNodes count.');

    // 2. Expand Links into a flat coordinate list (x1, y1, x2, y2, ...)
    // drawRawPoints with PointMode.lines requires pairs of points.
    // We cannot use indices directly with drawRawPoints.
    final int totalPoints = links.length * 4; // 2 points per link * 2 coords per point
    _linePositions = Float32List(totalPoints);

    int bufferIndex = 0;
    for (final link in links) {
      final int idxA = link[0];
      final int idxB = link[1];

      // Safe access check
      if (idxA * 2 + 1 < nodePositions.length && idxB * 2 + 1 < nodePositions.length) {
        // Point A
        _linePositions[bufferIndex++] = nodePositions[idxA * 2];
        _linePositions[bufferIndex++] = nodePositions[idxA * 2 + 1];
        // Point B
        _linePositions[bufferIndex++] = nodePositions[idxB * 2];
        _linePositions[bufferIndex++] = nodePositions[idxB * 2 + 1];
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (renderingMethod == RenderingMethod.batched) {
      _paintBatched(canvas, size);
    } else {
      _paintDetailed(canvas, size);
    }
  }

  void _paintDetailed(Canvas canvas, Size size) {
    if (nodePositions.isEmpty) return;

    final double scale = transformationController.value.getMaxScaleOnAxis();
    final bool isZoomedIn = scale > 0.5;
    final bool useGradients = scale > 0.3;

    final Set<Node> pathNodes = path?.toSet() ?? {};
    final Paint pathLinkPaint = Paint()
      ..color = app_theme.pathColor // Use a distinct color for the path
      ..strokeWidth = 3.0 // Make path links thicker
      ..strokeCap = StrokeCap.round;

    _linkPaint.strokeCap = StrokeCap.round;

    // Draw links
    for (final linkIndices in links) {
      final node1 = graphNodes[linkIndices[0]];
      final node2 = graphNodes[linkIndices[1]];
      final p1 = Offset(nodePositions[linkIndices[0] * 2], nodePositions[linkIndices[0] * 2 + 1]);
      final p2 = Offset(nodePositions[linkIndices[1] * 2], nodePositions[linkIndices[1] * 2 + 1]);

      final bool isPathLink = pathNodes.contains(node1) && pathNodes.contains(node2);

      if (isPathLink) {
        canvas.drawLine(p1, p2, pathLinkPaint); // Draw with highlight paint
      } else if (useGradients) {
        _linkPaint
          ..shader = ui.Gradient.linear(
              p1, p2, [colorScheme.outlineVariant, colorScheme.primary])
          ..strokeWidth = 2.0;
        canvas.drawLine(p1, p2, _linkPaint);
      } else {
        canvas.drawLine(p1, p2, _simpleLinkPaint);
      }
    }

    // Draw nodes
    for (int i = 0; i < nodePositions.length; i += 2) {
      final node = graphNodes[i ~/ 2];
      final center = Offset(nodePositions[i], nodePositions[i + 1]);
      const radius = 8.0;

      if (isZoomedIn) {
        canvas.drawCircle(center + const Offset(0, 2), radius, _shadowPaint);
      }

      if (pathNodes.contains(node)) {
        _nodePaint.color = app_theme.pathColor; // Highlight path nodes
        canvas.drawCircle(center, radius, _nodePaint);
        canvas.drawCircle(center, radius, _borderPaint);
      } else {
        _nodePaint.color = _getNodeColor(node); // Get regular node color
        canvas.drawCircle(center, radius, _nodePaint);
        canvas.drawCircle(center, radius, _borderPaint);
      }
    }
  }

  void _paintBatched(Canvas canvas, Size size) {

    if (nodePositions.isEmpty) return;

    final Set<Node> pathNodes = path?.toSet() ?? {};
    int? sourceNodeIdx;
    int? targetNodeIdx;

    if (sourceNode != null) {
      sourceNodeIdx = graphNodes.indexWhere((node) => node.id == sourceNode!.id);
    }
    if (targetNode != null) {
      targetNodeIdx = graphNodes.indexWhere((node) => node.id == targetNode!.id);
    }


    // Adjust strokeWidth inversely to scale, within reasonable bounds
    _batchedLinkPaint.strokeWidth = 1.0; // Thinner when zoomed out, thicker when zoomed in

    // --- Draw Links (Batch) ---
    if (_linePositions.isNotEmpty) {
      if (linkShader != null) {
        linkShader!
          ..setFloat(0, (colorScheme.outlineVariant.r * 255.0).round().clamp(0, 255).toDouble() / 255.0)
          ..setFloat(1, (colorScheme.outlineVariant.g * 255.0).round().clamp(0, 255).toDouble() / 255.0)
          ..setFloat(2, (colorScheme.outlineVariant.b * 255.0).round().clamp(0, 255).toDouble() / 255.0)
          ..setFloat(3, (colorScheme.outlineVariant.a * 255.0).round().clamp(0, 255).toDouble() / 255.0);
        _batchedLinkPaint.shader = linkShader;
      } else {
        _batchedLinkPaint.shader = null;
      }
      canvas.drawRawPoints(ui.PointMode.lines, _linePositions, _batchedLinkPaint);
    }

    // --- Draw Regular Nodes (Batch) ---
    final List<double> regularPoints = [];
    for (int i = 0; i < graphNodes.length; i++) {
      if (i != sourceNodeIdx && i != targetNodeIdx && !pathNodes.contains(graphNodes[i])) {
        regularPoints.add(_float32NodePositions[i * 2]);
        regularPoints.add(_float32NodePositions[i * 2 + 1]);
      }
    }
    
    if (regularPoints.isNotEmpty) {
      final Float32List regularPointsFloat32 = Float32List.fromList(regularPoints);
      // PointMode.points draws a point at each coordinate pair
      canvas.drawRawPoints(ui.PointMode.points, regularPointsFloat32, _batchedNodePaint);
    }

    if (path != null && path!.length > 1) {
      final Paint pathLinkPaint = Paint() // Re-declare or reuse if scope allows
        ..color = app_theme.pathColor
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < path!.length - 1; i++) {
        final Node startPathNode = path![i];
        final Node endPathNode = path![i + 1];

        final startIndex = graphNodes.indexWhere((node) => node.id == startPathNode.id);
        final endIndex = graphNodes.indexWhere((node) => node.id == endPathNode.id);


        if (startIndex != -1 && endIndex != -1) {
          final Offset p1 = Offset(_float32NodePositions[startIndex * 2], _float32NodePositions[startIndex * 2 + 1]);
          final Offset p2 = Offset(_float32NodePositions[endIndex * 2], _float32NodePositions[endIndex * 2 + 1]);
          canvas.drawLine(p1, p2, pathLinkPaint); // Draw individual highlighted path links
        }
      }
    }

    // --- Draw Source and Target Nodes (Detailed Overlay) ---
    const double radius = 8.0;
    _nodePaint.style = PaintingStyle.fill;
    _borderPaint.style = PaintingStyle.stroke;

    if (sourceNodeIdx != null && sourceNodeIdx >= 0 && (sourceNodeIdx * 2 + 1) < _float32NodePositions.length) {
      final center = Offset(_float32NodePositions[sourceNodeIdx * 2], _float32NodePositions[sourceNodeIdx * 2 + 1]);
      _nodePaint.color = _getNodeColor(sourceNode!);
      canvas.drawCircle(center, radius, _nodePaint);
      canvas.drawCircle(center, radius, _borderPaint);
    }

    if (targetNodeIdx != null && targetNodeIdx >= 0 && (targetNodeIdx * 2 + 1) < _float32NodePositions.length) {
      final center = Offset(_float32NodePositions[targetNodeIdx * 2], _float32NodePositions[targetNodeIdx * 2 + 1]);
      _nodePaint.color = _getNodeColor(targetNode!);
      canvas.drawCircle(center, radius, _nodePaint);
      canvas.drawCircle(center, radius, _borderPaint);
    }

    if (path != null) {
      final Paint pathNodePaint = Paint()
        ..color = app_theme.pathColor
        ..style = PaintingStyle.fill;

      for (final Node pathNode in path!) {
        // Skip source and target as they are drawn above
        if (pathNode == sourceNode || pathNode == targetNode) continue;

        final nodeIndex = graphNodes.indexWhere((node) => node.id == pathNode.id);

        if (nodeIndex != -1) {
          final Offset center = Offset(_float32NodePositions[nodeIndex * 2], _float32NodePositions[nodeIndex * 2 + 1]);
          canvas.drawCircle(center, radius, pathNodePaint); // Draw individual highlighted path nodes
          canvas.drawCircle(center, radius, _borderPaint);
        }
      }
    }
  }

  Color _getNodeColor(Node node) {
    if (path != null && path!.contains(node)) return app_theme.pathColor;
    if (node == draggedNode) return colorScheme.secondary;
    if (node == sourceNode) return app_theme.sourceNodeColor;
    if (node == targetNode) return app_theme.targetNodeColor;
    return colorScheme.surfaceContainerHighest;
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.nodePositions != nodePositions ||
        oldDelegate.links != links ||
        oldDelegate.draggedNode != draggedNode ||
        oldDelegate.sourceNode != sourceNode ||
        oldDelegate.targetNode != targetNode ||
        oldDelegate.path != path ||
        oldDelegate.renderingMethod != renderingMethod ||
        oldDelegate.colorScheme != colorScheme;
  }
}