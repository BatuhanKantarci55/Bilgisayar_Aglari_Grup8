
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/logic/graph_network.dart';
import 'package:flutter_application_1/logic/graph_generation_isolate.dart';


class GraphNotifier extends ChangeNotifier {
  GraphNetwork _graph = GraphNetwork(nodes: [], links: []); // Corrected to use 'links'

  GraphNetwork get graph => _graph;

  void setGraph(GraphNetwork newGraph) {
    _graph = newGraph;
    notifyListeners();
  }

  void addNode(Node node) {
    _graph.nodes.add(node);
    notifyListeners();
  }

  void addLink(Link link) { // Changed from addEdge to addLink
    _graph.links.add(link); // Corrected to use 'links'
    notifyListeners();
  }

  void updateNodePosition(String nodeId, CustomPoint newPosition) {
    final nodeIndex = _graph.nodes.indexWhere((node) => node.id == nodeId);
    if (nodeIndex != -1) {
      final oldNode = _graph.nodes[nodeIndex];
      _graph.nodes[nodeIndex] = oldNode.copyWith(position: newPosition);
      notifyListeners();
    }
  }

  void updateAllNodePositions(Map<String, CustomPoint> newPositions) {
    for (int i = 0; i < _graph.nodes.length; i++) {
      final node = _graph.nodes[i];
      if (newPositions.containsKey(node.id)) {
        _graph.nodes[i] = node.copyWith(position: newPositions[node.id]!);
      }
    }
    notifyListeners();
  }

  Future<void> generateRandomGraph({
    required int nodeCount,
    required double connectionProbability,
    required double width,
    required double height,
  }) async {
    _graph = await generateGraphInIsolate(
      nodeCount: nodeCount,
      connectionProbability: connectionProbability,
      width: width,
      height: height,
    );
    notifyListeners();
  }
}

final graphNotifierProvider = ChangeNotifierProvider<GraphNotifier>((ref) {
  return GraphNotifier();
});
