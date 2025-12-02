import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/admin/book_stats_page/full_view.dart';
import 'package:mengliyevsebook/services/gradientbutton.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:mengliyevsebook/services/style/app_style.dart';

class PaymentAcceptPage extends StatefulWidget {
  const PaymentAcceptPage({super.key});

  @override
  State<PaymentAcceptPage> createState() => _PaymentAcceptPageState();
}

class _PaymentAcceptPageState extends State<PaymentAcceptPage> {
  List payments = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final res = await requestHelper.getWithAuth(
        '/api/payments/get-payments?page=1&limit=50',
        log: true,
      );

      if (res is Map && res['payments'] is List) {
        payments = res['payments']
            .where((p) => p["status_id"] == 1) 
            .toList();
      } else {
        errorMessage = "Неверный формат данных";
      }
    } catch (e) {
      errorMessage = "Ошибка загрузки: $e";
    }

    setState(() => isLoading = false);
  }

  Future<void> updatePaymentStatus(int id, int status) async {
    try {
      await requestHelper.putWithAuth('/api/payments/update-payment/$id', {
        "status": status,
        "comment": status == 2 ? "Tasdiqlandi" : "Rad etildi",
      }, log: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 2 ? "To'lov tasdiqlandi" : "To'lov rad etildi",
          ),
        ),
      );

      fetchPayments();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      body: Builder(
        builder: (_) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: fetchPayments,
                    child: const Text("Qayta urinish"),
                  ),
                ],
              ),
            );
          }

          if (payments.isEmpty) {
            return const Center(child: Text("Hozircha to‘lovlar yo‘q"));
          }

          return RefreshIndicator(
            onRefresh: fetchPayments,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final p = payments[index];

                return Card(
                  color: AppColors.backgroundColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kitob: ${p["book_title"] ?? "Ko‘rsatilmagan"}',
                          style: AppStyle.fontStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Foydalanuvchi: ${p["user_name"] ?? "-"}",
                          style: AppStyle.fontStyle,
                        ),
                        Text(
                          "Telefon: ${p["phone_number"] ?? "-"}",
                          style: AppStyle.fontStyle,
                        ),
                        Text(
                          "Summa: ${p["amount"]} so‘m",
                          style: AppStyle.fontStyle,
                        ),
                        Text(
                          "Izoh: ${p["comment"] ?? "-"}",
                          style: AppStyle.fontStyle,
                        ),
                        Text(
                          "Status: ${p["status"]?["uz"] ?? "-"}",
                          style: AppStyle.fontStyle,
                        ),
                        const SizedBox(height: 12),

                        if (p["receipt_image"] != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageView(
                                    imageUrl:
                                        "https://etimolog.uz/_files${p["receipt_image"]}",
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                "https://etimolog.uz/_files${p["receipt_image"]}",
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),
                        GradientButton(
                          onPressed: () => updatePaymentStatus(p["id"], 2),
                          text: "Tasdiqlash",
                        ),
                        const SizedBox(height: 8),

                        GradientButton(
                          onPressed: () => updatePaymentStatus(p["id"], 3),
                          text: "Rad etish",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
