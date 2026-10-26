/// Formatting helpers (Uzbek).
String formatMoney(dynamic value) {
  final n = (value is num ? value : num.tryParse('$value') ?? 0).round();
  final neg = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return "${neg ? '−' : ''}$buf so'm";
}

String formatPrice(Map book) => book['is_free'] == true ? 'Bepul' : formatMoney(book['price']);

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  // SQLite "2026-10-26 12:00:00" is UTC.
  return DateTime.tryParse(s.contains('T') ? s : '${s.replaceFirst(' ', 'T')}Z')?.toLocal();
}

const _months = ['yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun', 'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'];

String formatDate(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '';
  return '${d.day}-${_months[d.month - 1]} ${d.year}';
}

String formatPeriod(String? period) {
  if (period == null || period.length < 7) return period ?? '';
  final m = int.tryParse(period.substring(5, 7)) ?? 1;
  return '${_months[m - 1][0].toUpperCase()}${_months[m - 1].substring(1)} ${period.substring(0, 4)}';
}

String timeAgo(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'hozirgina';
  if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
  if (diff.inHours < 24) return '${diff.inHours} soat oldin';
  if (diff.inDays < 7) return '${diff.inDays} kun oldin';
  return formatDate(v);
}

String readingTime(dynamic minutes) {
  final m = (minutes as num?)?.toInt() ?? 0;
  if (m <= 0) return '';
  if (m < 60) return '$m daqiqa';
  final h = m / 60;
  return '~${h < 10 ? h.toStringAsFixed(h < 2 ? 1 : 0) : h.round()} soat';
}

String plural(int n, String word) => '$n $word';
