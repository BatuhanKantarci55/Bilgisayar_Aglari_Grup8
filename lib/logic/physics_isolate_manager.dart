import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/logic/graph_network.dart';
import 'package:flutter_application_1/logic/isolate_messages.dart';
import 'package:flutter_application_1/logic/physics_isolate.dart';
import 'package:flutter_application_1/logic/physics_algorithm.dart';

/// Manages the physics isolate, sending commands and receiving position updates.
class PhysicsIsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  final StreamController<Float64List> _positionsController =
      StreamController<Float64List>.broadcast();

  Stream<Float64List> get positionsStream => _positionsController.stream;

  /// Spawns the physics isolate and establishes communication.
  Future<void> start(GraphNetwork graph,
      {double stiffness = 0.1,
      double repulsion = 10000.0,
      double damping = 0.8,
      double idealLength = 100.0,
      bool clockwiseFlow = false,
      required double width,
      required double height,
      double barnesHutTheta = 1.0,
      required PhysicsAlgorithm physicsAlgorithm,
      required bool useQuadtree}) async {
    if (_isolate != null) {
      // debugPrint('Isolate already running, stopping first.');
      await stop();
    }

    final linksFlatList = graph.toLinksList().expand((link) => link).toList();
    final linksInt32List = Int32List.fromList(linksFlatList);
    final linksTransferable = TransferableTypedData.fromList([linksInt32List]);

    _isolate = await Isolate.spawn(
      physicsIsolateEntryPoint,
      StartCommand(
        sendPort: _receivePort.sendPort,
        initialPositions: graph.toPositionsFloat64List(),
        linksFlat: linksTransferable,
        stiffness: stiffness,
        repulsion: repulsion,
        damping: damping,
        idealLength: idealLength,
        clockwiseFlow: clockwiseFlow,
        width: width,
        height: height,
        barnesHutTheta: barnesHutTheta,
        physicsAlgorithm: physicsAlgorithm,
        useQuadtree: useQuadtree,
      ),
      errorsAreFatal: true,
      // onExit: _handleIsolateExit, // Removed to fix SendPort type mismatch
      // onError: _handleIsolateError, // Removed to fix SendPort type mismatch
    );

    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        // Optionally send a ready message to the main app if needed
      } else if (message is PositionsUpdateResult) {
        _positionsController.add(Float64List.view(message.positions.materialize())); // Corrected: materialize()
      } else if (message is IsolateReadyResult) {
        // debugPrint("Physics Isolate is ready.");
      } else {
        // debugPrint('Unknown message from isolate: $message');
      }
    });

    // debugPrint('Physics Isolate spawned.');
  }

  /// Sends an UpdateParamsCommand to the isolate.
  void updateParams({
    double? stiffness,
    double? repulsion,
    double? damping,
    double? idealLength,
    bool? clockwiseFlow,
    double? width,
    double? height,
    double? barnesHutTheta,
    PhysicsAlgorithm? physicsAlgorithm,
    bool? useQuadtree,
  }) {
    _sendPort?.send(
      UpdateParamsCommand(
        stiffness: stiffness,
        repulsion: repulsion,
        damping: damping,
        idealLength: idealLength,
        clockwiseFlow: clockwiseFlow,
        width: width,
        height: height,
        barnesHutTheta: barnesHutTheta,
        physicsAlgorithm: physicsAlgorithm,
        useQuadtree: useQuadtree,
      ),
    );
  }

  /// Sends an ApplyForceCommand to the isolate.
  void applyForce(int nodeIndex, double dx, double dy) {
    _sendPort?.send(ApplyForceCommand(nodeIndex, dx, dy));
  }

  /// Sends a generic PhysicsCommand to the isolate.
  void sendCommand(PhysicsCommand command) {
    _sendPort?.send(command);
  }

  void updateDimensions(double width, double height) {
    _sendPort?.send(UpdateDimensionsCommand(width, height));
  }

  /// Stops the physics isolate.
  Future<void> stop() async {
    _sendPort?.send(StopCommand());
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    await _positionsController.close(); // Close the stream controller
    _receivePort.close();
    // debugPrint('Physics Isolate stopped and resources released.');
  }
}

// Top-level functions to handle isolate exit and errors
/*
void _handleIsolateExit(dynamic message) {
      // debugPrint('Physics Isolate exited: $message');  // Re-initialize manager state if needed, or notify UI
}

void _handleIsolateError(dynamic error, dynamic stack) { // Corrected signature
      // debugPrint('Physics Isolate error: $error\nStack: $stack');  // Handle error, e.g., restart isolate or notify UI
}
*/
