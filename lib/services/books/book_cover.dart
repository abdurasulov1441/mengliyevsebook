import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';

/// Book cover: a picture from the server ("/covers/x.jpg"), from the app
/// bundle ("asset:assets/..." in local mode), or a generated cover with the
/// title set in Literata. Drawn like a printed book: rounded, with a spine
/// highlight and a soft shadow.
class BookCover extends StatelessWidget {
  final Map book;
  final double width;
  final double height;
  final bool shadow;

  const BookCover({super.key, required this.book, this.width = 52, this.height = 76, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    final photo = book['photo']?.toString();
    Widget image;
    if (photo != null && photo.startsWith('asset:')) {
      image = Image.asset(photo.substring(6), width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _generated());
    } else if (Constants.fileUrl(photo) != null) {
      image = Image.network(Constants.fileUrl(photo)!, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _generated());
    } else {
      image = _generated();
    }
    final radius = BorderRadius.only(
      topLeft: Radius.circular(width * 0.04 + 2),
      bottomLeft: Radius.circular(width * 0.04 + 2),
      topRight: Radius.circular(width * 0.07 + 3),
      bottomRight: Radius.circular(width * 0.07 + 3),
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow
            ? [
                BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: width * 0.18, offset: Offset(0, width * 0.08)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            // Spine: a thin light/dark band on the left like a real binding.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width * 0.07 + 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.black.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.05),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _generated() {
    final title = (book['title'] ?? '').toString();
    final author = (book['author'] is Map ? book['author']['uz'] : '')?.toString() ?? '';
    // djb2 over the book id: the same book always gets the same colour.
    var seed = 5381;
    for (final ch in '${book['id'] ?? title}'.codeUnits) {
      seed = ((seed * 33) ^ ch) & 0x7fffffff;
    }
    final colors = AppPalette.coverGradients[seed % AppPalette.coverGradients.length];
    // Long words must fit on one line: shrink the type for them.
    final longest = title.split(RegExp(r'\s+')).fold<int>(1, (m, w) => w.length > m ? w.length : m);
    final titleSize = (width * 0.115).clamp(0.0, (width * 0.7) / (longest * 0.66));
    final small = width < 70;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
      padding: EdgeInsets.fromLTRB(width * 0.14, height * 0.09, width * 0.1, height * 0.07),
      child: small
          ? Center(
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : '?',
                style: TextStyle(fontFamily: AppFonts.book, fontFamilyFallback: AppFonts.fallback, fontSize: width * 0.45, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.92)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1.5, width: width * 0.3, color: Colors.white.withValues(alpha: 0.55)),
                SizedBox(height: height * 0.05),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 6,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontFamily: AppFonts.book,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: titleSize,
                      height: 1.18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (author.isNotEmpty)
                  Text(
                    author,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: AppFonts.ui, fontSize: width * 0.065, height: 1.25, color: Colors.white.withValues(alpha: 0.8)),
                  ),
              ],
            ),
    );
  }
}
