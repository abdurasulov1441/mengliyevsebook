import 'package:flutter/foundation.dart';

/// Bumped whenever the user's books change (purchase, reading progress,
/// download/removal) so tabs kept alive in the IndexedStack can refresh.
final ValueNotifier<int> booksChanged = ValueNotifier<int>(0);

void notifyBooksChanged() => booksChanged.value++;
