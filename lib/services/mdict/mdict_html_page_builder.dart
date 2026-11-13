import 'dart:convert';
import 'dart:typed_data';

typedef MDictResourceResolver = Future<Uint8List?> Function(String path);

/// Turns a raw MDX entry into a self-contained HTML page for a WebView.
///
/// MDX entries reference companion files (`.css`, `.js`, images in the `.mdd`)
/// by relative path, which a WebView loading a string cannot resolve. This
/// inlines them and adds a dark-theme override.
class MDictHtmlPageBuilder {
  MDictHtmlPageBuilder._();

  static final _linkCss = RegExp(
    r'''<link[^>]+href\s*=\s*["'][^"']+\.css["'][^>]*>''',
    caseSensitive: false,
  );
  static final _scriptSrc = RegExp(
    r'''<script[^>]+src\s*=\s*["'][^"']+\.js["'][^>]*>\s*</script>''',
    caseSensitive: false,
  );
  static final _imgSrc = RegExp(
    r'''(<img[^>]*?)\ssrc\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final _soundLink = RegExp(
    r'''(<a\s[^>]*href\s*=\s*["']sound://[^>]*>)(.*?)(</a>)''',
    caseSensitive: false,
    dotAll: true,
  );

  /// Some dictionaries (e.g. Oxford Primary) make the whole text a bare
  /// `sound://` link with no speaker icon. Prefix those with one; links that
  /// already carry an `<img>` icon (e.g. Longman) are left alone.
  static String addSpeakerIcons(String html) {
    return html.replaceAllMapped(_soundLink, (m) {
      final inner = m.group(2)!;
      if (inner.contains(RegExp('<img', caseSensitive: false))) return m.group(0)!;
      if (inner.replaceAll(RegExp(r'<[^>]*>|\s'), '').isEmpty) return m.group(0)!;
      return '${m.group(1)}<span class="mdd-play">\u{1F50A}</span>$inner${m.group(3)}';
    });
  }

  static const darkOverrideCss = '''
.mdd-play{color:#6fb1ff;font-size:.85em;margin-right:4px}
html,body{background:#141414!important;color:#e0e0e0!important;margin:0;padding:0}
body{padding:10px 12px;font-size:15px;line-height:1.5;-webkit-text-size-adjust:100%}
.entry,.gloss,.collgloss,span.neutral,span.italic,span.neutral{color:#e0e0e0!important}
a{color:#6fb1ff}
.example,.hyphenation,.phrvbhwd,.deriv,.homnum,span.sensenum,.ac{color:#7fb2ff!important}
.pos{color:#6fcf97!important}.gram{color:#6fcf97!important}
.geo,span.geo,.registerlab{color:#c792ea!important}
.arrow{color:#ccc!important;border-color:#777!important}
.popup-button{background:#222a3d!important;color:#9db4ff!important;border-color:#4a5a8a!important}
.at-link{border-color:#3a3a3a!important;background:#1d1d1d!important}
font[color="#0"],font[color="#000000"],font[color="black"]{color:#e0e0e0!important}
img{max-width:100%}
''';

  static const _imageLoader = '''
(function(){
  var m = window.__mddImages || {};
  var imgs = document.querySelectorAll('img[data-mdd-src]');
  for (var i = 0; i < imgs.length; i++) {
    var k = imgs[i].getAttribute('data-mdd-src');
    if (m[k]) imgs[i].src = m[k];
  }
})();
''';

  static String? _mimeFor(Uint8List b) {
    if (b.length >= 4 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b.length >= 3 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'image/gif';
    if (b.length >= 5 && String.fromCharCodes(b.sublist(0, 5)).toLowerCase() == '<?xml') {
      return 'image/svg+xml';
    }
    return null;
  }

  static Future<String> build({
    required String html,
    String? css,
    String? js,
    MDictResourceResolver? resolveResource,
  }) async {
    var body = addSpeakerIcons(html.replaceAll(_linkCss, '').replaceAll(_scriptSrc, ''));

    // Images live in the .mdd: collect unique paths and embed each only once.
    final images = <String, String>{};
    if (resolveResource != null) {
      final paths = _imgSrc
          .allMatches(body)
          .map((m) => m.group(2)!)
          .where((p) => !p.startsWith('data:') && !p.contains('://'))
          .toSet();
      for (final path in paths) {
        final bytes = await resolveResource(path);
        final mime = bytes == null ? null : _mimeFor(bytes);
        if (bytes != null && mime != null) {
          images[path] = 'data:$mime;base64,${base64Encode(bytes)}';
        }
      }
    }
    body = body.replaceAllMapped(_imgSrc, (m) {
      final path = m.group(2)!;
      return images.containsKey(path) ? '${m.group(1)} data-mdd-src="$path"' : m.group(0)!;
    });

    final buf = StringBuffer()
      ..write('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..write('<meta name="viewport" content="width=device-width,initial-scale=1">');
    if (css != null && css.isNotEmpty) buf.write('<style>$css</style>');
    buf.write('<style>$darkOverrideCss</style>');
    if (js != null && js.isNotEmpty) buf.write('<script>$js</script>');
    buf.write('</head><body>$body');
    if (images.isNotEmpty) {
      buf.write('<script>window.__mddImages=${jsonEncode(images)};$_imageLoader</script>');
    }
    buf.write('</body></html>');
    return buf.toString();
  }
}
