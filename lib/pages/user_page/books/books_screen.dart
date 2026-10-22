import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/book_reader_page.dart';
import 'package:mengliyevsebook/services/books/book_library.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';

/// "Mening kitoblarim": bought and free books. Tap downloads the book once
/// (package from the server), after that it opens offline.
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> myBooks = [];
  final Map<String, double> downloadProgress = {};
  final Map<String, int?> localVersions = {};

  @override
  void initState() {
    super.initState();
    _fetchMyBooks();
  }

  Future<void> _fetchMyBooks() async {
    setState(() {
      isLoading = myBooks.isEmpty;
      errorMessage = null;
    });
    try {
      final resp = await requestHelper.getWithAuth('/api/books/my-books');
      myBooks = resp is Map && resp['books'] is List ? resp['books'] : [];
      await _checkLocal();
    } catch (e) {
      errorMessage = "Kitoblarni yuklab bo'lmadi. Internetni tekshiring.";
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _checkLocal() async {
    for (final b in myBooks) {
      final id = b['id'].toString();
      localVersions[id] = await BookLibrary.instance.localVersion(id);
    }
  }

  Future<void> _open(Map book) async {
    final id = book['id'].toString();
    if (downloadProgress.containsKey(id)) return;
    final needsDownload = !(await BookLibrary.instance.isUpToDate(book));
    if (!mounted) return;
    if (needsDownload) setState(() => downloadProgress[id] = 0);
    try {
      await openBook(context, book, onProgress: (p) {
        if (mounted) setState(() => downloadProgress[id] = p);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      downloadProgress.remove(id);
      // Refresh progress percentages after reading.
      await _fetchMyBooks();
    }
  }

  Future<void> _remove(Map book) async {
    final id = book['id'].toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Qurilmadan o'chirish"),
        content: Text("\"${book['title']}\" telefoningizdan o'chiriladi. Keyin qayta yuklab olishingiz mumkin. Xatcho'p va belgilar saqlanib qoladi."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Bekor')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("O'chirish")),
        ],
      ),
    );
    if (ok != true) return;
    await BookLibrary.instance.remove(id);
    await _checkLocal();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      appBar: AppBar(
        title: const Text('Mening kitoblarim'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchMyBooks,
              child: errorMessage != null && myBooks.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 160),
                      Center(child: Text(errorMessage!, textAlign: TextAlign.center)),
                      Center(child: TextButton(onPressed: _fetchMyBooks, child: const Text('Qayta urinish'))),
                    ])
                  : myBooks.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 140),
                          Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Center(child: Text("Hozircha kitoblar yo'q", style: TextStyle(fontSize: 18, color: Colors.grey))),
                          const SizedBox(height: 8),
                          const Center(child: Text("Do'kondan kitob sotib oling", style: TextStyle(fontSize: 14, color: Colors.grey))),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: myBooks.length,
                          itemBuilder: (_, i) => _bookTile(myBooks[i]),
                        ),
            ),
    );
  }

  Widget _bookTile(Map book) {
    final id = book['id'].toString();
    final img = Constants.fileUrl(book['photo']);
    final local = localVersions[id];
    final remote = (book['package_version'] as num?)?.toInt() ?? 0;
    final downloaded = local != null;
    final outdated = downloaded && local < remote;
    final progress = downloadProgress[id];
    final percent = ((book['progress'] as num?) ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(book),
        onLongPress: downloaded ? () => _remove(book) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: img != null
                    ? Image.network(img, width: 52, height: 76, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(book))
                    : _placeholder(book),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book['title'] ?? "Noma'lum", maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(book['author']?['uz']?.toString().isNotEmpty == true ? book['author']['uz'] : 'Muallif', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    if (progress != null) ...[
                      LinearProgressIndicator(value: progress > 0 ? progress : null, backgroundColor: Colors.grey.shade300, valueColor: AlwaysStoppedAnimation(AppColors.grade1)),
                      const SizedBox(height: 4),
                      Text('Yuklanmoqda ${(progress * 100).round()}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ] else ...[
                      if (percent > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(value: percent, minHeight: 4, backgroundColor: Colors.grey.shade300, valueColor: AlwaysStoppedAnimation(AppColors.grade1)),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        [
                          if (percent > 0) "${(percent * 100).round()}% o'qildi",
                          if (book['reading_minutes'] != null && book['reading_minutes'] > 0) '~${(book['reading_minutes'] / 60).ceil()} soat',
                          if (book['is_free'] == true) 'bepul',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                outdated ? Icons.system_update_alt : (downloaded ? Icons.menu_book : Icons.download),
                color: downloaded && !outdated ? Colors.green : AppColors.grade1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(Map book) => Container(
        width: 52,
        height: 76,
        color: AppColors.grade1.withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Text(((book['title'] ?? '?') as String).isNotEmpty ? (book['title'] as String)[0] : '?', style: TextStyle(fontSize: 22, color: AppColors.grade1, fontWeight: FontWeight.bold)),
      );
}
