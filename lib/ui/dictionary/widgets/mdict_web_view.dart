import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../services/mdict/mdict_dictionary_pack.dart';
import '../../../services/mdict/mdict_html_page_builder.dart';

/// Renders one MDX entry in a WebView so the dictionary's own CSS/JS run as
/// designed (expand/collapse, popups, ...). `sound://` and `entry://` links are
/// intercepted and forwarded to the host.
class MDictWebView extends StatefulWidget {
  final MDictDictionaryPack pack;
  final String html;
  final ValueChanged<String> onSoundUrl;
  final ValueChanged<String> onEntryUrl;

  const MDictWebView({
    super.key,
    required this.pack,
    required this.html,
    required this.onSoundUrl,
    required this.onEntryUrl,
  });

  @override
  State<MDictWebView> createState() => _MDictWebViewState();
}

class _MDictWebViewState extends State<MDictWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF141414))
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: _onNavigate));
    _load();
  }

  @override
  void didUpdateWidget(MDictWebView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html || old.pack != widget.pack) _load();
  }

  Future<void> _load() async {
    final page = await MDictHtmlPageBuilder.build(
      html: widget.html,
      css: widget.pack.customCss,
      js: widget.pack.customJs,
      resolveResource: widget.pack.lookupResource,
    );
    if (!mounted) return;
    await _controller.loadHtmlString(page);
  }

  NavigationDecision _onNavigate(NavigationRequest request) {
    final url = request.url;
    if (url.startsWith('sound://')) {
      var path = url.substring('sound://'.length);
      try {
        path = Uri.decodeFull(path);
      } catch (_) {}
      widget.onSoundUrl(path);
      return NavigationDecision.prevent;
    }
    if (url.startsWith('entry://')) {
      final target = Uri.decodeComponent(url.substring('entry://'.length)).trim();
      if (target.startsWith('#')) {
        // In-page anchor (e.g. "noun | verb" jump links).
        final id = target.substring(1).replaceAll("'", r"\'");
        _controller.runJavaScript(
          "var e=document.querySelector(\"a[name='$id']\");if(e)e.scrollIntoView();",
        );
      } else if (target.isNotEmpty) {
        widget.onEntryUrl(target);
      }
      return NavigationDecision.prevent;
    }
    // Initial loadHtmlString and about:blank must pass; block everything else.
    return url.startsWith('about:') || url.startsWith('data:')
        ? NavigationDecision.navigate
        : NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
