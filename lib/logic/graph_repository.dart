import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math; // Add this import

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // Added for TransformationController
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/logic/graph_network.dart';
import 'package:flutter_application_1/logic/rendering_method.dart';
import 'package:flutter_application_1/logic/physics_isolate_manager.dart'; // New import
import 'package:flutter_application_1/logic/isolate_messages.dart'; // Added import
import 'package:flutter_application_1/logic/physics_algorithm.dart';
import 'package:flutter_application_1/logic/file_generator.dart'; // Added import
import 'package:flutter_application_1/logic/file_read.dart'; // Add this import

// Export graph data to CSV files
    // if (_graph != null) {
    //   FileGenerator.exportNodesToCsv(_graph!, 'nodes.csv');
    //   FileGenerator.exportEdgesToCsv(_graph!, 'edges.csv');
    // }

class GraphRepository extends ChangeNotifier {
  GraphNetwork? _graph; // Changed from Graph to GraphNetwork
  PhysicsIsolateManager? _physicsIsolateManager; // New
  StreamSubscription<Float64List>? _positionsSubscription; // New
  List<Node>? _path; // New: Stores the list of nodes to be highlighted
  late final TransformationController _transformationController; // New

  // Public getter for the path
  List<Node>? get path => _path;
  // Public getter for the TransformationController
  TransformationController get transformationController => _transformationController;

  // Method to set the path and notify listeners
  void setPath(List<Node>? newPath) {
    _path = newPath;
    notifyListeners();
  }



  // Stored Generation Parameters
  int _nodeCount = 250;
  double _connectionProbability = 0.4;
  double _bandwidth = 100.0; // New bandwidth parameter
  String _sourceNodeId = ''; // New demand parameter
  String _targetNodeId = ''; // New demand parameter
  double _demandMbps = 0.0; // New demand parameter
  double _stiffness = 0.1;
  double _repulsion = 10000.0;
  double _damping = 0.3;
  double _idealLength = 100.0;
  bool _clockwiseFlow = false;
  RenderingMethod _renderingMethod = RenderingMethod.batched; // Added rendering method
  double _barnesHutTheta = 1.0;
  PhysicsAlgorithm _physicsAlgorithm = PhysicsAlgorithm.ForceDirected;
  bool _useQuadtree = false;

  GraphRepository() : _transformationController = TransformationController();

  // Public Getters for Parameters
  int get nodeCount => _nodeCount;
  double get connectionProbability => _connectionProbability;
  double get bandwidth => _bandwidth; // New bandwidth getter
  String get sourceNodeId => _sourceNodeId; // New getter
  String get targetNodeId => _targetNodeId; // New getter
  double get demandMbps => _demandMbps; // New getter
  double get stiffness => _stiffness;
  double get repulsion => _repulsion;
  double get damping => _damping;
  double get idealLength => _idealLength;
  bool get clockwiseFlow => _clockwiseFlow;
  RenderingMethod get renderingMethod => _renderingMethod;
  double get barnesHutTheta => _barnesHutTheta;
  PhysicsAlgorithm get physicsAlgorithm => _physicsAlgorithm;
  bool get useQuadtree => _useQuadtree;

  GraphNetwork? get graph => _graph; // Changed from Graph to GraphNetwork

  /// Updates graph generation parameters (nodeCount, connectionProbability, initialLayoutRandom)
  /// without immediately generating a new graph or affecting the running physics isolate.
  void updateGenerationParameters({
    int? nodeCount,
    double? connectionProbability,
    double? bandwidth, // New optional parameter
    String? sourceNodeId, // New optional parameter
    String? targetNodeId, // New optional parameter
    double? demandMbps, // New optional parameter
  }) {
    bool changed = false;
    if (nodeCount != null && _nodeCount != nodeCount) {
      _nodeCount = nodeCount;
      changed = true;
    }
    if (connectionProbability != null && _connectionProbability != connectionProbability) {
      _connectionProbability = connectionProbability;
      changed = true;
    }
    if (bandwidth != null && _bandwidth != bandwidth) {
      _bandwidth = bandwidth;
      changed = true;
    }
    if (sourceNodeId != null && _sourceNodeId != sourceNodeId) {
      _sourceNodeId = sourceNodeId;
      changed = true;
    }
    if (targetNodeId != null && _targetNodeId != targetNodeId) {
      _targetNodeId = targetNodeId;
      changed = true;
    }
    if (demandMbps != null && _demandMbps != demandMbps) {
      _demandMbps = demandMbps;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Updates physics simulation parameters (stiffness, repulsion, damping, etc.)
  /// and applies them to the running physics isolate.
  void updatePhysicsParameters({
    double? stiffness,
    double? repulsion,
    double? damping,
    double? idealLength,
    bool? clockwiseFlow,
    RenderingMethod? renderingMethod,
    double? barnesHutTheta,
    PhysicsAlgorithm? physicsAlgorithm,
    bool? useQuadtree,
  }) {
    bool changed = false;
    if (stiffness != null && _stiffness != stiffness) {
      _stiffness = stiffness;
      changed = true;
    }
    if (repulsion != null && _repulsion != repulsion) {
      _repulsion = repulsion;
      changed = true;
    }
    if (damping != null && _damping != damping) {
      _damping = damping;
      changed = true;
    }
    if (idealLength != null && _idealLength != idealLength) {
      _idealLength = idealLength;
      changed = true;
    }
    if (clockwiseFlow != null && _clockwiseFlow != clockwiseFlow) {
      _clockwiseFlow = clockwiseFlow;
      changed = true;
    }
    if (renderingMethod != null && _renderingMethod != renderingMethod) {
      _renderingMethod = renderingMethod;
      changed = true;
    }
    if (barnesHutTheta != null && _barnesHutTheta != barnesHutTheta) {
      _barnesHutTheta = barnesHutTheta;
      changed = true;
    }
    if (physicsAlgorithm != null && _physicsAlgorithm != physicsAlgorithm) {
      _physicsAlgorithm = physicsAlgorithm;
      changed = true;
    }
    if (useQuadtree != null && _useQuadtree != useQuadtree) {
      _useQuadtree = useQuadtree;
      changed = true;
    }

    if (changed) {
      _physicsIsolateManager?.updateParams(
        stiffness: _stiffness,
        repulsion: _repulsion,
        damping: _damping,
        idealLength: _idealLength,
        clockwiseFlow: _clockwiseFlow,
        barnesHutTheta: _barnesHutTheta,
        physicsAlgorithm: _physicsAlgorithm,
        useQuadtree: _useQuadtree,
      );
      notifyListeners();
    }
  }


  /// Generates a new graph using the currently stored parameters.
  Future<void> generateGraph({required double width, required double height}) async {
    _graph = GraphNetwork.createRandomErdosRenyi(
      nodeCount: _nodeCount,
      connectionProbability: _connectionProbability,
      width: width,
      height: height,
      bandwidth: _bandwidth, // Pass bandwidth here
    );
    
    // Export graph data to CSV files
    if (_graph != null) {
      FileGenerator.exportNodesToCsv(_graph!, './scripts/data/nodes.csv');
      FileGenerator.exportEdgesToCsv(_graph!, './scripts/data/edges.csv');
    }

    // Dispose previous manager and subscription if they exist
    await _physicsIsolateManager?.stop();
    _positionsSubscription?.cancel();

    _physicsIsolateManager = PhysicsIsolateManager();
    await _physicsIsolateManager!.start(
      _graph!,
      stiffness: _stiffness,
      repulsion: _repulsion,
      damping: _damping,
      idealLength: _idealLength,
      clockwiseFlow: _clockwiseFlow,
      width: width,
      height: height,
      barnesHutTheta: _barnesHutTheta,
      physicsAlgorithm: _physicsAlgorithm,
      useQuadtree: _useQuadtree,
    );

    _positionsSubscription = _physicsIsolateManager!.positionsStream.listen(
      (newPositions) {
        if (_graph != null) {
          _graph!.updatePositionsFromFloat64List(newPositions);
          notifyListeners(); // Notify UI to redraw
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Error from Physics Isolate stream: $error\n$stackTrace');
        // Optionally, reset the graph or display an error to the user
      },
      cancelOnError: true, // Automatically cancel subscription on error
    );
    
    notifyListeners();
  }

  /// Imports a graph from nodes.csv and edges.csv files.
  Future<void> loadGraphFromCsvFiles(String nodesFilePath, {String? edgesFilePath, required double width, required double height}) async {
    try {
      final nodesData = await FileRead.readNodesCsv(nodesFilePath);
      List<Map<String, dynamic>> edgesData = [];
      if (edgesFilePath != null) {
        edgesData = await FileRead.readEdgesCsv(edgesFilePath);
      }

      // Create Node objects
      final List<Node> newNodes = [];
      final double centerX = width / 2;
      final double centerY = height / 2;
      final double scalingFactor = math.min(width, height) / (2 * math.sqrt(nodesData.length)); // Adjust factor for better fit

      for (int i = 0; i < nodesData.length; i++) {
        final data = nodesData[i];
        final SpiralNode spiralPos = OptimizedSpiralGenerator.getPosition(i, scalingFactor);

        final Node node = Node(
          id: data['id'],
          type: NodeType.relay, // Default to relay for imported nodes
          processingDelay: data['processingDelay'] ?? 0.0,
          nodeReliability: data['nodeReliability'] ?? 0.0,
          position: CustomPoint(
            (centerX + spiralPos.x).clamp(0.1, width - 0.1),
            (centerY + spiralPos.y).clamp(0.1, height - 0.1),
          ),
        );
        newNodes.add(node);
      }

      // Create a map for quick node lookup
      final Map<String, Node> nodeMap = {for (var node in newNodes) node.id: node};

      // Create Link objects
      final List<Link> newLinks = edgesData.map((data) {
        final sourceNode = nodeMap[data['sourceId']];
        final targetNode = nodeMap[data['targetId']];

        if (sourceNode == null || targetNode == null) {
          throw Exception('Source or target node not found for link: ${data['sourceId']} -> ${data['targetId']}');
        }

        return Link(
          source: sourceNode,
          target: targetNode,
          bandwidth: data['bandwidth'] ?? 0.0,
          linkDelay: data['linkDelay'] ?? 0.0,
          linkReliability: data['linkReliability'] ?? 0.0,
        );
      }).toList();

      _graph = GraphNetwork(nodes: newNodes, links: newLinks);
      // debugPrint('GraphRepository: Loaded ${newNodes.length} nodes and ${newLinks.length} links from CSV.');

      // Dispose previous manager and subscription if they exist
      await _physicsIsolateManager?.stop();
      _positionsSubscription?.cancel();

      // Start physics isolate with the new graph
      _physicsIsolateManager = PhysicsIsolateManager();
      await _physicsIsolateManager!.start(
        _graph!,
        stiffness: _stiffness,
        repulsion: _repulsion,
        damping: _damping,
        idealLength: _idealLength,
        clockwiseFlow: _clockwiseFlow,
        width: width,
        height: height,
        barnesHutTheta: _barnesHutTheta,
        physicsAlgorithm: _physicsAlgorithm,
        useQuadtree: _useQuadtree,
      );

      _positionsSubscription = _physicsIsolateManager!.positionsStream.listen(
        (newPositions) {
          if (_graph != null) {
            _graph!.updatePositionsFromFloat64List(newPositions);
            // debugPrint('GraphRepository: Received position update from isolate. Notifying listeners.'); // Removed debugPrint
            notifyListeners(); // Notify UI to redraw
          }
        },
        onError: (error, stackTrace) {
          debugPrint('Error from Physics Isolate stream: $error'); // Keep as error log
        },
        cancelOnError: true,
      );

      notifyListeners();
      // debugPrint('Graph loaded successfully from CSV files.'); // Removed debugPrint
    } catch (e) {
      debugPrint('Error loading graph from CSV: $e'); // Keep as error log
      // Optionally, set _graph to null or a default empty graph
      _graph = null;
      notifyListeners();
    }
  }


  /// Sends a PhysicsCommand to the physics isolate.
  void sendCommand(PhysicsCommand command) {
    _physicsIsolateManager?.sendCommand(command);
  }

  void updateDimensions(double width, double height) {
    _physicsIsolateManager?.updateDimensions(width, height);
  }

  /// Exports the demand data to a CSV file.
  Future<void> exportDemandFile() async {
    if (_sourceNodeId.isNotEmpty && _targetNodeId.isNotEmpty && _demandMbps > 0) {
      await FileGenerator.exportDemandToCsv(
        './scripts/data/demand.csv',
        _sourceNodeId,
        _targetNodeId,
        _demandMbps,
      );
      // debugPrint('Demand file exported to demand.csv'); // Add a debug print for confirmation
    } else {
      // debugPrint('Cannot export demand file: Source or target node ID is empty, or demand is zero.');
    }
  }

  @override
  void dispose() {
    _physicsIsolateManager?.stop();
    _positionsSubscription?.cancel();
    _transformationController.dispose(); // Dispose the TransformationController
    super.dispose();
  }

  @override
  void notifyListeners() {
    // Only notify listeners if the ChangeNotifier is still mounted and has active listeners.
    // This helps prevent calling notifyListeners on a disposed object, which can happen during testing.
    if (!hasListeners) return;
    super.notifyListeners();
  }
}

final graphRepositoryProvider = ChangeNotifierProvider<GraphRepository>((ref) {
  final repo = GraphRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});
