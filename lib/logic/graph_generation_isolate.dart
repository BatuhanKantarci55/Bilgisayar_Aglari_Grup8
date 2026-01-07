import 'dart:isolate';
import 'package:flutter_application_1/logic/graph_network.dart';

/// Message sent to the isolate for graph generation.
class GraphGenerationRequest {
  final SendPort sendPort;
  final int nodeCount;
  final double connectionProbability;
  final double width;
  final double height;

  GraphGenerationRequest({
    required this.sendPort,
    required this.nodeCount,
    required this.connectionProbability,
    required this.width,
    required this.height,
  });
}

/// Entry point for the isolate that generates the graph.
void graphGenerationEntryPoint(GraphGenerationRequest request) {
  final graph = GraphNetwork.createRandomErdosRenyi(
    nodeCount: request.nodeCount,
    connectionProbability: request.connectionProbability,
    width: request.width,
    height: request.height,
  );
  request.sendPort.send(graph);
}

/// Spawns an isolate to generate a graph and returns the generated graph.
Future<GraphNetwork> generateGraphInIsolate({
  required int nodeCount,
  required double connectionProbability,
  required double width,
  required double height,
}) async {
  final receivePort = ReceivePort();
  final isolate = await Isolate.spawn(
    graphGenerationEntryPoint,
    GraphGenerationRequest(
      sendPort: receivePort.sendPort,
      nodeCount: nodeCount,
      connectionProbability: connectionProbability,
      width: width,
      height: height,
    ),
  );

  final graph = await receivePort.first as GraphNetwork;
  isolate.kill(priority: Isolate.immediate);
  return graph;
}
