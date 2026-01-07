import 'dart:math';
import 'dart:math' as math;
import 'dart:typed_data'; // Added import for Float64List
import 'package:flutter_application_1/logic/priority_queue.dart';

final _random = Random();


/// A simple class to represent a 2D point with basic vector operations.
/// This is used to avoid a dependency on dart:ui (and thus Flutter) in the core graph logic.
class CustomPoint {
  double x, y;
  CustomPoint(this.x, this.y);

  factory CustomPoint.from(CustomPoint other) {
    return CustomPoint(other.x, other.y);
  }

  CustomPoint copyWith({double? x, double? y}) {
    return CustomPoint(x ?? this.x, y ?? this.y);
  }

  CustomPoint operator +(CustomPoint other) =>
      CustomPoint(x + other.x, y + other.y);
  CustomPoint operator -(CustomPoint other) =>
      CustomPoint(x - other.x, y - other.y);
  CustomPoint operator *(double scalar) => CustomPoint(x * scalar, y * scalar);
  CustomPoint operator /(double scalar) {
    if (scalar == 0) throw ArgumentError('Cannot divide by zero');
    return CustomPoint(x / scalar, y / scalar);
  }

  double get magnitude => sqrt(x * x + y * y);

  CustomPoint normalized() {
    final mag = magnitude;
    if (mag == 0) return CustomPoint(0, 0);
    return CustomPoint(x / mag, y / mag);
  }
}

enum NodeType { source, target, relay }

class Node {
  final String id;
  final NodeType type;
  final double processingDelay; // 0.5 ms to 2.0 ms
  final double nodeReliability; // 0.95 to 0.999
  CustomPoint position;

  Node({
    required this.id,
    required this.type,
    required this.processingDelay,
    required this.nodeReliability,
    required this.position,
  });

  factory Node.random(String id) {
    final nodeType = (_random.nextInt(10) == 0)
        ? NodeType.values[_random.nextInt(NodeType.values.length)]
        : NodeType.relay;
    return Node(
      id: id,
      type: nodeType,
      // ProcessingDelay_i: [0.5 ms - 2.0 ms]
      processingDelay: 0.5 + _random.nextDouble() * 1.5,
      // NodeReliability_i: [0.95, 0.999]
      nodeReliability: 0.95 + _random.nextDouble() * 0.049,
      position: CustomPoint(0, 0), // Default position
    );
  }

  Node copyWith({
    String? id,
    NodeType? type,
    double? processingDelay,
    double? nodeReliability,
    CustomPoint? position,
  }) {
    return Node(
      id: id ?? this.id,
      type: type ?? this.type,
      processingDelay: processingDelay ?? this.processingDelay,
      nodeReliability: nodeReliability ?? this.nodeReliability,
      position: position ?? this.position,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class Link {
  final Node source;
  final Node target;
  final double bandwidth; // 100 Mbps to 1000 Mbps
  final double linkDelay; // 3 ms to 15 ms
  final double linkReliability; // 0.95 to 0.999

  Link({
    required this.source,
    required this.target,
    required this.bandwidth,
    required this.linkDelay,
    required this.linkReliability,
  });

  factory Link.random(Node source, Node target, {double? bandwidth}) {
    return Link(
      source: source,
      target: target,
      // Bandwidth_ij: [100 Mbps, 1000 Mbps]
      bandwidth: bandwidth ?? (100 + _random.nextDouble() * 900),
      // LinkDelay_ij: [3 ms, 15 ms]
      linkDelay: 3 + _random.nextDouble() * 12,
      // LinkReliability_ij: [0.95, 0.999]
      linkReliability: 0.95 + _random.nextDouble() * 0.049,
    );
  }
}

class GraphNetwork {
  final List<Node> nodes;
  final List<Link> links;

  // NEW: Fast lookup map
  late final Map<String, List<Link>> _adjacencyList;
  late final Map<String, int> _nodeIndexMap; // Added for Node to index mapping

  GraphNetwork({required this.nodes, required this.links}) {
    _buildAdjacencyList();
    _buildNodeIndexMap();
  }

  void _buildAdjacencyList() {
    _adjacencyList = {};
    for (var node in nodes) {
      _adjacencyList[node.id] = [];
    }
    for (var link in links) {
      // Add link to both source and target (undirected logic for navigation)
      _adjacencyList[link.source.id]?.add(link);
      _adjacencyList[link.target.id]?.add(link);
    }
  }

  void _buildNodeIndexMap() {
    _nodeIndexMap = {};
    for (int i = 0; i < nodes.length; i++) {
      _nodeIndexMap[nodes[i].id] = i;
    }
  }

  // O(1) Lookup - Critical for ACO/GA
  List<Link> getOutboundLinks(Node u) {
    return _adjacencyList[u.id] ?? [];
  }

  /// Finds the shortest path between two nodes using a Dijkstra-like algorithm.
  /// This implementation finds the path with the minimum number of hops (unweighted edges).
  List<Node> getShortestPath(Node start, Node end) {
    final distances = <Node, double>{};
    final previous = <Node, Node?>{};
    final queue = PriorityQueue<Node>((a, b) => distances[a]!.compareTo(distances[b]!));

    for (var node in nodes) {
      distances[node] = double.infinity;
    }
    distances[start] = 0;
    queue.add(start);

    while (!queue.isEmpty) {
      final current = queue.removeMin();

      if (current == end) {
        final path = <Node>[];
        var curr = end;
        while (previous[curr] != null) {
          path.insert(0, curr);
          curr = previous[curr]!;
        }
        path.insert(0, start);
        return path;
      }

      if (distances[current] == double.infinity) continue; // Skip if already processed or unreachable

      for (var link in getOutboundLinks(current)) {
        final neighbor = (link.source == current) ? link.target : link.source;
        final alt = distances[current]! + 1; // Unweighted BFS (or use link.delay)

        if (alt < distances[neighbor]!) {
          distances[neighbor] = alt;
          previous[neighbor] = current;
          queue.add(neighbor);
        }
      }
    }
    return []; // No path found
  }

  /// Checks if the graph is connected using a Breadth-First Search (BFS).
  static bool isConnected(GraphNetwork graph) {
    if (graph.nodes.isEmpty) return true;
    if (graph.nodes.length == 1) return true;

    final visited = <Node>{};
    final queue = [graph.nodes.first];
    visited.add(graph.nodes.first);

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final link in graph.links) {
        if (link.source == current && !visited.contains(link.target)) {
          visited.add(link.target);
          queue.add(link.target);
        } else if (link.target == current && !visited.contains(link.source)) {
          visited.add(link.source);
          queue.add(link.source);
        }
      }
    }
    return visited.length == graph.nodes.length;
  }

  /// Converts the current node positions into a Float64List for efficient transfer.
  Float64List toPositionsFloat64List() {
    final Float64List positions = Float64List(nodes.length * 2);
    for (int i = 0; i < nodes.length; i++) {
      positions[i * 2] = nodes[i].position.x;
      positions[i * 2 + 1] = nodes[i].position.y;
    }
    return positions;
  }

  /// Converts the current links into a List<List<int>> for efficient transfer.
  List<List<int>> toLinksList() {
    return links.map((link) {
      final sourceIndex = _nodeIndexMap[link.source.id]!; // Use ! for non-null
      final targetIndex = _nodeIndexMap[link.target.id]!; // Use ! for non-null
      return [sourceIndex, targetIndex];
    }).toList();
  }

  /// Updates the positions of the nodes based on a Float64List received from the isolate.
  void updatePositionsFromFloat64List(Float64List newPositions) {
    if (newPositions.length != nodes.length * 2) {
      throw ArgumentError('Mismatched positions list length');
    }
    for (int i = 0; i < nodes.length; i++) {
      nodes[i].position.x = newPositions[i * 2];
      nodes[i].position.y = newPositions[i * 2 + 1];
    }
  }


  factory GraphNetwork.createRandomErdosRenyi({
    int nodeCount = 250,
    double connectionProbability = 0.4,
    double width = 100,
    double height = 100,
    double? bandwidth, // New optional parameter
  }) {
    GraphNetwork? generatedGraph;
    double currentP = connectionProbability;

    // Continue attempting generation until a connected graph is produced,
    // mirroring the while-not-nx.is_connected loop in Python.
    while (generatedGraph == null || !GraphNetwork.isConnected(generatedGraph)) {
      final List<Node> nodes = [];
      final List<Link> links = [];
      final Set<String> existingLinks = {};

      // 1. Initialize Nodes using spiral placement
      final double centerX = width / 2;
      final double centerY = height / 2;
      final double scalingFactor = math.min(width, height) / (2 * math.sqrt(nodeCount)); // Adjust factor for better fit

      for (int i = 0; i < nodeCount; i++) {
        final node = Node.random('node_$i');
        final SpiralNode spiralPos = OptimizedSpiralGenerator.getPosition(i, scalingFactor);
        node.position = CustomPoint(
          (centerX + spiralPos.x).clamp(0.1, width - 0.1),
          (centerY + spiralPos.y).clamp(0.1, height - 0.1),
        );
        nodes.add(node);
      }

      // 2. Implement G(n, p) Edge Generation
      // For every pair (i, j), connect with probability currentP
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          if (_random.nextDouble() < currentP) {
            final Node u = nodes[i];
            final Node v = nodes[j];
            
            // Canonical key to prevent duplicates
            final String linkKey = u.id.compareTo(v.id) < 0 
                ? '${u.id}-${v.id}' 
                : '${v.id}-${u.id}';

            if (existingLinks.add(linkKey)) {
              links.add(Link.random(u, v, bandwidth: bandwidth)); // Pass bandwidth here
            }
          }
        }
      }

      generatedGraph = GraphNetwork(nodes: nodes, links: links);

      // If not connected, increase probability slightly for next iteration
      if (!GraphNetwork.isConnected(generatedGraph)) {
        currentP += 0.05;
        if (currentP > 1.0) currentP = 1.0;
      }
    }

    return generatedGraph;
  }
}

class SpiralNode {
  final double x;
  final double y;
  
  SpiralNode(this.x, this.y);
}

class OptimizedSpiralGenerator {
  // The Golden Angle is the key to avoiding the "line" pattern in your image
  static const double _goldenAngle = 2.3999632297; 

  /// Generates positions that fill the space uniformly
  static SpiralNode getPosition(int n, double scalingFactor) {
    // 1. Use sqrt(n) to keep density constant across the entire disk
    final double radius = scalingFactor * math.sqrt(n);
    
    // 2. Use the golden angle so nodes don't "spoke" or "clump"
    final double theta = n * _goldenAngle;

    final double x = radius * math.cos(theta);
    final double y = radius * math.sin(theta);

    return SpiralNode(x, y);
  }
}

