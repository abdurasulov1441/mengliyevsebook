import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';

class BuyBookScreen extends StatefulWidget {
  final Map book;

  const BuyBookScreen({super.key, required this.book});

  @override
  State<BuyBookScreen> createState() => _BuyBookScreenState();
}

class _BuyBookScreenState extends State<BuyBookScreen> {
  Map? paymentContact;
  bool loading = true;

  File? selectedImage;
  final commentController = TextEditingController();
  DateTime? approvedAt;

  @override
  void initState() {
    super.initState();
    loadContact();
  }

  Future<void> loadContact() async {
    try {
      final data = await requestHelper.getWithAuth("/api/references/contact/1");

      setState(() {
        paymentContact = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    }
  }

  Future<void> chooseImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<void> submitPayment() async {
    if (selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Skrinshot yuklang")));
      return;
    }

    if (approvedAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Vaqtni tanlang")));
      return;
    }
    final userId = cache.getInt("user_id");

    try {
      final formData = FormData.fromMap({
        "book_id": widget.book["id"],
        "user_id": userId,
        "comment": commentController.text.trim(),
        "approved_at": approvedAt.toString(),
        "image": await MultipartFile.fromFile(
          selectedImage!.path,
          filename: "payment.jpg",
        ),
      });

      final resp = await requestHelper.postWithAuthMultipart(
        "/api/payments/create-payment",
        formData,
        log: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("To‘lov yuborildi! Tasdiqlash kutilmoqda."),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    }
  }

  void pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: now,
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          approvedAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      appBar: AppBar(title: const Text("Kitobni sotib olish")),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : paymentContact == null
          ? const Center(child: Text("Ma'lumot topilmadi"))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // BOOK TITLE
                Text(
                  widget.book["title"],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  "Narxi: ${widget.book['price']} so‘m",
                  style: const TextStyle(fontSize: 20),
                ),

                const SizedBox(height: 20),

                // CARD WIDGET
                _buildPaymentCard(paymentContact!),

                const SizedBox(height: 25),
                const Text(
                  "To‘lov tasdig‘i",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                // CHOOSE IMAGE
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: chooseImage,
                      icon: const Icon(Icons.image),
                      label: const Text("Skrinshot yuklash"),
                    ),
                    const SizedBox(width: 12),
                    if (selectedImage != null)
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),

                const SizedBox(height: 16),

                // COMMENT
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: "Kommentariya (ixtiyoriy)",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                // DATE PICKER
                ElevatedButton.icon(
                  onPressed: pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    approvedAt == null
                        ? "Vaqtni tanlang"
                        : approvedAt.toString(),
                  ),
                ),

                const SizedBox(height: 25),

                ElevatedButton.icon(
                  onPressed: submitPayment,
                  icon: const Icon(Icons.send),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  label: const Text("To‘lovni yuborish"),
                ),
              ],
            ),
    );
  }

  Widget _buildPaymentCard(Map data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "To‘lov kartasi:",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),

          Text(
            data["card_number"],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            data["name"],
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),

          const SizedBox(height: 6),

          Text(
            data["phone"],
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
