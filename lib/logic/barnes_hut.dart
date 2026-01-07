import 'flat_quadtree.dart'; // Import the new flat quadtree implementation

const int MAX_DEPTH = 16; // Hard cap recursion depth
const double EPSILON = 0.01; // Microscopic random noise for jitter
const double SOFTENING_SQUARED = 1.0; // Softening parameter for repulsion force (epsilon^2)

Point calculateRepulsionBarnesHut(
    BHNode target, FlatQuadTree tree, int rootNodeIndex, double theta, double repulsionConstant) {
  return _calculateRepulsionBarnesHutRecursive(target, tree, rootNodeIndex, theta, repulsionConstant);
}

Point _calculateRepulsionBarnesHutRecursive(
    BHNode target, FlatQuadTree tree, int nodeIndex, double theta, double repulsionConstant) {
  if (nodeIndex == -1 || tree.getNodeMass(nodeIndex) == 0) {
    return Point(0, 0);
  }

  // Get properties from the flat tree
  final double nodeComX = tree.getNodeComX(nodeIndex);
  final double nodeComY = tree.getNodeComY(nodeIndex);
  final double nodeMass = tree.getNodeMass(nodeIndex);
  final double nodeWidth = tree.getNodeWidth(nodeIndex);

  // Vector AWAY from the center of mass (Target - Source)
  final Point nodeCenterOfMass = Point(nodeComX, nodeComY);
  final delta = target.position - nodeCenterOfMass;
  final distance = delta.magnitude;

  // Prevent division by zero and extreme force spikes
  if (distance < 0.5) return Point(0, 0);

  // Barnes-Hut Criterion: Width / Distance < Theta
  // OR if it's a leaf node containing the target itself
  if (tree.getNodeNw(nodeIndex) == -1 || (nodeWidth / distance) < theta) {
    // If it's a leaf node that contains the target, and potentially other points
    if (tree.getNodePointCount(nodeIndex) > 0) {
      bool targetInNode = false;
      int startIndex = tree.getNodePointIndex(nodeIndex);
      for (int i = 0; i < tree.getNodePointCount(nodeIndex); i++) {
        if (tree.getPointID(startIndex + i) == target.id) {
          targetInNode = true;
          break;
        }
      }

      if (targetInNode) {
        // For a leaf containing multiple points, sum repulsion from each
        Point totalRepulsion = Point(0, 0);
        for (int i = 0; i < tree.getNodePointCount(nodeIndex); i++) {
          int pointGlobalIndex = startIndex + i;
          if (tree.getPointID(pointGlobalIndex) != target.id) { // Avoid self-repulsion
            final Point pPosition = Point(tree.getPointX(pointGlobalIndex), tree.getPointY(pointGlobalIndex));
            final pDelta = target.position - pPosition;
            final pDistance = pDelta.magnitude;
            if (pDistance < 0.5) continue;
            final forceMagnitude = (repulsionConstant * 1.0) / (pDistance * pDistance + SOFTENING_SQUARED);
            totalRepulsion = totalRepulsion + (pDelta.normalized() * forceMagnitude);
          }
        }
        return totalRepulsion;
      }
    }
    // If it's an internal node, or a leaf with only other points, treat as single body
    final forceMagnitude = (repulsionConstant * nodeMass) / (distance * distance + SOFTENING_SQUARED);
    return delta.normalized() * forceMagnitude;
  } else {
    // Decompose into quadrants
    return _calculateRepulsionBarnesHutRecursive(target, tree, tree.getNodeNw(nodeIndex), theta, repulsionConstant) +
           _calculateRepulsionBarnesHutRecursive(target, tree, tree.getNodeNe(nodeIndex), theta, repulsionConstant) +
           _calculateRepulsionBarnesHutRecursive(target, tree, tree.getNodeSw(nodeIndex), theta, repulsionConstant) +
           _calculateRepulsionBarnesHutRecursive(target, tree, tree.getNodeSe(nodeIndex), theta, repulsionConstant);
  }
}