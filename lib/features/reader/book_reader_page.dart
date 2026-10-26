import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/books/book_library.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Reads a book folder with the bundled HTML reader (assets/reader): pages,
/// fonts, themes, contents, bookmarks, highlights, search, footnotes.
/// This page hosts it and syncs reading state with the server.
///
/// Pops with 'buy' when the reader of a sample asks for the full book.
class BookReaderPage extends StatefulWidget {
  final String folder; // "12" (book) or "p12" (sample)
  final String bookId;
  final String title;
  final bool preview;

  const BookReaderPage({super.key, required this.folder, required this.bookId, required this.title, this.preview = false});

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  Color _background = const Color(0xFFFBF9F5);
  bool _dark = false;
  Timer? _syncTimer;
  Map<String, dynamic> _pending = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _init();
  }

  Future<void> _init() async {
    try {
      final library = BookLibrary.instance;
      final readerFile = await library.readerFile();
      final remote = widget.preview || !session.loggedIn ? null : await library.fetchReading(widget.bookId);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(_background)
        ..addJavaScriptChannel('ReaderBridge', onMessageReceived: (m) => _onMessage(m.message))
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) => _open(remote),
          onNavigationRequest: (req) {
            if (req.url.startsWith('file:')) return NavigationDecision.navigate;
            launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ));
      final platform = controller.platform;
      if (platform is AndroidWebViewController) await platform.setAllowFileAccess(true);
      await controller.loadFile(readerFile.path);
      setState(() => _controller = controller);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(Map<String, dynamic>? remote) async {
    if (!mounted) return;
    final pad = MediaQuery.of(context).padding;
    final cfg = {
      'bookBase': './${widget.folder}/',
      'uiLang': 'uz',
      'embedded': true,
      'insets': {'top': pad.top, 'bottom': pad.bottom},
      if (remote != null) 'reading': remote,
    };
    await _controller?.runJavaScript('Reader.open(${jsonEncode(cfg)});');
  }

  void _onMessage(String raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'loaded':
        if (mounted) setState(() => _loading = false);
      case 'error':
        if (mounted) {
          setState(() {
            _loading = false;
            _error = msg['message']?.toString();
          });
        }
      case 'position':
        if (!widget.preview) _queueSync({'position': msg['position'], 'percent': msg['percent'], 'updatedAt': DateTime.now().millisecondsSinceEpoch});
      case 'annotations':
        if (!widget.preview) _queueSync({'bookmarks': msg['bookmarks'], 'highlights': msg['highlights'], 'updatedAt': msg['updatedAt']});
      case 'theme':
        final hex = (msg['background'] ?? '').toString().replaceAll('#', '');
        final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
        if (mounted && value != null) {
          setState(() {
            _background = Color(value);
            _dark = msg['dark'] == true;
          });
        }
      case 'copy':
        Clipboard.setData(ClipboardData(text: (msg['text'] ?? '').toString()));
      case 'openUrl':
        final url = msg['url']?.toString();
        if (url != null) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      case 'buy':
        if (mounted) Navigator.of(context).pop('buy');
      case 'close':
        _flushSync();
        if (mounted) Navigator.of(context).maybePop();
    }
  }

  void _queueSync(Map<String, dynamic> data) {
    if (!session.loggedIn) return;
    data.removeWhere((k, v) => v == null);
    _pending = {..._pending, ...data};
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), _flushSync);
  }

  void _flushSync() {
    _syncTimer?.cancel();
    if (_pending.isEmpty) return;
    final data = _pending;
    _pending = {};
    BookLibrary.instance.pushReading(widget.bookId, data).then((_) => notifyBooksChanged());
  }

  @override
  void dispose() {
    _flushSync();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlay = (_dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: _background);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) => _flushSync(),
        child: Scaffold(
          backgroundColor: _background,
          body: Stack(
            children: [
              if (_controller != null) WebViewWidget(controller: _controller!),
              if (_loading && _error == null)
                Container(
                  color: _background,
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 18),
                    Text(widget.title, textAlign: TextAlign.center, style: AppText.bookTitle.copyWith(color: AppPalette.inkSoft)),
                  ]),
                ),
              if (_error != null)
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const AppIcon('circle-alert', size: 52, color: AppPalette.danger),
                        const SizedBox(height: 12),
                        const Text("Kitobni ochib bo'lmadi", style: AppText.section),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center, style: AppText.bodySoft),
                        const SizedBox(height: 20),
                        if (!widget.preview)
                          FilledButton(
                            onPressed: () async {
                              await BookLibrary.instance.remove(widget.bookId);
                              if (context.mounted) Navigator.pop(context, 'redownload');
                            },
                            child: const Text('Qayta yuklab olish'),
                          ),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Orqaga')),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
