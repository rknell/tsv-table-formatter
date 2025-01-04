# TSV Table Formatter

A command-line tool to convert TSV (Tab-Separated Values) files into beautifully formatted PNG images. The tool supports both portrait and landscape orientations and automatically handles section headers.

## Dependencies

### Debian/Ubuntu
```bash
# Install Dart
sudo apt-get update
sudo apt-get install apt-transport-https
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
sudo apt-get update
sudo apt-get install dart

# Install other dependencies
sudo apt-get install wkhtmltopdf imagemagick
```

### Fedora
```bash
# Install Dart
sudo dnf install dart

# Install other dependencies
sudo dnf install wkhtmltopdf ImageMagick
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/rknell/tsv-table-formatter.git
cd tsv-table-formatter
```

2. Install Dart dependencies:
```bash
dart pub get
```

## Usage

Basic usage with automatic output filename:
```bash
dart run format_table.dart -i input.txt
```

Specify input and output files:
```bash
dart run format_table.dart -i input.txt -o output.png
```

Generate landscape output:
```bash
dart run format_table.dart -i input.txt --landscape
```

### Command Line Options

```
Usage: dart run format_table.dart -i <file> [options]
Required:
  -i, --input <file>     Input TSV file
Options:
  -o, --output <file>    Output PNG file (default: input_file_name.png)
  --landscape            Generate landscape output (default: portrait)
  -h, --help            Show this help message
```

## Input File Format

The input file should be a TSV (Tab-Separated Values) file with section headers in UPPERCASE. Example:

```
SECTION1
Header1  Header2  Header3
Data1    Data2    Data3

SECTION2
Header1  Header2  Header3
Data1    Data2    Data3
```

## Output

The tool generates:
- A PNG file with the formatted table
- Temporary files (temp.html and temp.pdf) for debugging purposes

## License

MIT License 