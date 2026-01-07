import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_application_1/logic/physics_algorithm.dart';

// A. --- Commands Sent FROM Main Thread TO Physics Isolate ---

/// Abstract base class for all commands sent to the physics isolate.
abstract class PhysicsCommand {}

/// Command to initialize and start the physics simulation.
class StartCommand implements PhysicsCommand {
  /// The port to send results back to the main thread.
  final SendPort sendPort;

  /// The initial positions of all nodes, packed as [x0, y0, x1, y1, ...].
  final Float64List initialPositions;
  
  /// The list of links, flattened into a single Int32List: [sourceIdx0, targetIdx0, sourceIdx1, targetIdx1, ...].
  /// This is passed as `TransferableTypedData` for zero-copy transfer.
  final TransferableTypedData linksFlat;

  /// Initial simulation parameters.
  final double stiffness;
  final double repulsion;
  final double damping;
  final double idealLength;
  final bool clockwiseFlow;
  final double width;
  final double height;
  final double barnesHutTheta;
  final PhysicsAlgorithm physicsAlgorithm;
  final bool useQuadtree;

  StartCommand({
    required this.sendPort,
    required this.initialPositions,
    required this.linksFlat,
    required this.stiffness,
    required this.repulsion,
    required this.damping,
    required this.idealLength,
    required this.clockwiseFlow,
    required this.width,
    required this.height,
    required this.barnesHutTheta,
    required this.physicsAlgorithm,
    required this.useQuadtree,
  });
}

/// Command to update the simulation parameters while it's running.
class UpdateParamsCommand implements PhysicsCommand {
  final double? stiffness;
  final double? repulsion;
  final double? damping;
  final double? idealLength;
  final bool? clockwiseFlow;
  final double? width;
  final double? height;
  final double? barnesHutTheta;
  final PhysicsAlgorithm? physicsAlgorithm;
  final bool? useQuadtree;

  UpdateParamsCommand({
    this.stiffness,
    this.repulsion,
    this.damping,
    this.idealLength,
    this.clockwiseFlow,
    this.width,
    this.height,
    this.barnesHutTheta,
    this.physicsAlgorithm,
    this.useQuadtree,
  });
}

/// Command to apply a direct force to a specific node.
/// (As suggested by `code_critique.txt`, for future use e.g., user interaction)
class ApplyForceCommand implements PhysicsCommand {
  final int nodeIndex;
  final double dx;
  final double dy;

  ApplyForceCommand(this.nodeIndex, this.dx, this.dy);
}

/// Command to update the position of a specific node in the physics isolate.
class UpdateNodePositionCommand implements PhysicsCommand {
  final int nodeIndex;
  final double newX;
  final double newY;

  UpdateNodePositionCommand({required this.nodeIndex, required this.newX, required this.newY});
}


/// Command to stop the physics simulation and terminate the isolate.
class StopCommand implements PhysicsCommand {}

class UpdateDimensionsCommand implements PhysicsCommand {
  final double width;
  final double height;

  UpdateDimensionsCommand(this.width, this.height);
}



// B. --- Results Sent FROM Physics Isolate TO Main Thread ---

/// Abstract base class for messages sent from the physics isolate.
abstract class PhysicsResult {}

/// Carries the calculated node positions.
/// This is the primary message sent on every simulation tick.
class PositionsUpdateResult implements PhysicsResult {
  /// The updated positions of all nodes, packed as [x0, y0, x1, y1, ...].
  /// This can be a `TransferableTypedData` for zero-copy transfer.
    final TransferableTypedData positions;

  PositionsUpdateResult(this.positions);
}

/// A message to indicate the isolate has been successfully initialized and is running.
class IsolateReadyResult implements PhysicsResult {}


// C. --- Commands Sent FROM Main Thread TO File Generator Isolate ---

/// Abstract base class for all commands sent to the file generator isolate.
abstract class FileGeneratorCommand {
  late SendPort sendPort; // To send results back to the main thread for this specific command

  FileGeneratorCommand();
}

/// Command to export nodes data to a CSV file.
class ExportNodesCommand extends FileGeneratorCommand {
  final String filePath;
  final List<Map<String, dynamic>> nodesData;

  ExportNodesCommand({
    required this.filePath,
    required this.nodesData,
  });
}

/// Command to export edges data to a CSV file.
class ExportEdgesCommand extends FileGeneratorCommand {
  final String filePath;
  final List<Map<String, dynamic>> edgesData;

  ExportEdgesCommand({
    required this.filePath,
    required this.edgesData,
  });
}

/// Command to export demand data to a CSV file.
class ExportDemandCommand extends FileGeneratorCommand {
  final String filePath;
  final String sourceNodeId;
  final String targetNodeId;
  final double demandMbps;

  ExportDemandCommand({
    required this.filePath,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.demandMbps,
  });
}

/// Command to import nodes data from a CSV file.
class ImportNodesCommand extends FileGeneratorCommand {
  final String filePath;

  ImportNodesCommand({required this.filePath});
}

/// Command to import edges data from a CSV file.
class ImportEdgesCommand extends FileGeneratorCommand {
  final String filePath;

  ImportEdgesCommand({required this.filePath});
}

// D. --- Results Sent FROM File Generator Isolate TO Main Thread ---

/// Abstract base class for messages sent from the file generator isolate.
abstract class FileGeneratorResult {}

/// Indicates successful file export.
class FileExportSuccess implements FileGeneratorResult {}

/// Indicates failure during file export.
class FileExportFailure implements FileGeneratorResult {
  final String error;
  FileExportFailure(this.error);
}

/// Indicates successful file import with data.
class FileImportSuccessWithData implements FileGeneratorResult {
  final List<Map<String, dynamic>> data;
  FileImportSuccessWithData(this.data);
}