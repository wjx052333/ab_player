/// MDict XML header metadata model
class MDictHeader {
  final double engineVersion;
  final String format;
  final bool keyCaseSensitive;
  final bool stripKey;
  final int encrypted;
  final String title;
  final String description;
  final String encoding;
  final String creationDate;
  final String styleSheet;

  const MDictHeader({
    this.engineVersion = 2.0,
    this.format = 'Html',
    this.keyCaseSensitive = false,
    this.stripKey = true,
    this.encrypted = 0,
    this.title = '',
    this.description = '',
    this.encoding = 'UTF-8',
    this.creationDate = '',
    this.styleSheet = '',
  });

  factory MDictHeader.fromXml(String xmlString) {
    String extractAttr(String name, [String defaultVal = '']) {
      final match = RegExp('$name="([^"]*)"', caseSensitive: false).firstMatch(xmlString);
      return match != null ? match.group(1) ?? defaultVal : defaultVal;
    }

    final engineVerStr = extractAttr('GeneratedByEngineVersion', '2.0');
    final engineVersion = double.tryParse(engineVerStr) ?? 2.0;
    final format = extractAttr('Format', 'Html');
    final keyCaseSensitive = extractAttr('KeyCaseSensitive', 'No').toLowerCase() == 'yes';
    final stripKey = extractAttr('StripKey', 'Yes').toLowerCase() == 'yes';
    final encrypted = int.tryParse(extractAttr('Encrypted', '0')) ?? 0;
    final title = extractAttr('Title', '');
    final description = extractAttr('Description', '');
    final encoding = extractAttr('Encoding', 'UTF-8');
    final creationDate = extractAttr('CreationDate', '');
    final styleSheet = extractAttr('StyleSheet', '');

    return MDictHeader(
      engineVersion: engineVersion,
      format: format,
      keyCaseSensitive: keyCaseSensitive,
      stripKey: stripKey,
      encrypted: encrypted,
      title: title,
      description: description,
      encoding: encoding,
      creationDate: creationDate,
      styleSheet: styleSheet,
    );
  }
}
