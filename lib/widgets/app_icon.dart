import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Lucide icon set (ISC licence, assets/icons/lucide). Use the file name
/// without extension, e.g. `AppIcon('book-open')`.
class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    return SvgPicture.asset(
      'assets/icons/lucide/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

/// Round tappable icon (app bars, sheets).
class AppIconButton extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? background;
  final double size;
  final String? tooltip;

  const AppIconButton(this.icon, {super.key, this.onTap, this.color, this.background, this.size = 44, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background ?? Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: size, height: size, child: Center(child: AppIcon(icon, size: size * 0.48, color: color))),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
