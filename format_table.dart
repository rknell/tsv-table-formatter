import 'dart:io';
import 'package:html/dom.dart';
import 'package:process_run/shell.dart';

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
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    print('Found ${lines.length} non-empty lines');

    // Process sections
    final sections = <String, List<List<String>>>{};
    String? currentSection;
    var currentData = <List<String>>[];

    for (final line in lines) {
      print('Processing line: $line');

      // Check if it's a section header (all caps, no tabs)
      if (!line.contains('\t') && line == line.toUpperCase()) {
        print('Found section header: $line');
        if (currentSection != null && currentData.isNotEmpty) {
          sections[currentSection] = List.from(currentData);
          print(
            'Saved section $currentSection with ${currentData.length} rows',
          );
        }
        currentSection = line;
        currentData = [];
      } else {
        final cells = line.split('\t').map((cell) => cell.trim()).toList();
        currentData.add(cells);
        print('Added row with ${cells.length} cells');
      }
    }

    // Don't forget the last section
    if (currentSection != null && currentData.isNotEmpty) {
      sections[currentSection] = List.from(currentData);
      print(
        'Saved final section $currentSection with ${currentData.length} rows',
      );
    }

    print('\nFound ${sections.length} sections: ${sections.keys.toList()}');

    // Generate HTML
    // First, determine the number of columns from the first data row in any section
    final numColumns = sections.values.first[0].length;

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
    ${sections.entries.map((entry) => '''
        <tr>
            <th colspan="$numColumns" class="section-header">${entry.key}</th>
        </tr>
        <tr>
            ${entry.value[0].map((cell) => '<td>$cell</td>').join('\n')}
        </tr>
        ${entry.value.skip(1).map((row) => '''
            <tr>
                ${row.map((cell) => '<td>$cell</td>').join('\n')}
            </tr>
        ''').join('\n')}
    ''').join('\n')}
    </table>
    </body>
    </html>
    ''';

    // Save HTML
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
      convert -density 300 temp.pdf -trim -quality 100 $outputFile
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
