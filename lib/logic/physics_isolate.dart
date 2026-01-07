import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui'; // For Rect

import 'package:flutter_application_1/logic/flat_quadtree.dart' as flat_quadtree; // Import FlatQuadTree
import 'package:flutter_application_1/logic/isolate_messages.dart'; // Re-add missing import
import 'package:flutter_application_1/logic/barnes_hut.dart'; // Re-add missing import for calculateRepulsionBarnesHut
import 'package:flutter_application_1/logic/physics_algorithm.dart';

/// The entry point for the physics isolate.
void physicsIsolateEntryPoint(StartCommand initialCommand) {
  final runner = PhysicsIsolateRunner();
  runner.init(initialCommand);
}

/// The main class that runs the simulation within the isolate.
class PhysicsIsolateRunner {
  late final SendPort _sendPort;
  late final int _nodeCount;

  // Data-Oriented Design: Flat lists for physics properties.
  late Float64List _positions; // [x0, y0, x1, y1, ...]
  late Float64List _forces; // [fx0, fy0, fx1, fy1, ...]
  late TransferableTypedData _linksTransferable; // Stores the transferable version
  late Int32List _linksFlat; // Stores the materialized Int32List for use
  late Float64List _previousPositions; // [prev_x0, prev_y0, prev_x1, prev_y1, ...]

  // Simulation parameters
  late double _stiffness;
  late double _repulsion;
  late double _damping;
  late double _idealLength;
  late bool _clockwiseFlow;
  late double _width;
  late double _height;
  late double _barnesHutTheta;
  late PhysicsAlgorithm _physicsAlgorithm;
  late bool _useQuadtree;

  // Flat Quadtree for Barnes-Hut
  late flat_quadtree.FlatQuadTree _flatQuadTree;
  late int _rootNodeIndex;

  Timer? _timer;
  final _receivePort = ReceivePort();

  /// Initializes the runner and starts the simulation loop.
  void init(StartCommand command) {
    _sendPort = command.sendPort;
    _positions = command.initialPositions;
    _linksTransferable = command.linksFlat; // Store the transferable object
    _linksFlat = Int32List.view(_linksTransferable.materialize());

    _nodeCount = _positions.length ~/ 2;
    _forces = Float64List(_nodeCount * 2);
    _previousPositions = Float64List.fromList(_positions); // Initialize previous positions

    // Set initial parameters from command
    _stiffness = command.stiffness;
    _repulsion = command.repulsion;
    _damping = command.damping;
    _idealLength = command.idealLength;
    _clockwiseFlow = command.clockwiseFlow;
    _width = command.width;
    _height = command.height;
    _barnesHutTheta = command.barnesHutTheta;
    _physicsAlgorithm = command.physicsAlgorithm;
    _useQuadtree = command.useQuadtree;

    // Initialize FlatQuadTree after parameters are set
    _flatQuadTree = flat_quadtree.FlatQuadTree(_nodeCount * (flat_quadtree.MAX_DEPTH + 1), _nodeCount * (flat_quadtree.MAX_DEPTH + 1), Rect.fromLTWH(0, 0, _width, _height));

    // Listen for commands from the main thread.
    _receivePort.listen(_handleCommand);

    // Send the receive port to the main thread so it can send us commands.
    _sendPort.send(_receivePort.sendPort);
    
    // Notify main thread that the isolate is ready.
    _sendPort.send(IsolateReadyResult());

    // Start the simulation loop.
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  /// Handles commands received from the main thread.
  void _handleCommand(dynamic message) {
    if (message is PhysicsCommand) {
      if (message is UpdateParamsCommand) {
        // Update parameters
        _stiffness = message.stiffness ?? _stiffness;
        _repulsion = message.repulsion ?? _repulsion;
        _damping = message.damping ?? _damping;
        _idealLength = message.idealLength ?? _idealLength;
        _clockwiseFlow = message.clockwiseFlow ?? _clockwiseFlow;
        _width = message.width ?? _width;
        _height = message.height ?? _height;
        _barnesHutTheta = message.barnesHutTheta ?? _barnesHutTheta;
        _physicsAlgorithm = message.physicsAlgorithm ?? _physicsAlgorithm;
        _useQuadtree = message.useQuadtree ?? _useQuadtree;
      } else if (message is ApplyForceCommand) {
        // Apply a force to a node
        final index = message.nodeIndex * 2;
        _forces[index] += message.dx;
        _forces[index + 1] += message.dy;
      } else if (message is UpdateNodePositionCommand) {
        final index = message.nodeIndex * 2;
        _positions[index] = message.newX;
        _positions[index + 1] = message.newY;
        // Zero out velocity by setting previous position to current position
        _previousPositions[index] = message.newX;
        _previousPositions[index + 1] = message.newY;
      } else if (message is UpdateDimensionsCommand) {
        _width = message.width;
        _height = message.height;
      } else if (message is StopCommand) {
        _timer?.cancel();
        _receivePort.close();
      }
    }
  }

  /// A single step of the physics simulation.
  void _tick(Timer timer) {
    // 1. Reset forces
    _forces.fillRange(0, _forces.length, 0);

    // 2. Calculate repulsive forces based on the selected algorithm
    if (_physicsAlgorithm == PhysicsAlgorithm.BarnesHut && _useQuadtree) {
      // Build Barnes-Hut tree for repulsion
      _flatQuadTree.clear(); // Clear the tree for a new build
      final List<flat_quadtree.BHNode> bhNodes = [];
      for (int i = 0; i < _nodeCount; i++) {
        final clampedX = _positions[i * 2].clamp(0.0, _width);
        final clampedY = _positions[i * 2 + 1].clamp(0.0, _height);
        bhNodes.add(flat_quadtree.BHNode(id: i, position: flat_quadtree.Point(clampedX, clampedY)));
      }
      _rootNodeIndex = _flatQuadTree.build(bhNodes);
      _calculateRepulsiveForcesBarnesHut();
    } else { // PhysicsAlgorithm.ForceDirected or BarnesHut without Quadtree
      _calculateRepulsiveForcesDirect();
    }

    // 3. Calculate attractive forces
    _calculateAttractiveForces();
    if (_clockwiseFlow) {
      _applyClockwiseFlow();
    }

    // 4. Update velocities and positions (Euler integration)
    _updatePositions();
    
    // 5. Send the new positions back to the main thread.
    // Use TransferableTypedData for zero-copy transfer.
    try {
        final transferable = TransferableTypedData.fromList([_positions]);
        _sendPort.send(PositionsUpdateResult(transferable));
    } catch (e) {
        // The port might be closed if the main isolate has been disposed.
    }
  }

  void _calculateRepulsiveForcesBarnesHut() { // No longer takes QuadNode as argument
    for (int i = 0; i < _nodeCount; i++) {
      final iIdx = i * 2;
      final targetBHNode = flat_quadtree.BHNode(id: i, position: flat_quadtree.Point(_positions[iIdx], _positions[iIdx + 1]));
      
      final repulsionForce = calculateRepulsionBarnesHut(
        targetBHNode,
        _flatQuadTree, // Pass the FlatQuadTree instance
        _rootNodeIndex, // Pass the root node index
        _barnesHutTheta,
        _repulsion,
      );

      _forces[iIdx] += repulsionForce.x;
      _forces[iIdx + 1] += repulsionForce.y;
    }
  }

  void _calculateRepulsiveForcesDirect() {
    for (int i = 0; i < _nodeCount; i++) {
      for (int j = i + 1; j < _nodeCount; j++) {
        final iIdx = i * 2;
        final jIdx = j * 2;

        final dx = _positions[jIdx] - _positions[iIdx];
        final dy = _positions[jIdx + 1] - _positions[iIdx + 1];
        final distance = sqrt(dx * dx + dy * dy) + 0.01; // Add epsilon to prevent division by zero

        final forceMagnitude = -_repulsion / (distance * distance); // Inverse square law
        
        final fx = (dx / distance) * forceMagnitude;
        final fy = (dy / distance) * forceMagnitude;

        _forces[iIdx] += fx;
        _forces[iIdx + 1] += fy;
        _forces[jIdx] -= fx;
        _forces[jIdx + 1] -= fy;
      }
    }
  }

  void _calculateAttractiveForces() {
    for (int i = 0; i < _linksFlat.length; i += 2) {
      final sourceNodeIndex = _linksFlat[i];
      final targetNodeIndex = _linksFlat[i + 1];

      final sourceIdx = sourceNodeIndex * 2;
      final targetIdx = targetNodeIndex * 2;

      final dx = _positions[targetIdx] - _positions[sourceIdx];
      final dy = _positions[targetIdx + 1] - _positions[sourceIdx + 1];
      final distance = sqrt(dx * dx + dy * dy) + 0.01;

      final displacement = distance - _idealLength;
      final force = _stiffness * displacement * 0.01;

      final fx = (dx / distance) * force;
      final fy = (dy / distance) * force;

      // Apply forces to the nodes
      _forces[sourceIdx] += fx;
      _forces[sourceIdx + 1] += fy;
      _forces[targetIdx] -= fx;
      _forces[targetIdx + 1] -= fy;
    }
  }
  
  void _applyClockwiseFlow() {
    final centerX = _width / 2;
    final centerY = _height / 2;

    for (int i = 0; i < _nodeCount; i++) {
        final iIdx = i*2;
        final dx = _positions[iIdx] - centerX;
        final dy = _positions[iIdx+1] - centerY;
        final distFromCenter = sqrt(dx*dx + dy*dy);

        if (distFromCenter > 1.0) {
            // Tangential force: (-dy, dx) normalized
            final fdx = -dy / distFromCenter;
            final fdy = dx / distFromCenter;
            
            _forces[iIdx] += fdx * 0.1;
            _forces[iIdx+1] += fdy * 0.1;
        }
    }
  }

  // Time step squared (16ms = 0.016s)
  static const double DT_SQUARED = 0.016 * 0.016; // 0.000256

  void _updatePositions() {
    for (int i = 0; i < _nodeCount; i++) {
      final idx = i * 2;

      final currentX = _positions[idx];
      final currentY = _positions[idx + 1];

      final prevX = _previousPositions[idx];
      final prevY = _previousPositions[idx + 1];

      // Calculate acceleration from forces (assuming unit mass)
      final accX = _forces[idx];
      final accY = _forces[idx + 1];

      // Verlet Integration
      // x_next = x_current + (x_current - x_previous) * damping + acceleration * dt^2
      final newX = currentX + (currentX - prevX) * _damping + accX * DT_SQUARED;
      final newY = currentY + (currentY - prevY) * _damping + accY * DT_SQUARED;

      // Update previous positions
      _previousPositions[idx] = currentX;
      _previousPositions[idx + 1] = currentY;

      // Update current positions
      _positions[idx] = newX;
      _positions[idx + 1] = newY;
    }
  }
}
