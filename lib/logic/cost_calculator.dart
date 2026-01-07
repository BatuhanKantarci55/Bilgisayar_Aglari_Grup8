import 'dart:math';
import 'graph_network.dart';

class NetworkCostCalculator {
  final double wDelay;
  final double wRel;
  final double wRes;
  final GraphNetwork? graph;

  NetworkCostCalculator({
    required this.graph,
    this.wDelay = 0.33,
    this.wRel = 0.33,
    this.wRes = 0.34,
  });

  /// Calculates the fitness cost of a given path.
  /// Logic ported directly from Python cost_calculator.py
  Map<String, dynamic> calculateMetrics(List<Node> path) {
    if (graph == null) {
      return {"valid": false, "message": "Graph not loaded."};
    }

    if (path.length < 2) {
      return {"valid": false, "message": "Path too short or empty."};
    }

    double totalDelay = 0.0;
    double totalResourceCost = 0.0;
    double reliabilityLogCost = 0.0;
    double reliabilityReal = 1.0;

    try {
      // --- 1. NODE CALCULATIONS (Intermediate Nodes Only) ---
      // In Python: path[1:-1]
      for (int i = 1; i < path.length - 1; i++) {
        final node = path[i];

        // Processing Delay
        totalDelay += node.processingDelay;

        // Node Reliability
        double rel = node.nodeReliability;
        reliabilityReal *= rel;

        // Cost calculation using natural log (math.log in Python)
        reliabilityLogCost += (rel > 0) ? -log(rel) : 100.0;
      }

      // --- 2. LINK CALCULATIONS ---
      for (int i = 0; i < path.length - 1; i++) {
        final u = path[i];
        final v = path[i + 1];

        // Find the link connecting node u and node v
        final link = _findLink(u, v);

        if (link == null) {
          return {
            "valid": false,
            "message": "Link not found: ${u.id} -> ${v.id}",
          };
        }

        // Link Delay
        totalDelay += link.linkDelay;

        // Link Reliability
        double lRel = link.linkReliability;
        reliabilityReal *= lRel;
        reliabilityLogCost += (lRel > 0) ? -log(lRel) : 100.0;

        // Resource Cost (Based on Bandwidth)
        // Python logic: 1000.0 / bandwidth
        double bw = (link.bandwidth > 0) ? link.bandwidth : 1.0;
        totalResourceCost += (1000.0 / bw);
      }

      // --- 3. FINAL FITNESS CALCULATION ---
      final weightedCost =
          (wDelay * totalDelay) +
          (wRel * reliabilityLogCost) +
          (wRes * totalResourceCost);

      return {
        "valid": true,
        "path": path.map((n) => n.id).toList(),
        "total_cost (Fitness)": _round(weightedCost, 4),
        "details": {
          "Total Delay": _round(totalDelay, 4),
          "Reliability (%)": _round(reliabilityReal * 100, 4),
          "Reliability Cost": _round(reliabilityLogCost, 4),
          "Resource Cost": _round(totalResourceCost, 4),
        },
      };
    } catch (e) {
      return {"valid": false, "message": "Calculation error: $e"};
    }
  }

  /// Helper: Finds the Link object that connects two specific Nodes
  Link? _findLink(Node u, Node v) {
    if (graph == null) return null;

    // Iterates through links to find matching source/target (undirected)
    for (var link in graph!.links) {
      if ((link.source == u && link.target == v) ||
          (link.source == v && link.target == u)) {
        return link;
      }
    }
    return null;
  }

  /// Rounds doubles to a specific precision
  double _round(double val, int places) {
    double mod = pow(10.0, places).toDouble();
    return ((val * mod).round().toDouble() / mod);
  }
}
