import 'dart:io';
import 'package:csv/csv.dart';


class FileRead {
  /// Helper function to read a CSV file and parse its content.
  /// Handles semicolon as delimiter and converts specific number formats.
  static Future<List<Map<String, dynamic>>> _readCsvFile(
      String filePath, List<String> columns, {String fieldDelimiter = ';'}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final input = await file.readAsString();

    List<List<dynamic>> csvTable = CsvToListConverter(
      fieldDelimiter: fieldDelimiter,
      eol: '\n', // Explicitly specify the end-of-line character
    ).convert(input);

    if (csvTable.isEmpty) {
      return [];
    }

    // Assuming the first row is the header, but using provided columns for mapping
    final List<Map<String, dynamic>> result = [];
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      if (row.length != columns.length) {
        // Warning log for row parsing issues, useful to keep
        // debugPrint('FileRead: Warning for $filePath: Row ${i + 1} has ${row.length} columns, expected ${columns.length}. Content: ${row.toString()}. Skipping row.');
        continue;
      }
      final Map<String, dynamic> rowMap = {};
      for (int j = 0; j < columns.length; j++) {
        rowMap[columns[j]] = row[j];
      }
      result.add(rowMap);
    }
    return result;
  }

  /// Reads and parses the nodes.csv file.
  /// Expected columns: 'node_id', 's_ms', 'r_node'
  static Future<List<Map<String, dynamic>>> readNodesCsv(String filePath) async {
    final rawData = await _readCsvFile(filePath, ['node_id', 's_ms', 'r_node']);
    final mappedData = rawData.map((row) {
      return {
        'id': 'node_${row['node_id']}',
        // Replace comma with dot for proper double parsing
        'processingDelay': double.tryParse(row['s_ms'].toString().replaceFirst(',', '.')),
        'nodeReliability': double.tryParse(row['r_node'].toString().replaceFirst(',', '.')),
      };
    }).toList();
    return mappedData;
  }

  /// Reads and parses the edges.csv file.
  /// Expected columns: 'src', 'dst', 'capacity_mbps', 'delay_ms', 'r_link'
  static Future<List<Map<String, dynamic>>> readEdgesCsv(String filePath) async {
    final rawData = await _readCsvFile(filePath, ['src', 'dst', 'capacity_mbps', 'delay_ms', 'r_link']);
    final mappedData = rawData.map((row) {
      return {
        'sourceId': 'node_${row['src']}',
        'targetId': 'node_${row['dst']}',
        'bandwidth': double.tryParse(row['capacity_mbps'].toString()),
        'linkDelay': double.tryParse(row['delay_ms'].toString()),
        'linkReliability': double.tryParse(row['r_link'].toString().replaceFirst(',', '.')),
      };
    }).toList();
    return mappedData;
  }

  /// Reads and parses a path CSV file, expecting a single 'node_id' column.
  /// Returns a list of node IDs (strings).
  static Future<List<String>> readPathCsv(String filePath) async {
    final rawData = await _readCsvFile(filePath, ['step', 'node_id'], fieldDelimiter: ',');
    rawData.sort((a, b) => int.parse(a['step'].toString()).compareTo(int.parse(b['step'].toString())));
    rawData.sort((a, b) => int.parse(a['step'].toString()).compareTo(int.parse(b['step'].toString())));
    return rawData.map((row) => 'node_${row['node_id'].toString().trim()}').toList();
  }

  /// Reads a CSV file and returns its raw content as a single string.
  static Future<String> readCsvContentAsString(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return 'File not found: $filePath';
    }
    return await file.readAsString();
  }
}