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

// Models
class RowSpanInfo {
  final int startIndex;
  final int rowSpan;
  final String value;

  RowSpanInfo({
    required this.startIndex,
    required this.rowSpan,
    required this.value,
  });
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
    final dataRows = lines
        .skip(1)
        .map((row) {
          final processedCells = row.map((cell) => cell.toString()).toList();
          while (processedCells.length < headerRow.length) {
            processedCells.add('');
          }
          return processedCells;
        })
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();

    return TableData(headerRow: headerRow, rows: dataRows);
  }
}

// Rowspan Calculation
class RowspanCalculator {
  static Map<int, List<RowSpanInfo>> calculateRowspans(
      List<List<String>> rows, Set<int> mergeCols) {
    final columnRowSpans = <int, List<RowSpanInfo>>{};

    for (final colIndex in mergeCols) {
      final spans = <RowSpanInfo>[];
      var currentValue = '';
      var spanStartIndex = -1;
      var currentSpan = 0;

      for (var i = 0; i < rows.length; i++) {
        final cell = rows[i][colIndex];

        if (cell.isNotEmpty && cell != currentValue) {
          // Add previous span if it exists
          if (currentSpan > 1) {
            spans.add(RowSpanInfo(
              startIndex: spanStartIndex,
              rowSpan: currentSpan,
              value: currentValue,
            ));
          }
          // Start new span
          currentValue = cell;
          spanStartIndex = i;
          currentSpan = 1;
        } else if (cell.isEmpty && spanStartIndex >= 0) {
          currentSpan++;
        } else if (cell.isNotEmpty && cell == currentValue) {
          // Handle consecutive rows with the same non-empty value
          if (spanStartIndex == -1) {
            spanStartIndex = i;
            currentSpan = 1;
          } else {
            currentSpan++;
          }
        }
      }

      // Add the final span if it exists
      if (currentSpan > 1) {
        spans.add(RowSpanInfo(
          startIndex: spanStartIndex,
          rowSpan: currentSpan,
          value: currentValue,
        ));
      }

      columnRowSpans[colIndex] = spans;
    }

    return columnRowSpans;
  }
}

// HTML Generation
class HtmlGenerator {
  static String generateHtml(TableData tableData,
      Map<int, List<RowSpanInfo>> columnRowSpans, Set<int> mergeCols,
      {bool isLandscape = false}) {
    final headerHtml = _generateHeaderRow(tableData.headerRow);
    final bodyHtml =
        _generateTableBody(tableData.rows, columnRowSpans, mergeCols);

    return '''
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
    $headerHtml
    $bodyHtml
    </table>
    </body>
    </html>
    ''';
  }

  static String _generateHeaderRow(List<String> headerRow) {
    return '''
    <tr class="header-row">
        ${headerRow.map((cell) => '<th>$cell</th>').join('\n')}
    </tr>''';
  }

  static String _generateTableBody(List<List<String>> rows,
      Map<int, List<RowSpanInfo>> columnRowSpans, Set<int> mergeCols) {
    // Track active rowspans
    var activeRowspans = <int, int>{}; // column index -> remaining rows

    return rows.asMap().entries.map((rowEntry) {
      final rowIndex = rowEntry.key;
      final row = rowEntry.value;
      var currentCol = 0;
      var cells = <String>[];

      // First handle active rowspans
      for (var col = 0; col < row.length; col++) {
        if (activeRowspans.containsKey(col) && activeRowspans[col]! > 0) {
          activeRowspans[col] = activeRowspans[col]! - 1;
          continue; // Skip this column as it's being spanned
        }

        final value = row[col];
        if (mergeCols.contains(col)) {
          final spans = columnRowSpans[col] ?? [];
          var spanFound = false;
          for (final span in spans) {
            if (rowIndex == span.startIndex) {
              cells.add('<td rowspan="${span.rowSpan}">$value</td>');
              activeRowspans[col] = span.rowSpan - 1;
              spanFound = true;
              break;
            }
          }
          if (!spanFound && !activeRowspans.containsKey(col)) {
            cells.add('<td>$value</td>');
          }
        } else {
          cells.add('<td>$value</td>');
        }
      }

      return '''
      <tr>${cells.join()}</tr>''';
    }).join('\n');
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
            tr:nth-child(even) {
                background-color: #fafafa;
            }
    ''';
  }
}

// Validation
class TableValidator {
  static void validateStructure(String htmlContent) {
    final document = parse(htmlContent);
    final rows = document.getElementsByTagName('tr');
    final headerCells = rows.first.getElementsByTagName('th');
    final expectedColumns = headerCells.length;

    // Track active rowspans
    var activeRowspans = <int, int>{}; // column index -> remaining rows

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final cells = row.getElementsByTagName('td');
      var effectiveColumnCount = 0;
      var currentCol = 0;

      // Count active rowspans from previous rows
      for (var col = 0; col < expectedColumns; col++) {
        if (activeRowspans.containsKey(col) && activeRowspans[col]! > 0) {
          effectiveColumnCount++;
          activeRowspans[col] = activeRowspans[col]! - 1;
        }
      }

      // Process current row's cells
      for (final cell in cells) {
        // Skip columns that are currently being spanned
        while (currentCol < expectedColumns &&
            activeRowspans.containsKey(currentCol) &&
            activeRowspans[currentCol]! > 0) {
          currentCol++;
        }

        if (currentCol >= expectedColumns) break;

        final rowspan = int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 1;
        if (rowspan > 1) {
          activeRowspans[currentCol] = rowspan - 1;
          effectiveColumnCount++;
        } else {
          effectiveColumnCount++;
        }
        currentCol++;
      }

      if (effectiveColumnCount != expectedColumns) {
        throw Exception(
            'Row ${i + 1} has $effectiveColumnCount columns, expected $expectedColumns');
      }
    }
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

// Main function remains mostly the same but uses these components
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

    // Process the data
    final tableData = TableDataProcessor.processTableData(content);

    // Calculate rowspans
    final columnRowSpans =
        RowspanCalculator.calculateRowspans(tableData.rows, mergeCols);

    // Generate HTML
    final html = HtmlGenerator.generateHtml(
        tableData, columnRowSpans, mergeCols,
        isLandscape: isLandscape);

    // Validate
    TableValidator.validateStructure(html);

    // Convert to output
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
