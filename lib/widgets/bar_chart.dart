import 'package:flutter/material.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';

/// Small column chart (monthly income, daily sales). Tap a bar to see its value.
class BarChart extends StatefulWidget {
  final List<(String label, num value)> bars;
  final String Function(num value) format;
  final double height;
  final Color color;

  const BarChart({super.key, required this.bars, required this.format, this.height = 150, this.color = AppPalette.brand});

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    if (bars.isEmpty) {
      return SizedBox(height: widget.height, child: const Center(child: Text("Hali ma'lumot yo'q", style: AppText.caption)));
    }
    final max = bars.map((b) => b.$2).fold<num>(0, (a, b) => b > a ? b : a);
    final sel = _selected ?? bars.length - 1;
    // Show every n-th label so they do not overlap.
    final every = (bars.length / 7).ceil();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.format(bars[sel].$2), style: AppText.title.copyWith(color: widget.color)),
      Text(bars[sel].$1, style: AppText.caption),
      const SizedBox(height: 12),
      SizedBox(
        height: widget.height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selected = i),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: bars.length > 20 ? 1 : 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: max <= 0 ? 3 : (widget.height - 22) * (bars[i].$2 / max).clamp(0.02, 1).toDouble(),
                      decoration: BoxDecoration(
                        color: i == sel ? widget.color : widget.color.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 16,
                      child: i % every == 0 || i == bars.length - 1
                          ? FittedBox(child: Text(_short(bars[i].$1), style: AppText.caption.copyWith(fontSize: 10)))
                          : null,
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }

  static String _short(String label) => label.length > 6 ? label.substring(0, 3) : label;
}
