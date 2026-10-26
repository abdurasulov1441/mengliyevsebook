import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:mengliyevsebook/services/books/book_library.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Reads a downloaded book with the bundled HTML reader (assets/reader).
///
/// The reader handles pagination, fonts, themes, table of contents,
/// bookmarks, highlights, notes, search and footnotes. This page only hosts
/// it and syncs the reading state with the server.
class BookReaderPage extends StatefulWidget {
  final String bookId;
  final String title;

  const BookReaderPage({super.key, required this.bookId, required this.title});

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  Color _background = const Color(0xFFFBFAF7);
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
      // Server copy of bookmarks/highlights/position (newest wins inside the reader).
      final remote = await library.fetchReading(widget.bookId);

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(_background)
        ..addJavaScriptChannel('ReaderBridge', onMessageReceived: (m) => _onMessage(m.message))
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) => _openBook(remote),
          onNavigationRequest: (req) {
            if (req.url.startsWith('file:')) return NavigationDecision.navigate;
            launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ));
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        // reader.html loads ./<bookId>/book.js and images from app storage.
        await platform.setAllowFileAccess(true);
      }
      await controller.loadFile(readerFile.path);
      setState(() => _controller = controller);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openBook(Map<String, dynamic>? remote) async {
    if (!mounted) return;
    final pad = MediaQuery.of(context).padding;
    final cfg = {
      'bookBase': './${widget.bookId}/',
      'uiLang': 'uz',
      'embedded': true,
      // The WebView is edge-to-edge; the reader pads its bars by these.
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
        break;
      case 'error':
        if (mounted) {
          setState(() {
            _loading = false;
            _error = msg['message']?.toString();
          });
        }
        break;
      case 'position':
        _queueSync({'position': msg['position'], 'percent': msg['percent'], 'updatedAt': DateTime.now().millisecondsSinceEpoch});
        break;
      case 'annotations':
        _queueSync({'bookmarks': msg['bookmarks'], 'highlights': msg['highlights'], 'updatedAt': msg['updatedAt']});
        break;
      case 'theme':
        final hex = (msg['background'] ?? '').toString().replaceAll('#', '');
        final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
        if (mounted && value != null) {
          setState(() {
            _background = Color(value);
            _dark = msg['dark'] == true;
          });
        }
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: (msg['text'] ?? '').toString()));
        break;
      case 'openUrl':
        final url = msg['url']?.toString();
        if (url != null) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        break;
      case 'close':
        _flushSync();
        if (mounted) Navigator.of(context).maybePop();
        break;
    }
  }

  void _queueSync(Map<String, dynamic> data) {
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
    BookLibrary.instance.pushReading(widget.bookId, data);
  }

  @override
  void dispose() {
    _flushSync();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlay = (_dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _background,
    );
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(widget.title, textAlign: TextAlign.center, style: AppText.bookTitle.copyWith(color: AppPalette.inkSoft)),
                    ],
                  ),
                ),
              if (_error != null)
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon('book-open', size: 52, color: AppPalette.danger),
                          const SizedBox(height: 12),
                          const Text("Kitobni ochib bo'lmadi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () async {
                              await BookLibrary.instance.remove(widget.bookId);
                              if (context.mounted) Navigator.pop(context, 'redownload');
                            },
                            child: const Text('Qayta yuklab olish'),
                          ),
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Orqaga')),
                        ],
                      ),
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

/// Opens a book: downloads (or updates) the package if needed, then reads it.
Future<void> openBook(BuildContext context, Map book, {void Function(double)? onProgress}) async {
  final library = BookLibrary.instance;
  final id = book['id'].toString();
  if (!await library.isUpToDate(book)) {
    final hadOld = await library.localVersion(id) != null;
    try {
      await library.download(book, onProgress: onProgress);
    } catch (e) {
      // An older copy is still readable offline.
      if (!hadOld) rethrow;
    }
  }
  if (!context.mounted) return;
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => BookReaderPage(bookId: id, title: (book['title'] ?? 'Kitob').toString())),
  );
  if (result == 'redownload' && context.mounted) {
    await openBook(context, book, onProgress: onProgress);
  }
}

/// Size of downloaded books (for a "free space" hint).
Future<int> downloadedBytes() async {
  final dir = await BookLibrary.instance.root();
  var total = 0;
  await for (final f in dir.list(recursive: true)) {
    if (f is File) total += await f.length();
  }
  return total;
}
