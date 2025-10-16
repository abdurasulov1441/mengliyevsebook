import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

void showSuccessToast(BuildContext context, String title, String message) {
  toastification.show(
    context: context,
    animationBuilder: (context, animation, alignment, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.1),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    type: ToastificationType.success,
    style: ToastificationStyle.flat,
    title: Text(title.tr()),
    description: Text(message.tr()),
    alignment: Alignment.topRight,
    backgroundColor: Colors.green.shade700,
    foregroundColor: Colors.white,
    icon: const Icon(Icons.check_circle, color: Colors.white),
    autoCloseDuration: const Duration(seconds: 3),
  );
}
