import 'dart:io';
import 'dart:isolate';
import 'package:flutter_application_1/logic/isolate_messages.dart';

/// The entry point for the file generator isolate.
/// It listens for commands from the main isolate and performs file export operations.
void fileGeneratorIsolateEntry(SendPort mainSendPort) {
  final ReceivePort isolateReceivePort = ReceivePort();
  mainSendPort.send(isolateReceivePort.sendPort);

  isolateReceivePort.listen((dynamic message) async {
    if (message is ExportNodesCommand) {
      try {
        final file = File(message.filePath);
        final buffer = StringBuffer();

        // Write header
        buffer.writeln('node_id;s_ms;r_node');

        // Write node data
        for (final nodeData in message.nodesData) {
          final nodeId = nodeData['id'].toString().split('_').last;
          final sMs = nodeData['processingDelay'].toStringAsFixed(2).replaceFirst('.', ',');
          final rNode = nodeData['nodeReliability'].toStringAsFixed(3).replaceFirst('.', ',');
          buffer.writeln('$nodeId;$sMs;$rNode');
        }

        await file.writeAsString(buffer.toString());
        message.sendPort.send(FileExportSuccess());
      } catch (e) {
        message.sendPort.send(FileExportFailure('Failed to export nodes: $e'));
      }
    } else if (message is ExportEdgesCommand) {
      try {
        final file = File(message.filePath);
        final buffer = StringBuffer();

        // Write header
        buffer.writeln('src;dst;capacity_mbps;delay_ms;r_link');

        // Write link (edge) data
        for (final edgeData in message.edgesData) {
          // print('Writing edgeData: $edgeData');
          final srcId = edgeData['sourceId'].toString().split('_').last;
          final dstId = edgeData['targetId'].toString().split('_').last;
          final bandwidth = edgeData['bandwidth'].toStringAsFixed(0);
          final delayMs = edgeData['linkDelay'].toStringAsFixed(0);
          final rLink = edgeData['linkReliability'].toStringAsFixed(3).replaceFirst('.', ',');
          buffer.writeln('$srcId;$dstId;$bandwidth;$delayMs;$rLink');
        }

        await file.writeAsString(buffer.toString());
        print('Finished writing edges.csv'); // Keep this original print
        message.sendPort.send(FileExportSuccess());
      } catch (e, s) {
        print('Error writing edges.csv: $e');
        print(s);
        message.sendPort.send(FileExportFailure('Failed to export edges: $e'));
      }
    } else if (message is ExportDemandCommand) {
      try {
        final file = File(message.filePath);
        final buffer = StringBuffer();

        // Write header
        buffer.writeln('src;dst;demand_mbps');

        // Write demand data
        final srcId = message.sourceNodeId.split('_').last;
        final dstId = message.targetNodeId.split('_').last;
        final demandMbps = message.demandMbps.toStringAsFixed(0);

        buffer.writeln('$srcId;$dstId;$demandMbps');

        await file.writeAsString(buffer.toString());
        message.sendPort.send(FileExportSuccess());
      } catch (e) {
        message.sendPort.send(FileExportFailure('Failed to export demand data: $e'));
      }
    }
  });
}
