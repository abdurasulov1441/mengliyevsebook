import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/style/app_style.dart';

class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Audio Kitoblar',
          style: AppStyle.fontStyle.copyWith(fontSize: 20),
        ),
      ),
      body: Center(
        child: Text(
          'Tez kunda...',
          style: AppStyle.fontStyle.copyWith(fontSize: 30),
        ),
      ),
    );
  }
}
