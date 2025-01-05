import 'dart:io';
import 'package:html/dom.dart';
import 'package:process_run/shell.dart';
import 'package:csv/csv.dart';
import 'package:html/parser.dart' show parse;
import 'package:path/path.dart' as path;

// Command Line Interface
void printUsage() {
  print('''
Usage: dart run format_table.dart -i <file> [options]
Required:
  -i, --input <file>     Input TSV file
Options:
  -o, --output <file>    Output PNG file (default: input_file_name.png)
  --landscape            Generate landscape output (default: portrait)
  --merge-cols <cols>    Comma-separated list of column indexes (e.g., 4,5) to merge empty cells with cells above
  -h, --help            Show this help message
''');
}

class TableData {
  final List<String> headerRow;
  final List<List<String>> rows;

  TableData({required this.headerRow, required this.rows});
}

// Data Processing
class TableDataProcessor {
  static TableData processTableData(String content) {
    final csvConverter = CsvToListConverter(
      fieldDelimiter: '\t',
      eol: '\n',
      shouldParseNumbers: false,
    );
    final allRows = csvConverter.convert(content);
    final lines = allRows
        .where((row) => row.any((cell) => cell.toString().isNotEmpty))
        .toList();

    if (lines.isEmpty) {
      throw Exception('No data found in the input file');
    }

    final headerRow = lines.first.map((cell) => cell.toString()).toList();
    final expectedColumns = headerRow.length;

    final dataRows = lines
        .skip(1)
        .map((row) {
          final processedCells = row.map((cell) => cell.toString()).toList();
          // Trim any extra columns beyond the header length
          if (processedCells.length > expectedColumns) {
            processedCells.length = expectedColumns;
          }
          // Add empty cells if row is shorter than header
          while (processedCells.length < expectedColumns) {
            processedCells.add('');
          }
          return processedCells;
        })
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();

    return TableData(headerRow: headerRow, rows: dataRows);
  }
}

// HTML Generation
class HtmlGenerator {
  static String generateHtml(TableData tableData, Set<int> mergeCols,
      {bool isLandscape = false}) {
    // First generate basic HTML without any merging
    final html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            ${_getStyles(isLandscape)}
        </style>
    </head>
    <body>
    <table>
    ${_generateHeaderRow(tableData.headerRow)}
    ${_generateTableBody(tableData.rows)}
    </table>
    </body>
    </html>
    ''';

    // Apply merging as post-processing if needed
    if (mergeCols.isNotEmpty) {
      return _postProcessMergeCols(html, mergeCols);
    }
    return html;
  }

  static String _generateHeaderRow(List<String> headerRow) {
    return '''
    <tr class="header-row">
        ${headerRow.map((cell) => '<th>$cell</th>').join('\n')}
    </tr>''';
  }

  static String _generateTableBody(List<List<String>> rows) {
    return rows.map((row) {
      // Check if this is a section header (only first column has content)
      bool isSectionHeader =
          row[0].isNotEmpty && row.skip(1).every((cell) => cell.isEmpty);

      if (isSectionHeader) {
        return '''
        <tr class="section-header">
          <td colspan="${row.length}">${row[0]}</td>
        </tr>''';
      }

      final cells = row.map((cell) => '<td>$cell</td>').join();
      return '''
      <tr>$cells</tr>''';
    }).join('\n');
  }

  static String _postProcessMergeCols(String html, Set<int> mergeCols) {
    final document = parse(html);
    final rows = document.getElementsByTagName('tr').toList();
    final headerRow = rows.removeAt(0); // Remove header row from processing

    // Process each merge column
    for (final colIndex in mergeCols) {
      var currentValue = '';
      var currentStartRow = -1;
      var currentSpan = 0;

      // First pass: calculate spans
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final cells = rows[rowIndex].getElementsByTagName('td');
        if (cells.length <= colIndex) continue;

        final cellValue = cells[colIndex].text;

        if (cellValue.isNotEmpty) {
          // If we have an active span and encounter a new value, finalize the previous span
          if (currentSpan > 1) {
            final startCell =
                rows[currentStartRow].getElementsByTagName('td')[colIndex];
            startCell.attributes['rowspan'] = currentSpan.toString();

            // Remove spanned cells
            for (var i = currentStartRow + 1; i < rowIndex; i++) {
              final rowCells = rows[i].getElementsByTagName('td');
              if (rowCells.length > colIndex) {
                rowCells[colIndex].remove();
              }
            }
          }

          // Start new span
          if (cellValue != currentValue) {
            currentValue = cellValue;
            currentStartRow = rowIndex;
            currentSpan = 1;
          } else {
            currentSpan++;
          }
        } else if (currentStartRow >= 0) {
          // Empty cell, extend current span if we have one
          currentSpan++;
        }
      }

      // Handle the last span if it exists
      if (currentSpan > 1) {
        final startCell =
            rows[currentStartRow].getElementsByTagName('td')[colIndex];
        startCell.attributes['rowspan'] = currentSpan.toString();

        // Remove spanned cells
        for (var i = currentStartRow + 1; i < rows.length; i++) {
          final rowCells = rows[i].getElementsByTagName('td');
          if (rowCells.length > colIndex) {
            rowCells[colIndex].remove();
          }
        }
      }
    }

    // Reconstruct the table with the header
    final table = document.getElementsByTagName('table').first;
    table.nodes.clear();
    table.append(headerRow);
    rows.forEach(table.append);

    return document.outerHtml;
  }

  static String _getStyles(bool isLandscape) {
    return '''
            body {
                font-family: Arial, sans-serif;
                margin: 20px;
                color: #333;
            }
            .header-row {
                background-color: #f5f5f5;
                font-weight: bold;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 20px;
                font-size: ${isLandscape ? '11px' : '12px'};
                break-inside: avoid;
                page-break-inside: avoid;
            }
            th {
                background-color: #f5f5f5;
                border: 1px solid #ddd;
                padding: 8px;
                text-align: left;
                font-weight: bold;
            }
            td {
                border: 1px solid #ddd;
                padding: 8px;
                text-align: left;
                vertical-align: top;
            }
            tr {
                break-inside: avoid;
                page-break-inside: avoid;
            }
            tr:nth-child(even):not(.section-header) {
                background-color: #fafafa;
            }
            .section-header {
                background-color: #e0e0e0 !important;
                font-weight: bold;
                font-size: 1.1em;
            }
            .section-header td {
                padding: 12px 8px;
            }
    ''';
  }
}

// File Operations
class FileOperations {
  static Future<void> cleanupOldOutputs(String outputFile) async {
    // Get the base name without extension
    final baseName = outputFile.replaceAll(RegExp(r'\.png$'), '');

    // Create the pattern to match base name followed by optional -number and .png
    final pattern = RegExp('^${RegExp.escape(baseName)}(?:-\\d+)?\\.png\$');

    final dir = Directory(path.dirname(outputFile));
    await for (final file in dir.list()) {
      if (file is File && pattern.hasMatch(path.basename(file.path))) {
        await file.delete();
      }
    }
  }

  static Future<void> convertToOutput(String htmlContent, String outputFile,
      {bool isLandscape = false}) async {
    await cleanupOldOutputs(outputFile);
    await File('temp.html').writeAsString(htmlContent);

    var shell = Shell();
    await shell.run('''
      wkhtmltopdf --enable-local-file-access ${isLandscape ? '--orientation Landscape' : ''} --page-size A4 --margin-top 0 --margin-right 0 --margin-bottom 0 --margin-left 0 --disable-smart-shrinking --zoom 1.0 temp.html temp.pdf
    ''');

    await shell.run('''
      convert -density 300 'temp.pdf' -trim -quality 100 '$outputFile'
''');
  }
}

void main(List<String> args) async {
  // Parse command line arguments
  String? inputFile;
  String? outputFile;
  bool isLandscape = false;
  Set<int> mergeCols = {};

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--input':
      case '-i':
        if (i + 1 < args.length) {
          inputFile = args[++i];
        }
        break;
      case '--output':
      case '-o':
        if (i + 1 < args.length) {
          outputFile = args[++i];
        }
        break;
      case '--landscape':
        isLandscape = true;
        break;
      case '--merge-cols':
        if (i + 1 < args.length) {
          mergeCols = args[++i]
              .split(RegExp(r'[,\s]+')) // Split on comma or whitespace
              .map((s) => int.tryParse(s.trim()))
              .where((n) => n != null)
              .map((n) => n!)
              .toSet();
        }
        break;
      case '--help':
      case '-h':
        printUsage();
        exit(0);
      case '--test':
        print('For running tests, use: dart run format_table_test.dart');
        exit(0);
      default:
        if (args[i].startsWith('-')) {
          print('Unknown option: ${args[i]}');
          printUsage();
          exit(1);
        }
    }
  }

  // Check required arguments
  if (inputFile == null) {
    print('Error: --input argument is required');
    printUsage();
    exit(1);
  }

  // If output file is not specified, use input filename with .png extension
  if (outputFile == null) {
    final inputBaseName = inputFile.contains('.')
        ? inputFile.substring(0, inputFile.lastIndexOf('.'))
        : inputFile;
    outputFile = '$inputBaseName.png';
    print('No output file specified, using: $outputFile');
  }

  try {
    final content = await File(inputFile).readAsString();
    final tableData = TableDataProcessor.processTableData(content);

    // Generate HTML with post-processing for merge columns
    final html = HtmlGenerator.generateHtml(
      tableData,
      mergeCols,
      isLandscape: isLandscape,
    );

    await FileOperations.convertToOutput(html, outputFile,
        isLandscape: isLandscape);

    print('Done! Output saved to $outputFile');
    print(
        'Temporary files temp.html and temp.pdf have been preserved for debugging');
    print('Output format: ${isLandscape ? 'Landscape' : 'Portrait'}');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
