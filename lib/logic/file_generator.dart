import 'dart:async';
import 'dart:isolate';

import 'package:flutter_application_1/logic/graph_network.dart';
import 'package:flutter_application_1/logic/isolate_messages.dart';
import 'package:flutter_application_1/logic/file_generator_isolate.dart'; // Import the new isolate entry point

class FileGenerator {
  static final _FileGeneratorIsolateManager _isolateManager = _FileGeneratorIsolateManager();

  static Future<void> exportNodesToCsv(GraphNetwork graph, String filePath) async {
    await _isolateManager.ensureIsolateInitialized();

    final List<Map<String, dynamic>> nodesData = graph.nodes.map((node) => {
          'id': node.id,
          'processingDelay': node.processingDelay,
          'nodeReliability': node.nodeReliability,
        }).toList();

    return _isolateManager.sendCommand(
      ExportNodesCommand(
        filePath: filePath,
        nodesData: nodesData,
      ),
    );
  }

  static Future<void> exportEdgesToCsv(GraphNetwork graph, String filePath) async {
    await _isolateManager.ensureIsolateInitialized();

    final List<Map<String, dynamic>> edgesData = graph.links.map((link) => {
          'sourceId': link.source.id,
          'targetId': link.target.id,
          'bandwidth': link.bandwidth,
          'linkDelay': link.linkDelay,
          'linkReliability': link.linkReliability,
        }).toList();

    return _isolateManager.sendCommand(
      ExportEdgesCommand(
        filePath: filePath,
        edgesData: edgesData,
      ),
    );
  }

  static Future<void> exportDemandToCsv(String filePath, String sourceNodeId, String targetNodeId, double demandMbps) async {
    await _isolateManager.ensureIsolateInitialized();

    return _isolateManager.sendCommand(
      ExportDemandCommand(
        filePath: filePath,
        sourceNodeId: sourceNodeId,
        targetNodeId: targetNodeId,
        demandMbps: demandMbps,
      ),
    );
  }

  static void dispose() {
    _isolateManager.dispose();
  }
}

class _FileGeneratorIsolateManager {
  Isolate? _isolate;
  ReceivePort? _initializerReceivePort; // Port for initial handshake (SendPort)
  SendPort? _isolateSendPort;
  Completer<void> _isolateReady = Completer<void>();

  Future<void> ensureIsolateInitialized() async {
    if (_isolate == null) {
      _initializerReceivePort = ReceivePort();
      // Ensure a fresh completer if we're (re)initializing the isolate
      if (_isolateReady.isCompleted) {
        _isolateReady = Completer<void>();
      }
      _initializerReceivePort!.listen((message) {
        if (message is SendPort) {
          _isolateSendPort = message;
          if (!_isolateReady.isCompleted) { // Failsafe check
            _isolateReady.complete();
          }
        }
      });
      _isolate = await Isolate.spawn(fileGeneratorIsolateEntry, _initializerReceivePort!.sendPort);
      await _isolateReady.future; // Wait for the isolate to send its SendPort
    }
  }

  Future<void> sendCommand(FileGeneratorCommand command) {
    if (_isolateSendPort == null) {
      throw StateError('FileGenerator Isolate not initialized. Call ensureIsolateInitialized first.');
    }

    final Completer<void> commandCompleter = Completer<void>();
    final ReceivePort responsePort = ReceivePort(); // Dedicated port for this command's response

    responsePort.listen((message) {
      if (message is FileExportSuccess) {
        commandCompleter.complete();
        responsePort.close(); // Close port after receiving result
      } else if (message is FileExportFailure) {
        commandCompleter.completeError(Exception(message.error));
        responsePort.close(); // Close port after receiving result
      }
    });

    // Send the command with its own response port
    command.sendPort = responsePort.sendPort; // Assign the SendPort to the command
    _isolateSendPort!.send(command);
    return commandCompleter.future;
  }

  void dispose() {
    _initializerReceivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _initializerReceivePort = null;
    _isolateSendPort = null;
  }
}