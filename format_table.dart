import 'dart:io';
import 'package:html/dom.dart';
import 'package:process_run/shell.dart';
import 'package:csv/csv.dart';
import 'package:html/parser.dart' show parse;

void printUsage() {
  print('''
Usage: dart run format_table.dart -i <file> [options]
Required:
  -i, --input <file>     Input TSV file
Options:
  -o, --output <file>    Output PNG file (default: input_file_name.png)
  --landscape            Generate landscape output (default: portrait)
  -h, --help            Show this help message
''');
}

void main(List<String> args) async {
  // Parse command line arguments
  String? inputFile;
  String? outputFile;
  bool isLandscape = false;

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
      case '--help':
      case '-h':
        printUsage();
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
    // Remove extension from input file if it exists
    final inputBaseName = inputFile.contains('.')
        ? inputFile.substring(0, inputFile.lastIndexOf('.'))
        : inputFile;
    outputFile = '$inputBaseName.png';
    print('No output file specified, using: $outputFile');
  }

  try {
    // Check if input file exists
    if (!await File(inputFile).exists()) {
      print('Error: Input file "$inputFile" not found');
      exit(1);
    }

    // Read the TSV file
    print('Reading input file: $inputFile');
    final content = await File(inputFile).readAsString();
    final csvConverter = CsvToListConverter(
      fieldDelimiter: '\t',
      eol: '\n',
      shouldParseNumbers: false,
    );
    final allRows = csvConverter.convert(content);
    final lines = allRows
        .where((row) => row.any((cell) => cell.toString().isNotEmpty))
        .toList();

    print('Found ${lines.length} non-empty lines');

    // Process sections
    final sections = <String, List<List<String>>>{};
    String? currentSection;
    var currentData = <List<String>>[];

    // Store the header row
    final headerRow = lines.first.map((cell) => cell.toString()).toList();
    print('Found header row with ${headerRow.length} columns');

    // Process remaining lines
    final dataLines = lines.skip(1).toList();

    // Process lines
    for (final row in dataLines) {
      // Convert all cells to strings
      final processedCells = row.map((cell) => cell.toString()).toList();

      // Pad with empty strings if we have fewer cells than the header
      while (processedCells.length < headerRow.length) {
        processedCells.add('');
      }

      // Skip if all cells in the row are empty
      if (processedCells.every((cell) => cell.trim().isEmpty)) {
        print('Skipping empty row');
        continue;
      }

      // Add to default section
      if (!sections.containsKey('data')) {
        sections['data'] = [];
      }
      sections['data']!.add(processedCells);
      print('Added row with ${processedCells.length} cells to default section');
    }

    if (sections.isEmpty) {
      print('Error: No data found in the input file');
      exit(1);
    }

    print('\nFound ${sections.length} sections: ${sections.keys.toList()}');

    // Calculate row spans for the first column
    final rowSpans = <int>[];
    final firstColumnCells = <String>[];
    var currentSpan = 1;
    var currentCell = '';

    for (var i = 0; i < sections['data']!.length; i++) {
      final row = sections['data']![i];
      final firstCell = row[0];

      // Skip section headers
      if (firstCell.contains('EVIDENCE FOR LEVEL')) {
        continue;
      }

      if (i == 0 ||
          (firstCell.isNotEmpty && !firstCell.contains('EVIDENCE FOR LEVEL'))) {
        if (currentCell.isNotEmpty) {
          rowSpans.add(currentSpan);
          firstColumnCells.add(currentCell);
        }
        currentSpan = 1;
        currentCell = firstCell;
      } else {
        currentSpan++;
      }
    }
    // Add the last span
    if (currentCell.isNotEmpty) {
      rowSpans.add(currentSpan);
      firstColumnCells.add(currentCell);
    }

    // Generate HTML
    final numColumns = headerRow.length;

    final html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 20px;
                color: #333;
            }
            .section-header {
                font-size: 14px;
                font-weight: bold;
                color: #000;
                background-color: #e9ecef;
                padding: 8px;
            }
            .header-row {
                background-color: #f5f5f5;
                font-weight: bold;
            }
            .full-row {
                background-color: #e9ecef;
                font-weight: bold;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 20px;
                font-size: ${isLandscape ? '11px' : '12px'};
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
            }
            tr:nth-child(even) {
                background-color: #fafafa;
            }
        </style>
    </head>
    <body>
    <table>
    <tr class="header-row">
        ${headerRow[0].trim().isNotEmpty && headerRow.skip(1).every((cell) => cell.trim().isEmpty) ? '<th colspan="$numColumns" class="full-row">${headerRow[0]}</th>' : headerRow.map((cell) => '<th>$cell</th>').join('\n')}
    </tr>
    ${sections.entries.map((entry) => '''
        ${entry.key != 'data' ? '''
        <tr>
            <th colspan="$numColumns" class="section-header">${entry.key}</th>
        </tr>
        ''' : ''}
        ${() {
              var rowIndex = 0;
              var spanIndex = 0;
              return entry.value.map((row) {
                final buffer = StringBuffer();

                // Check if this is a section header (contains "EVIDENCE FOR LEVEL")
                if (row[0].contains('EVIDENCE FOR LEVEL')) {
                  buffer.write(
                      '<tr><td colspan="$numColumns" class="full-row">${row[0]}</td></tr>\n');
                  return buffer.toString();
                }

                buffer.write('<tr>');

                // Handle first column
                if (row[0].isNotEmpty) {
                  // Check if this row should be part of a rowspan group
                  if (spanIndex < rowSpans.length &&
                      row[0] == firstColumnCells[spanIndex]) {
                    buffer.write(
                        '<td rowspan="${rowSpans[spanIndex]}">${row[0]}</td>');
                    buffer.write(
                        row.skip(1).map((cell) => '<td>$cell</td>').join('\n'));
                    spanIndex++;
                  } else {
                    // Regular row with data
                    buffer
                        .write(row.map((cell) => '<td>$cell</td>').join('\n'));
                  }
                } else {
                  // Continuation row of a rowspan
                  buffer.write(
                      row.skip(1).map((cell) => '<td>$cell</td>').join('\n'));
                }

                buffer.write('</tr>');
                rowIndex++;
                return buffer.toString();
              }).join('\n');
            }()}
    ''').join('\n')}
    </table>
    </body>
    </html>
    ''';

    // Validate table structure
    void validateTableStructure(String htmlContent) {
      final document = parse(htmlContent);
      final rows = document.getElementsByTagName('tr');

      // Get the expected number of columns from the header
      final headerCells = rows.first.getElementsByTagName('th');
      final expectedColumns = headerCells.length;

      print(
          'Validating table structure - expecting $expectedColumns columns per row');

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final cells = row.getElementsByTagName('td');
        var effectiveColumnCount = 0;

        // Count cells considering colspan and rowspan
        for (final cell in cells) {
          final colspan = int.tryParse(cell.attributes['colspan'] ?? '1') ?? 1;
          effectiveColumnCount += colspan;
        }

        if (effectiveColumnCount != expectedColumns) {
          throw Exception(
              'Row ${i + 1} has $effectiveColumnCount columns, expected $expectedColumns');
        }
      }

      print('Table structure validation passed');
    }

    // Validate and save HTML
    print('\nValidating HTML structure...');
    validateTableStructure(html);

    print('\nSaving HTML file...');
    await File('temp.html').writeAsString(html);

    // Convert to PDF using wkhtmltopdf
    print('Converting to PDF...');
    var shell = Shell();
    await shell.run('''
      wkhtmltopdf --enable-local-file-access ${isLandscape ? '--orientation Landscape' : ''} --page-size A4 --margin-top 10 --margin-right 10 --margin-bottom 10 --margin-left 10 temp.html temp.pdf
    ''');

    // Convert to PNG using ImageMagick
    print('Converting to PNG...');
    await shell.run('''
      convert -density 300 'temp.pdf' -trim -quality 100 '$outputFile'
    ''');

    // Removed cleanup step to keep temp files
    print('Done! Output saved to $outputFile');
    print(
        'Temporary files temp.html and temp.pdf have been preserved for debugging');
    print('Output format: ${isLandscape ? 'Landscape' : 'Portrait'}');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
