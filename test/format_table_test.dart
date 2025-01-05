import 'package:test/test.dart';
import '../format_table.dart';

void main() {
  group('TableDataProcessor', () {
    test('processes valid TSV data correctly', () {
      final input = '''GENE\tLOCATION\tINTERPRETATION
gene1\tloc1\tbenign
gene2\tloc2\t
gene3\tloc3\tpathogenic''';

      final result = TableDataProcessor.processTableData(input);

      expect(result.headerRow, ['GENE', 'LOCATION', 'INTERPRETATION']);
      expect(result.rows, [
        ['gene1', 'loc1', 'benign'],
        ['gene2', 'loc2', ''],
        ['gene3', 'loc3', 'pathogenic'],
      ]);
    });

    test('handles empty rows correctly', () {
      final input = '''GENE\tLOCATION\tINTERPRETATION
gene1\tloc1\tbenign

gene2\tloc2\t''';

      final result = TableDataProcessor.processTableData(input);

      expect(result.rows.length, 2);
      expect(result.rows, [
        ['gene1', 'loc1', 'benign'],
        ['gene2', 'loc2', ''],
      ]);
    });

    test('throws exception for empty input', () {
      expect(
        () => TableDataProcessor.processTableData(''),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('RowspanCalculator', () {
    test('calculates single rowspan correctly', () {
      final rows = [
        ['gene1', 'loc1', 'benign'],
        ['gene2', 'loc2', ''],
        ['gene3', 'loc3', ''],
        ['gene4', 'loc4', 'pathogenic'],
      ];
      final mergeCols = {2}; // Merge the INTERPRETATION column

      final result = RowspanCalculator.calculateRowspans(rows, mergeCols);

      expect(result.length, 1); // One column being merged
      expect(result[2]!.length, 1); // One span for 'benign'
      expect(result[2]![0].startIndex, 0);
      expect(result[2]![0].rowSpan, 3);
      expect(result[2]![0].value, 'benign');
    });

    test('handles multiple merge columns', () {
      final rows = [
        ['gene1', 'loc1', 'benign'],
        ['gene2', '', ''],
        ['gene3', 'loc2', 'pathogenic'],
        ['gene4', '', ''],
      ];
      final mergeCols = {
        1,
        2
      }; // Merge both LOCATION and INTERPRETATION columns

      final result = RowspanCalculator.calculateRowspans(rows, mergeCols);

      expect(result.length, 2); // Two columns being merged
      expect(result[1]!.length, 2); // Two spans in LOCATION column
      expect(result[2]!.length, 2); // Two spans in INTERPRETATION column

      // Verify first LOCATION span
      expect(result[1]![0].startIndex, 0);
      expect(result[1]![0].rowSpan, 2);
      expect(result[1]![0].value, 'loc1');

      // Verify second LOCATION span
      expect(result[1]![1].startIndex, 2);
      expect(result[1]![1].rowSpan, 2);
      expect(result[1]![1].value, 'loc2');

      // Verify first INTERPRETATION span
      expect(result[2]![0].startIndex, 0);
      expect(result[2]![0].rowSpan, 2);
      expect(result[2]![0].value, 'benign');

      // Verify second INTERPRETATION span
      expect(result[2]![1].startIndex, 2);
      expect(result[2]![1].rowSpan, 2);
      expect(result[2]![1].value, 'pathogenic');
    });
  });

  group('HtmlGenerator', () {
    test('generates correct HTML structure', () {
      final tableData = TableData(
        headerRow: ['GENE', 'LOCATION', 'INTERPRETATION'],
        rows: [
          ['gene1', 'loc1', 'benign'],
          ['gene2', 'loc2', ''],
        ],
      );
      final columnRowSpans = <int, List<RowSpanInfo>>{};
      final mergeCols = <int>{};

      final html =
          HtmlGenerator.generateHtml(tableData, columnRowSpans, mergeCols);

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<table>'));
      expect(html, contains('<th>GENE</th>'));
      expect(html, contains('<td>gene1</td>'));
    });

    test('applies rowspans correctly', () {
      final tableData = TableData(
        headerRow: ['GENE', 'INTERPRETATION'],
        rows: [
          ['gene1', 'benign'],
          ['gene2', ''],
        ],
      );
      final columnRowSpans = {
        1: [
          RowSpanInfo(startIndex: 0, rowSpan: 2, value: 'benign'),
        ],
      };
      final mergeCols = {1};

      final html =
          HtmlGenerator.generateHtml(tableData, columnRowSpans, mergeCols);

      expect(html, contains('rowspan="2"'));
      expect(html, contains('>benign<'));
    });
  });

  group('TableValidator', () {
    test('validates correct table structure', () {
      final html = '''
      <!DOCTYPE html>
      <html>
      <body>
      <table>
        <tr><th>Col1</th><th>Col2</th></tr>
        <tr><td>Data1</td><td>Data2</td></tr>
      </table>
      </body>
      </html>''';

      expect(() => TableValidator.validateStructure(html), returnsNormally);
    });

    test('detects incorrect number of columns', () {
      final html = '''
      <!DOCTYPE html>
      <html>
      <body>
      <table>
        <tr><th>Col1</th><th>Col2</th></tr>
        <tr><td>Data1</td></tr>
      </table>
      </body>
      </html>''';

      expect(
        () => TableValidator.validateStructure(html),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FileOperations', () {
    test('writes HTML content to file', () async {
      final htmlContent = '<html><body>Test</body></html>';
      final outputFile = 'test_output.png';

      // Note: This test only verifies that the function runs without errors
      // A more comprehensive test would need to mock the shell commands
      await expectLater(
        FileOperations.convertToOutput(htmlContent, outputFile),
        completes,
      );
    });
  });
}
