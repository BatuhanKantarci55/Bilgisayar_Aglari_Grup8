import 'dart:math';

class Point {
  final double x, y;
  Point(this.x, this.y);
}

enum Direction { north, south, east, west }

class FMM {
  late FMMNode root;
  List<Point> particles;
  late List<Force> forces;

  FMM({required this.particles}) {
    forces = List.generate(particles.length, (_) => Force(0, 0));
    _buildTree();
  }

  void _buildTree() {
    final boundingBox = _calculateBoundingBox(particles);
    root = FMMNode(boundingBox.center, boundingBox.sideLength);
    for (final particle in particles) {
      root.addParticle(particle);
    }
  }

  BoundingBox _calculateBoundingBox(List<Point> particles) {
    if (particles.isEmpty) {
      return BoundingBox(Point(0, 0), 0);
    }

    double minX = particles[0].x;
    double maxX = particles[0].x;
    double minY = particles[0].y;
    double maxY = particles[0].y;

    for (int i = 1; i < particles.length; i++) {
      minX = min(minX, particles[i].x);
      maxX = max(maxX, particles[i].x);
      minY = min(minY, particles[i].y);
      maxY = max(maxY, particles[i].y);
    }

    final center = Point((minX + maxX) / 2, (minY + maxY) / 2);
    final sideLength = max(maxX - minX, maxY - minY);
    return BoundingBox(center, sideLength);
  }

  void run() {
    root.calculateMultipoleExpansion();
    _downwardPass(root);
  }

  void _downwardPass(FMMNode node) {
    _calculateLocalExpansions(node);
    _calculateParticleForces(node);
  }

  void _calculateLocalExpansions(FMMNode node) {
    if (node.isLeaf) return;

    for (final child in node.children) {
      // L2L: parent's local expansion to child's local expansion
      _l2l(node, child);
      
      // M2L: interaction list's multipole to child's local
      final interactionList = _getInteractionList(child);
      for (final interationNode in interactionList) {
        _m2l(interationNode, child);
      }

      _calculateLocalExpansions(child);
    }
  }

  void _calculateParticleForces(FMMNode node) {
    if (node.isLeaf) {
      // P2P: direct calculation for neighbors
      final neighbors = _getNeighbors(node);
      for (final neighbor in neighbors) {
        for (final p1 in node.particles) {
          for (final p2 in neighbor.particles) {
            final dx = p1.x - p2.x;
            final dy = p1.y - p2.y;
            final r2 = dx * dx + dy * dy;
            if (r2 == 0) continue;
            final r = sqrt(r2);
            final force = 1.0 / r2;
            final particleIndex1 = particles.indexOf(p1);
            final particleIndex2 = particles.indexOf(p2);
            forces[particleIndex1].fx += force * dx / r;
            forces[particleIndex1].fy += force * dy / r;
            forces[particleIndex2].fx -= force * dx / r;
            forces[particleIndex2].fy -= force * dy / r;
          }
        }
      }
      // P2L: use local expansion for far fields
      for (final particle in node.particles) {
        final dx = particle.x - node.center.x;
        final dy = particle.y - node.center.y;
        final r2 = dx * dx + dy * dy;
        if (r2 == 0) continue;
        final r = sqrt(r2);
        final potential = node.localCoefficients[0];
        final force = potential / r2;
        final particleIndex = particles.indexOf(particle);
        forces[particleIndex].fx += force * dx / r;
        forces[particleIndex].fy += force * dy / r;
      }
    } else {
      for (final child in node.children) {
        _calculateParticleForces(child);
      }
    }
  }
  
  List<FMMNode> _getInteractionList(FMMNode node) {
    // a node's interaction list consists of the children of its parent's neighbors 
    // that are well-separated from the node.
    final interactionList = <FMMNode>[];
    if (node.parent == null) return interactionList;

    final parentNode = node.parent;
    if (parentNode == null) return interactionList;

    final parentNeighbors = [
      _getAdjoiningNode(parentNode, Direction.north),
      _getAdjoiningNode(parentNode, Direction.south),
      _getAdjoiningNode(parentNode, Direction.east),
      _getAdjoiningNode(parentNode, Direction.west),
    ];

    for (final neighbor in parentNeighbors) {
      if (neighbor == null) continue;
      for (final neighborChild in neighbor.children) {
        if (node._areWellSeparated(neighborChild)) {
          interactionList.add(neighborChild);
        }
      }
    }
    return interactionList;
  }

  List<FMMNode> _getNeighbors(FMMNode node) {
    final neighbors = <FMMNode>[];
    for (final direction in Direction.values) {
      final adjoiningNode = _getAdjoiningNode(node, direction);
      if (adjoiningNode != null) {
        neighbors.addAll(adjoiningNode._getLeaves());
      }
    }
    return neighbors;
  }

  FMMNode? _getAdjoiningNode(FMMNode node, Direction direction) {
    if (node.parent == null) return null;

    final parent = node.parent!;
    final childIndex = parent.children.indexOf(node);

    FMMNode? candidate;

    switch (direction) {
      case Direction.north:
        if (childIndex == 2) candidate = parent.children[0];
        if (childIndex == 3) candidate = parent.children[1];
        break;
      case Direction.south:
        if (childIndex == 0) candidate = parent.children[2];
        if (childIndex == 1) candidate = parent.children[3];
        break;
      case Direction.east:
        if (childIndex == 0) candidate = parent.children[1];
        if (childIndex == 2) candidate = parent.children[3];
        break;
      case Direction.west:
        if (childIndex == 1) candidate = parent.children[0];
        if (childIndex == 3) candidate = parent.children[2];
        break;
    }

    if (candidate != null) return candidate;

    final adjoiningParent = _getAdjoiningNode(parent, direction);
    if (adjoiningParent == null || adjoiningParent.isLeaf) return adjoiningParent;

    switch (direction) {
      case Direction.north:
        if (childIndex == 0) return adjoiningParent.children[2];
        if (childIndex == 1) return adjoiningParent.children[3];
        break;
      case Direction.south:
        if (childIndex == 2) return adjoiningParent.children[0];
        if (childIndex == 3) return adjoiningParent.children[1];
        break;
      case Direction.east:
        if (childIndex == 2) return adjoiningParent.children[2];
        if (childIndex == 3) return adjoiningParent.children[3];
        break;
      case Direction.west:
        if (childIndex == 0) return adjoiningParent.children[1];
        if (childIndex == 1) return adjoiningParent.children[0];
        break;
    }
    return null;
  }

  void _l2l(FMMNode parent, FMMNode child) {
    if (parent.localCoefficients.isEmpty) return;
    final dx = parent.center.x - child.center.x;
    final dy = parent.center.y - child.center.y;
    final r2 = dx * dx + dy * dy;
    if (r2 == 0) return;
    
    // Simple monopole shift
    child.localCoefficients[0] += parent.localCoefficients[0];
  }

  void _m2l(FMMNode sourceNode, FMMNode targetNode) {
    final dx = sourceNode.center.x - targetNode.center.x;
    final dy = sourceNode.center.y - targetNode.center.y;
    final r2 = dx * dx + dy * dy;
    if (r2 == 0) return;

    final r = sqrt(r2);
    // Simple monopole conversion
    targetNode.localCoefficients[0] += sourceNode.charge / r;
  }
}

class BoundingBox {
  Point center;
  double sideLength;

  BoundingBox(this.center, this.sideLength);
}

class FMMNode {
  static const int maxParticlesPerNode = 1;
  static const int maxDepth = 20;

  Point center;
  double sideLength;
  FMMNode? parent;
  int depth;
  List<Point> particles = [];
  List<FMMNode> children = [];

  // [charge, dx, dy] for multipole
  // [potential, fx, fy] for local
  List<double> multipoleCoefficients = [];
  List<double> localCoefficients = [0, 0, 0];

  double get charge => multipoleCoefficients.isNotEmpty ? multipoleCoefficients[0] : 0;

  bool get isLeaf => children.isEmpty;

  FMMNode(this.center, this.sideLength, {this.parent, this.depth = 0});
  
  void addParticle(Point particle) {
    if (isLeaf) {
      if (particles.length < maxParticlesPerNode || depth >= maxDepth) {
        particles.add(particle);
        return;
      } else {
        subdivide();
        _addParticleToChildren(particle);
        return;
      }
    }
    _addParticleToChildren(particle);
  }

  void subdivide() {
    final halfSide = sideLength / 2;
    final quarterSide = sideLength / 4;

    children = [
      FMMNode(Point(center.x - quarterSide, center.y - quarterSide), halfSide, parent: this, depth: depth + 1),
      FMMNode(Point(center.x + quarterSide, center.y - quarterSide), halfSide, parent: this, depth: depth + 1),
      FMMNode(Point(center.x - quarterSide, center.y + quarterSide), halfSide, parent: this, depth: depth + 1),
      FMMNode(Point(center.x + quarterSide, center.y + quarterSide), halfSide, parent: this, depth: depth + 1),
    ];

    final existingParticles = List<Point>.from(particles);
    particles.clear();

    for (final particle in existingParticles) {
      _addParticleToChildren(particle);
    }
  }
  
  void _addParticleToChildren(Point particle) {
    for (final child in children) {
      if (child.contains(particle)) {
        child.addParticle(particle);
        return;
      }
    }
  }

  bool contains(Point point) {
    final halfSide = sideLength / 2;
    return point.x >= center.x - halfSide &&
        point.x <= center.x + halfSide &&
        point.y >= center.y - halfSide &&
        point.y <= center.y + halfSide;
  }

  void calculateMultipoleExpansion() {
    if (isLeaf) {
      // P2M: Particle to Multipole
      double totalCharge = 0;
      double dx = 0;
      double dy = 0;
      for (final particle in particles) {
        totalCharge += 1.0; // Assuming charge is 1.0
        dx += particle.x - center.x;
        dy += particle.y - center.y;
      }
      multipoleCoefficients = [totalCharge, dx, dy];
    } else {
      // M2M: Multipole to Multipole
      for (final child in children) {
        child.calculateMultipoleExpansion();
      }

      double totalCharge = 0;
      double dx = 0;
      double dy = 0;
      for (final child in children) {
        totalCharge += child.charge;
        final childDx = child.multipoleCoefficients[1];
        final childDy = child.multipoleCoefficients[2];
        final childCenterDx = child.center.x - center.x;
        final childCenterDy = child.center.y - center.y;
        dx += child.charge * childCenterDx + childDx;
        dy += child.charge * childCenterDy + childDy;
      }
      multipoleCoefficients = [totalCharge, dx, dy];
    }
  }

  bool _areWellSeparated(FMMNode other) {
    final dx = center.x - other.center.x;
    final dy = center.y - other.center.y;
    final distance = sqrt(dx * dx + dy * dy);
    return sideLength / distance < 0.5; // multipole acceptance criterion
  }

  List<FMMNode> _getLeaves() {
    if (isLeaf) {
      return [this];
    } else {
      final leaves = <FMMNode>[];
      for (final child in children) {
        leaves.addAll(child._getLeaves());
      }
      return leaves;
    }
  }
}

class Force {
  double fx, fy;
  Force(this.fx, this.fy);
}