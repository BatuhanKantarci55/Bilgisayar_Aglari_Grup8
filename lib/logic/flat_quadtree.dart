import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';

final _random = Random();
const int MAX_DEPTH = 16; // Hard cap recursion depth
const double EPSILON = 1.0; // Microscopic random noise for jitter

/// A simple class to represent a 2D point with basic vector operations.
/// This is an isolate-safe version.
class Point {
  double x, y;
  Point(this.x, this.y);

  Point operator +(Point other) => Point(x + other.x, y + other.y);
  Point operator -(Point other) => Point(x - other.x, y - other.y);
  Point operator *(double scalar) => Point(x * scalar, y * scalar);
  Point operator /(double scalar) {
    if (scalar == 0) return Point(0, 0); // Handle division by zero gracefully
    return Point(x / scalar, y / scalar);
  }

  double get magnitude => sqrt(x * x + y * y);

  Point normalized() {
    final mag = magnitude;
    if (mag == 0) return Point(0, 0);
    return Point(x / mag, y / mag);
  }
}

/// A simple class representing a node for Barnes-Hut algorithm within the isolate.
class BHNode {
  final int id;
  Point position;

  BHNode({required this.id, required this.position});
}

/// A flat array-based quadtree for Barnes-Hut simulation.
///
/// This implementation uses parallel arrays (`Float64List` and `Int32List`)
/// to store quadtree nodes and their properties, aiming to reduce
/// memory thrashing and improve cache locality compared to an OOP-based
/// recursive structure.
class FlatQuadTree {
  // --- Quadtree Constants ---
  static const int MAX_BUILD_RETRIES = 100; // Arbitrary limit for build retries

  // --- Node Properties (Float64List) ---
  // Each node consumes 4 doubles for boundary (left, top, width, height)
  late Float64List _nodeBounds;
  // Each node consumes 2 doubles for center of mass (x, y)
  late Float64List _nodeCenterOfMass;
  // Each node consumes 1 double for total mass
  late Float64List _nodeTotalMass;

  // --- Node Relationships (Int32List) ---
  // Each node consumes 4 ints for children indices (nw, ne, sw, se). -1 for no child.
  late Int32List _nodeChildren;
  // Each node consumes 1 int for the number of points in a leaf node.
  late Int32List _nodePointCount;
  // Each node consumes 1 int for the starting index of points in _pointIDs and _pointPositions.
  late Int32List _nodePointIndices;
  // Each node consumes 1 int for the depth of the node.
  late Int32List _nodeDepth;

  // --- Point Properties (Managed separately for all points in the tree) ---
  // All points' positions (x, y)
  late Float64List _pointPositions;
  // All points' IDs
  late Int32List _pointIDs;

  // Current number of active nodes and points
  int _nextNodeIndex = 0;
  int _nextPointIndex = 0;

  // Maximum number of nodes and points (pre-allocated size)
  final int _maxNodes;
  final int _maxPoints;

  // Root node boundary
  final Rect _rootBoundary;

  FlatQuadTree(int maxNodes, int maxPoints, Rect rootBoundary)
      : _maxNodes = maxNodes,
        _maxPoints = maxPoints,
        _rootBoundary = rootBoundary {
    _nodeBounds = Float64List(maxNodes * 4); // left, top, width, height
    _nodeCenterOfMass = Float64List(maxNodes * 2); // x, y
    _nodeTotalMass = Float64List(maxNodes); // mass

    _nodeChildren = Int32List(maxNodes * 4); // nw, ne, sw, se
    _nodePointCount = Int32List(maxNodes); // count of points in this leaf
    _nodePointIndices = Int32List(maxNodes); // starting index in global _pointIDs/_pointPositions
    _nodeDepth = Int32List(maxNodes); // depth of the node

    _pointPositions = Float64List(maxPoints * 2); // x, y
    _pointIDs = Int32List(maxPoints); // id

    // Initialize children to -1 (no child)
    for (int i = 0; i < _maxNodes * 4; i++) {
      _nodeChildren[i] = -1;
    }
  }

  // Helper getters for node properties
  double getNodeLeft(int nodeIndex) => _nodeBounds[nodeIndex * 4];
  double getNodeTop(int nodeIndex) => _nodeBounds[nodeIndex * 4 + 1];
  double getNodeWidth(int nodeIndex) => _nodeBounds[nodeIndex * 4 + 2];
  double getNodeHeight(int nodeIndex) => _nodeBounds[nodeIndex * 4 + 3];

  double getNodeComX(int nodeIndex) => _nodeCenterOfMass[nodeIndex * 2];
  double getNodeComY(int nodeIndex) => _nodeCenterOfMass[nodeIndex * 2 + 1];
  double getNodeMass(int nodeIndex) => _nodeTotalMass[nodeIndex];

  int getNodeNw(int nodeIndex) => _nodeChildren[nodeIndex * 4];
  int getNodeNe(int nodeIndex) => _nodeChildren[nodeIndex * 4 + 1];
  int getNodeSw(int nodeIndex) => _nodeChildren[nodeIndex * 4 + 2];
  int getNodeSe(int nodeIndex) => _nodeChildren[nodeIndex * 4 + 3];

  int getNodePointCount(int nodeIndex) => _nodePointCount[nodeIndex];
  int getNodePointIndex(int nodeIndex) => _nodePointIndices[nodeIndex];
  int getNodeDepth(int nodeIndex) => _nodeDepth[nodeIndex];

  // Helper getters for point properties
  double getPointX(int pointIndex) => _pointPositions[pointIndex * 2];
  double getPointY(int pointIndex) => _pointPositions[pointIndex * 2 + 1];
  int getPointID(int pointIndex) => _pointIDs[pointIndex];


  /// Resets the quadtree for a new build.
  void clear() {
    _nextNodeIndex = 0;
    _nextPointIndex = 0;
    // No need to clear array contents, they will be overwritten
    // or implicitly handled by _nextNodeIndex and _nextPointIndex.
    // However, children pointers must be reset to -1.
    for (int i = 0; i < _maxNodes * 4; i++) {
      _nodeChildren[i] = -1;
    }
  }

  /// Builds the quadtree from a list of BHNodes.
  /// Returns the index of the root node.
  int build(List<BHNode> nodes) {
    int retries = 0;
    bool success = false;
    int rootIndex = -1; // Initialize to an invalid index

    while (!success && retries < MAX_BUILD_RETRIES) {
      clear(); // Fully resets indices and children
      rootIndex = _createNode(_rootBoundary, 0); // Re-create root node
      success = true; // Assume success for this iteration

      for (var node in nodes) {
        // Attempt to insert each node. If any insertion fails,
        // mark as not successful and break to retry all nodes.
        if (!_insert(rootIndex, node)) {
          success = false;
          break;
        }
      }
      retries++;
    }

    if (!success) {
      // If after max retries, we still couldn't insert all nodes,
      // it indicates a persistent issue. Log a warning with the current state.
      print("Warning: Quadtree build failed after $MAX_BUILD_RETRIES retries. "
            "Some nodes may not be inserted due to extreme overlap or out-of-bounds initial positions. "
            "Number of inserted points: $_nextPointIndex / ${nodes.length}");
      // In this case, the tree might be incomplete, but we proceed with
      // whatever was inserted successfully in the last attempt.
    }
    
    // Update mass and COM only if a root node was successfully created (which it should be after _createNode)
    if (rootIndex != -1) {
      _updateMassAndComRecursive(rootIndex);
    }
    return rootIndex;
  }

  /// Creates a new node and returns its index.
  int _createNode(Rect boundary, int depth) {
    if (_nextNodeIndex >= _maxNodes) {
      throw StateError("Max quadtree nodes reached. Increase _maxNodes.");
    }
    int nodeIndex = _nextNodeIndex++;

    _nodeBounds[nodeIndex * 4] = boundary.left;
    _nodeBounds[nodeIndex * 4 + 1] = boundary.top;
    _nodeBounds[nodeIndex * 4 + 2] = boundary.width;
    _nodeBounds[nodeIndex * 4 + 3] = boundary.height;

    _nodeDepth[nodeIndex] = depth;
    // Initialize mass and COM to zero/null for new nodes
    _nodeTotalMass[nodeIndex] = 0;
    _nodeCenterOfMass[nodeIndex * 2] = 0;
    _nodeCenterOfMass[nodeIndex * 2 + 1] = 0;
    _nodePointCount[nodeIndex] = 0; // No points initially

    return nodeIndex;
  }

  /// Inserts a BHNode into the quadtree, starting from a given nodeIndex.
  bool _insert(int nodeIndex, BHNode bhNode) {
    // If point is outside this quadrant's bounds, ignore it
    Rect boundary = Rect.fromLTWH(getNodeLeft(nodeIndex), getNodeTop(nodeIndex), getNodeWidth(nodeIndex), getNodeHeight(nodeIndex));
    if (!boundary.contains(Offset(bhNode.position.x, bhNode.position.y))) {
      return false;
    }

    // If at max depth or boundary is too small, treat as a leaf and store points
    if (getNodeDepth(nodeIndex) >= MAX_DEPTH || boundary.width < EPSILON * 2 || boundary.height < EPSILON * 2) {
      return _addPointToNode(nodeIndex, bhNode);
    }

    // If this node is currently empty (no children, no points), add the point to it
    if (getNodeNw(nodeIndex) == -1 && getNodePointCount(nodeIndex) == 0) {
      return _addPointToNode(nodeIndex, bhNode);
    }

    // If this node has points but no children, it needs to subdivide
    if (getNodeNw(nodeIndex) == -1 && getNodePointCount(nodeIndex) > 0) {
      _subdivide(nodeIndex);
      // Reinsert existing points into children
      // We need to collect points first, as getNodePointCount(nodeIndex) will change.
      List<BHNode> pointsToReinsert = [];
      for (int i = 0; i < getNodePointCount(nodeIndex); i++) {
        int pointGlobalIndex = getNodePointIndex(nodeIndex) + i;
        pointsToReinsert.add(BHNode(id: getPointID(pointGlobalIndex), position: Point(getPointX(pointGlobalIndex), getPointY(pointGlobalIndex))));
      }
      _nodePointCount[nodeIndex] = 0; // Clear points from this node *before* re-inserting

      for (var existingBhNode in pointsToReinsert) {
        bool reinsertedIntoChild = _insertIntoChildren(nodeIndex, existingBhNode);
        if (!reinsertedIntoChild) {
          // If an existing point could not be re-inserted into any child,
          // attempt to add it back to this node. If this also fails due to jitter,
          // then this `_insert` call itself should return false.
          if (!_addPointToNode(nodeIndex, existingBhNode)) {
            return false; // Point cannot be placed in this node or its children.
          }
        }
      }
    }

    // Now insert the new point into the appropriate child
    bool insertedIntoChild = _insertIntoChildren(nodeIndex, bhNode);
    if (!insertedIntoChild) {
      // If the point could not be inserted into any child (e.g., due to being exactly on a subdivision line,
      // or child at max depth couldn't take it), attempt to add it to the current node as a leaf.
      // If that also fails (due to jittering), then this _insert call must return false.
      if (!_addPointToNode(nodeIndex, bhNode)) {
        return false;
      }
    }
    return true; // Point was successfully added to a child or this node.
  }

  /// Adds a point to a leaf node. Handles jittering if points are too close.
  bool _addPointToNode(int nodeIndex, BHNode bhNode) {
    if (_nextPointIndex >= _maxPoints) {
      throw StateError("Max points reached. Increase _maxPoints.");
    }

    Rect boundary = Rect.fromLTWH(getNodeLeft(nodeIndex), getNodeTop(nodeIndex), getNodeWidth(nodeIndex), getNodeHeight(nodeIndex));

    // Jittering logic (copied from original QuadNode)
    if (getNodePointCount(nodeIndex) > 0) {
      bool needsJitter = false;
      for (int i = 0; i < getNodePointCount(nodeIndex); i++) {
        int existingPointGlobalIndex = getNodePointIndex(nodeIndex) + i;
        if ((bhNode.position.x - getPointX(existingPointGlobalIndex)).abs() < EPSILON &&
            (bhNode.position.y - getPointY(existingPointGlobalIndex)).abs() < EPSILON) {
          needsJitter = true;
          break;
        }
      }
      if (needsJitter) {
        // Apply jitter, but clamp it to stay 0.1 units inside the quadrant boundaries
        // This prevents jittering from pushing a node outside its current quadrant,
        // avoiding an infinite retry loop for peripheral nodes.
        bhNode.position = Point(
          (bhNode.position.x + (_random.nextDouble() - 0.5) * EPSILON)
              .clamp(boundary.left + 0.1, boundary.right - 0.1),
          (bhNode.position.y + (_random.nextDouble() - 0.5) * EPSILON)
              .clamp(boundary.top + 0.1, boundary.bottom - 0.1),
        );
      }
    }

    // If this is the first point for this node, record its starting global index
    if (getNodePointCount(nodeIndex) == 0) {
      _nodePointIndices[nodeIndex] = _nextPointIndex;
    }

    int pointGlobalIndex = _nextPointIndex++;
    _pointPositions[pointGlobalIndex * 2] = bhNode.position.x;
    _pointPositions[pointGlobalIndex * 2 + 1] = bhNode.position.y;
    _pointIDs[pointGlobalIndex] = bhNode.id;
    _nodePointCount[nodeIndex]++;
    return true; // Point successfully added to this node.
  }


  /// Subdivides a node, creating its four children.
  void _subdivide(int nodeIndex) {
    double x = getNodeLeft(nodeIndex);
    double y = getNodeTop(nodeIndex);
    double w = getNodeWidth(nodeIndex) / 2;
    double h = getNodeHeight(nodeIndex) / 2;
    int depth = getNodeDepth(nodeIndex);

    int nwChild = _createNode(Rect.fromLTWH(x, y, w, h), depth + 1);
    int neChild = _createNode(Rect.fromLTWH(x + w, y, w, h), depth + 1);
    int swChild = _createNode(Rect.fromLTWH(x, y + h, w, h), depth + 1);
    int seChild = _createNode(Rect.fromLTWH(x + w, y + h, w, h), depth + 1);

    _nodeChildren[nodeIndex * 4] = nwChild;
    _nodeChildren[nodeIndex * 4 + 1] = neChild;
    _nodeChildren[nodeIndex * 4 + 2] = swChild;
    _nodeChildren[nodeIndex * 4 + 3] = seChild;
  }

  /// Helper to insert points into children nodes.
  bool _insertIntoChildren(int nodeIndex, BHNode bhNode) {
    // Standard quadtree insertion logic using child indices
    int nwChild = getNodeNw(nodeIndex);
    int neChild = getNodeNe(nodeIndex);
    int swChild = getNodeSw(nodeIndex);
    int seChild = getNodeSe(nodeIndex);

    return (_insert(nwChild, bhNode) ||
            _insert(neChild, bhNode) ||
            _insert(swChild, bhNode) ||
            _insert(seChild, bhNode));
  }

  /// Recursively updates total mass and center of mass for a node and its children.
  void _updateMassAndComRecursive(int nodeIndex) {
    if (nodeIndex == -1) return;

    int nwChild = getNodeNw(nodeIndex);
    int neChild = getNodeNe(nodeIndex);
    int swChild = getNodeSw(nodeIndex);
    int seChild = getNodeSe(nodeIndex);

    if (nwChild != -1) { // If it has children, recurse
      _updateMassAndComRecursive(nwChild);
      _updateMassAndComRecursive(neChild);
      _updateMassAndComRecursive(swChild);
      _updateMassAndComRecursive(seChild);
      _updateCenterOfMassFromChildren(nodeIndex);
    } else if (getNodePointCount(nodeIndex) > 0) {
      // It's a leaf node with points, calculate COM from its points
      _updateCenterOfMassFromPoints(nodeIndex);
    }
  }

  /// Recalculates center of mass from children's aggregated masses
  void _updateCenterOfMassFromChildren(int nodeIndex) {
    Point tempCM = Point(0, 0);
    double tempMass = 0;

    void aggregate(int? childIndex) {
      if (childIndex != -1) {
        double childMass = getNodeMass(childIndex!);
        if (childMass > 0) {
          tempCM = tempCM + (Point(getNodeComX(childIndex), getNodeComY(childIndex)) * childMass);
          tempMass += childMass;
        }
      }
    }
    
    aggregate(getNodeNw(nodeIndex)); 
    aggregate(getNodeNe(nodeIndex)); 
    aggregate(getNodeSw(nodeIndex)); 
    aggregate(getNodeSe(nodeIndex));

    if (tempMass > 0) {
      _nodeCenterOfMass[nodeIndex * 2] = tempCM.x / tempMass;
      _nodeCenterOfMass[nodeIndex * 2 + 1] = tempCM.y / tempMass;
      _nodeTotalMass[nodeIndex] = tempMass;
    } else {
      _nodeCenterOfMass[nodeIndex * 2] = 0;
      _nodeCenterOfMass[nodeIndex * 2 + 1] = 0;
      _nodeTotalMass[nodeIndex] = 0;
    }
  }

  /// Recalculates center of mass for multiple points in a leaf node
  void _updateCenterOfMassFromPoints(int nodeIndex) {
    if (getNodePointCount(nodeIndex) == 0) {
      _nodeCenterOfMass[nodeIndex * 2] = 0;
      _nodeCenterOfMass[nodeIndex * 2 + 1] = 0;
      _nodeTotalMass[nodeIndex] = 0;
      return;
    }
    Point sumPositions = Point(0, 0);
    int count = getNodePointCount(nodeIndex);
    int startIndex = getNodePointIndex(nodeIndex);

    for (int i = 0; i < count; i++) {
      int pointGlobalIndex = startIndex + i;
      sumPositions = sumPositions + Point(getPointX(pointGlobalIndex), getPointY(pointGlobalIndex));
    }
    _nodeTotalMass[nodeIndex] = count.toDouble();
    _nodeCenterOfMass[nodeIndex * 2] = sumPositions.x / count;
    _nodeCenterOfMass[nodeIndex * 2 + 1] = sumPositions.y / count;
  }
}
