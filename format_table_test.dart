import 'package:html/parser.dart' show parse;
import 'format_table.dart';

class TableTests {
  static void runTests() {
    testRowspanCalculation();
    testHtmlGeneration();
    testColumnCounts();
  }

  static void testRowspanCalculation() {
    print('\nRunning rowspan calculation tests...');

    final testData = [
      ['FREM2', 'pos1', 'seq1', 'p.Thr2153Ser', 'Issue1', 'Action1'],
      ['ZNF611', 'pos2', 'seq2', 'p.Pro252Ile', 'Issue1', ''],
      ['PSD3', 'pos3', 'seq3', 'p.Thr186Leu', 'Issue1', ''],
      ['ZNF853', 'pos4', 'seq4', 'p.Gly8Arg', 'Issue2', 'Action2'],
      ['', 'pos5', 'seq5', 'p.Gln30Arg', 'Issue2', ''],
      ['TEX38', 'pos6', 'seq6', 'p.Ser204Thr', 'Issue2', ''],
    ];

    final mergeCols = {4}; // Test merging the "Issue" column
    final spans = RowspanCalculator.calculateRowspans(testData, mergeCols);

    // Verify spans for column 4
    assert(spans.containsKey(4), 'Column 4 should have rowspans');
    assert(spans[4]!.length == 2, 'Should have 2 rowspan groups');

    // Check first span group
    assert(spans[4]![0].startIndex == 0, 'First span should start at index 0');
    assert(spans[4]![0].rowSpan == 3, 'First span should cover 3 rows');
    assert(
        spans[4]![0].value == 'Issue1', 'First span should have value Issue1');

    // Check second span group
    assert(spans[4]![1].startIndex == 3, 'Second span should start at index 3');
    assert(spans[4]![1].rowSpan == 3, 'Second span should cover 3 rows');
    assert(
        spans[4]![1].value == 'Issue2', 'Second span should have value Issue2');

    print('✓ Rowspan calculation tests passed');
  }

  static void testHtmlGeneration() {
    print('\nRunning HTML generation tests...');

    final testData = TableData(
      headerRow: ['Col1', 'Col2', 'Col3'],
      rows: [
        ['A1', 'B1', 'C1'],
        ['A2', 'B2', 'C2'],
      ],
    );

    final html = HtmlGenerator.generateHtml(testData, {}, {});

    // Parse the generated HTML
    final document = parse(html);

    // Test table structure
    final table = document.getElementsByTagName('table');
    assert(table.length == 1, 'Should have exactly one table');

    // Test header
    final headers = document.getElementsByTagName('th');
    assert(headers.length == testData.headerRow.length,
        'Header count should match: expected ${testData.headerRow.length}, got ${headers.length}');

    // Test rows
    final rows = document.getElementsByTagName('tr');
    assert(
        rows.length == testData.rows.length + 1, // +1 for header row
        'Row count should match: expected ${testData.rows.length + 1}, got ${rows.length}');

    print('✓ HTML generation tests passed');
  }

  static void testColumnCounts() {
    print('\nRunning column count tests...');

    // Test case 1: Single merged column
    _testColumnCountsWithMerge("Single merge");

    // Test case 2: Multiple merged columns
    _testMultipleMergedColumns();

    // Test case 3: Complex real-world scenario
    _testComplexMergeScenario();

    // Test case 4: Table19 data
    _testTable19Data();

    // Test case 5: Command line merge columns parsing
    _testMergeColumnsParsing();
  }

  static void _testColumnCountsWithMerge(String testName) {
    final testData = TableData(
      headerRow: [
        'GENE',
        'POSITION',
        'CODING SEQUENCE',
        'PROTEIN SEQUENCE',
        'ISSUE',
        'ACTION'
      ],
      rows: [
        [
          'FREM2',
          'chr13:39424253',
          'c.6458_6459delCTinsGC',
          'p.Thr2153Ser',
          'Issue1',
          'Action1'
        ],
        [
          'ZNF611',
          'chr19:53209553',
          'c.754_755delCCinsAT',
          'p.Pro252Ile',
          'Issue1',
          ''
        ],
        [
          'PSD3',
          'chr8:18729817',
          'c.556_557delACinsCT',
          'p.Thr186Leu',
          'Issue1',
          ''
        ],
      ],
    );

    final mergeCols = {4}; // Merge ISSUE column
    _validateTableStructure(testData, mergeCols, testName);
  }

  static void _testMultipleMergedColumns() {
    print('\nTesting multiple merged columns...');
    final testData = TableData(
      headerRow: [
        'GENE',
        'POSITION',
        'CODING SEQUENCE',
        'PROTEIN SEQUENCE',
        'ISSUE',
        'ACTION'
      ],
      rows: [
        [
          'FREM2',
          'chr13:39424253',
          'c.6458_6459delCTinsGC',
          'p.Thr2153Ser',
          'Issue1',
          'Action1'
        ],
        [
          'ZNF611',
          'chr19:53209553',
          'c.754_755delCCinsAT',
          'p.Pro252Ile',
          'Issue1',
          'Action1'
        ],
        [
          'PSD3',
          'chr8:18729817',
          'c.556_557delACinsCT',
          'p.Thr186Leu',
          'Issue1',
          'Action1'
        ],
        ['ZNF853', 'chr7:6656830', 'c.22G>A', 'p.Gly8Arg', 'Issue2', 'Action2'],
      ],
    );

    final mergeCols = {4, 5}; // Merge both ISSUE and ACTION columns
    _validateTableStructure(testData, mergeCols, "Multiple merges");
  }

  static void _testComplexMergeScenario() {
    print('\nTesting complex merge scenario...');
    final testData = TableData(
      headerRow: [
        'GENE',
        'POSITION',
        'CODING SEQUENCE',
        'PROTEIN SEQUENCE',
        'ISSUE',
        'ACTION'
      ],
      rows: [
        [
          'FREM2',
          'chr13:39424253',
          'c.6458_6459delCTinsGC',
          'p.Thr2153Ser',
          'Ambiguous annotation',
          'Action1'
        ],
        [
          'ZNF611',
          'chr19:53209553',
          'c.754_755delCCinsAT',
          'p.Pro252Ile',
          'Ambiguous annotation',
          ''
        ],
        [
          'PSD3',
          'chr8:18729817',
          'c.556_557delACinsCT',
          'p.Thr186Leu',
          'Ambiguous annotation',
          ''
        ],
        [
          'ZNF853',
          'chr7:6656830',
          'c.22G>A',
          'p.Gly8Arg',
          'Missing REVEL scores',
          'Action2'
        ],
        [
          '',
          'chr7:6656897',
          'c.89A>G',
          'p.Gln30Arg',
          'Missing REVEL scores',
          ''
        ],
      ],
    );

    final mergeCols = {4, 5}; // Merge both ISSUE and ACTION columns
    final spans = RowspanCalculator.calculateRowspans(testData.rows, mergeCols);

    print('\nDebug: Rowspans calculated:');
    spans.forEach((col, spanList) {
      print('Column $col spans:');
      for (var span in spanList) {
        print(
            '  Start: ${span.startIndex}, Rows: ${span.rowSpan}, Value: ${span.value}');
      }
    });

    final html = HtmlGenerator.generateHtml(testData, spans, mergeCols);

    print('\nDebug: Generated HTML structure:');
    final document = parse(html);
    final table = document.getElementsByTagName('table').first;
    final rows = table.getElementsByTagName('tr');

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final cells = i == 0
          ? row.getElementsByTagName('th')
          : row.getElementsByTagName('td');
      print('\nRow $i:');
      for (var cell in cells) {
        final rowspan = cell.attributes['rowspan'] ?? '1';
        print('  Cell: "${cell.text}" (rowspan: $rowspan)');
      }
    }

    _validateTableStructure(testData, mergeCols, "Complex merge");

    // Additional validation specific to complex scenario
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].getElementsByTagName('td');
      var effectiveColumnCount = 0;
      print('\nRow $i column count calculation:');

      for (final cell in cells) {
        final rowspan = int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 1;
        final text = cell.text;
        if (!text.isEmpty || rowspan > 1) {
          effectiveColumnCount++;
          print('  Cell: "$text" (rowspan: $rowspan) - counted');
        } else {
          print('  Cell: "$text" (rowspan: $rowspan) - not counted');
        }
      }

      print(
          '  Total effective columns: $effectiveColumnCount (expected: ${testData.headerRow.length})');
      assert(effectiveColumnCount == testData.headerRow.length,
          'Row $i should have ${testData.headerRow.length} columns, got $effectiveColumnCount');
    }

    print('✓ Complex merge scenario passed');
  }

  static void _testTable19Data() {
    print('\nTesting table19.txt data...');
    final testData = TableData(
      headerRow: [
        'GENE',
        'POSITION',
        'CODING SEQUENCE',
        'PROTEIN SEQUENCE',
        'ISSUE',
        'ACTION'
      ],
      rows: [
        [
          'FREM2',
          'chr13:39424253',
          'c.6458_6459delCTinsGC',
          'p.Thr2153Ser',
          'Ambiguous annotation consecutive SNVs or small insertions/deletions causing a missense effect.',
          'Retained in disease-causing potential analysis but also included in OTHER VARIANTS dataset for assessment.'
        ],
        [
          'ZNF611',
          'chr19:53209553',
          'c.754_755delCCinsAT',
          'p.Pro252Ile',
          '',
          ''
        ],
        ['PSD3', 'chr8:18729817', 'c.556_557delACinsCT', 'p.Thr186Leu', '', ''],
        [
          'ZNF853',
          'chr7:6656830',
          'c.22G>A',
          'p.Gly8Arg',
          'Missing REVEL scores; partial data availability.',
          'Prioritized using CADD-PHRED and PrimateAI scores.'
        ],
        ['', 'chr7:6656897', 'c.89A>G', 'p.Gln30Arg', '', ''],
        ['TEX38', 'chr1:47139117', 'c.610T>A', 'p.Ser204Thr', '', ''],
        ['PKD1L3', 'chr16:72003952', 'c.2006C>G', 'p.Thr669Ser', '', ''],
        [
          'PCDHB6',
          'chr5:140531175',
          'c.1337T>C',
          'p.Val446Ala',
          'Missing LoGoFunc scores.',
          'Substituted with LOEUF scores from burden analysis.'
        ],
        ['LAMA3', 'chr18:21511089', 'c.8500A>G', 'p.Ser2834Gly', '', ''],
        ['PTPN13', 'chr4:87622624', 'c.865G>A', 'p.Gly289Ser', '', ''],
        ['MCHR1', 'chr22:41075543', 'c.94A>G', 'p.Asn32Asp', '', ''],
        ['DDX60L', 'chr4:169336662', 'c.2876A>G', 'p.Tyr959Cys', '', ''],
      ],
    );

    final mergeCols = {4, 5}; // Merge both ISSUE and ACTION columns
    final spans = RowspanCalculator.calculateRowspans(testData.rows, mergeCols);

    print('\nDebug: Rowspans calculated for table19:');
    spans.forEach((col, spanList) {
      print('Column $col spans:');
      for (var span in spanList) {
        print(
            '  Start: ${span.startIndex}, Rows: ${span.rowSpan}, Value: ${span.value}');
      }
    });

    final html = HtmlGenerator.generateHtml(testData, spans, mergeCols);
    final document = parse(html);
    final table = document.getElementsByTagName('table').first;
    final rows = table.getElementsByTagName('tr');

    print('\nDebug: HTML structure for table19:');
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final cells = i == 0
          ? row.getElementsByTagName('th')
          : row.getElementsByTagName('td');
      print('\nRow $i:');
      for (var cell in cells) {
        final rowspan = cell.attributes['rowspan'] ?? '1';
        print('  Cell: "${cell.text}" (rowspan: $rowspan)');
      }
    }

    // Validate structure
    _validateTableStructure(testData, mergeCols, "Table19");

    print('✓ Table19 test passed');
  }

  static void _testMergeColumnsParsing() {
    print('\nTesting merge columns parsing...');

    // Test parsing comma-separated columns (preferred format)
    final argsComma = ['--merge-cols', '4,5'];
    final mergeColsComma = _parseMergeColumns(argsComma);
    assert(mergeColsComma.contains(4), 'Should contain column 4');
    assert(mergeColsComma.contains(5), 'Should contain column 5');
    assert(mergeColsComma.length == 2, 'Should have exactly 2 columns');

    // Test parsing multiple comma-separated columns
    final argsMultiple = ['--merge-cols', '4,5,6'];
    final mergeColsMultiple = _parseMergeColumns(argsMultiple);
    assert(mergeColsMultiple.length == 3, 'Should have exactly 3 columns');

    // Test parsing single column
    final argsSingle = ['--merge-cols', '4'];
    final mergeColsSingle = _parseMergeColumns(argsSingle);
    assert(mergeColsSingle.length == 1, 'Should have exactly 1 column');

    print('✓ Merge columns parsing test passed');
  }

  static Set<int> _parseMergeColumns(List<String> args) {
    var mergeCols = <int>{};
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--merge-cols' && i + 1 < args.length) {
        final input = args[++i];
        if (input.contains(' ')) {
          print(
              'Warning: Please use comma-separated format (e.g., 4,5) instead of spaces');
        }
        mergeCols = input
            .split(RegExp(r'[,\s]+'))
            .map((s) => int.tryParse(s.trim()))
            .where((n) => n != null)
            .map((n) => n!)
            .toSet();
        break;
      }
    }
    return mergeCols;
  }

  static void _validateTableStructure(
      TableData testData, Set<int> mergeCols, String testName) {
    final html = HtmlGenerator.generateHtml(
        testData,
        RowspanCalculator.calculateRowspans(testData.rows, mergeCols),
        mergeCols);

    // Parse and validate
    final document = parse(html);
    final table = document.getElementsByTagName('table').first;
    final rows = table.getElementsByTagName('tr');

    // Check header count
    final headerCells = rows.first.getElementsByTagName('th');
    assert(headerCells.length == testData.headerRow.length,
        '$testName: Header should have ${testData.headerRow.length} columns, got ${headerCells.length}');

    // Track active rowspans
    var activeRowspans = <int, int>{}; // column index -> remaining rows

    // Check each data row
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].getElementsByTagName('td');
      var effectiveColumnCount = 0;
      var currentCol = 0;

      // First count active rowspans from previous rows
      for (var col = 0; col < testData.headerRow.length; col++) {
        if (activeRowspans.containsKey(col) && activeRowspans[col]! > 0) {
          effectiveColumnCount++;
          activeRowspans[col] = activeRowspans[col]! - 1;
        }
      }

      // Then process current row's cells
      for (final cell in cells) {
        // Skip columns that are currently being spanned
        while (currentCol < testData.headerRow.length &&
            activeRowspans.containsKey(currentCol) &&
            activeRowspans[currentCol]! > 0) {
          currentCol++;
        }

        if (currentCol >= testData.headerRow.length) break;

        final rowspan = int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 1;
        if (rowspan > 1) {
          activeRowspans[currentCol] = rowspan - 1;
          effectiveColumnCount++;
        } else if (!cell.text.isEmpty) {
          effectiveColumnCount++;
        }
        currentCol++;
      }

      print('\nRow $i column calculation:');
      print('  Effective columns: $effectiveColumnCount');
      print('  Active rowspans: $activeRowspans');

      assert(effectiveColumnCount == testData.headerRow.length,
          '$testName: Row $i should have ${testData.headerRow.length} columns, got $effectiveColumnCount');
    }

    print('✓ $testName test passed');
  }
}

void main() {
  print('Running tests...');
  TableTests.runTests();
  print('\nAll tests completed successfully!\n');
}
