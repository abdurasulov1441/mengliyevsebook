import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mengliyevsebook/app/router.dart';
import 'package:mengliyevsebook/services/gradientbutton.dart';
import 'package:mengliyevsebook/services/language/language_provider.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/toats/error.dart';
import 'package:mengliyevsebook/services/utils/toats/succes.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:mengliyevsebook/services/style/app_style.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  TextEditingController phoneTextInputController = TextEditingController(
    text: '+998 ',
  );
  final formKey = GlobalKey<FormState>();

  final _phoneNumberFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    if (!newValue.text.startsWith('+998 ')) {
      return TextEditingValue(
        text: '+998 ',
        selection: TextSelection.collapsed(offset: 5),
      );
    }

    String rawText = newValue.text
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(3);

    if (rawText.length > 9) {
      rawText = rawText.substring(0, 9);
    }

    String formattedText = '+998 ';
    if (rawText.isNotEmpty) {
      formattedText += '(${rawText.substring(0, min(2, rawText.length))}';
    }
    if (rawText.length > 2) {
      formattedText += ') ${rawText.substring(2, min(5, rawText.length))}';
    }
    if (rawText.length > 5) {
      formattedText += ' ${rawText.substring(5, min(7, rawText.length))}';
    }
    if (rawText.length > 7) {
      formattedText += ' ${rawText.substring(7)}';
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  });

  Future<void> login() async {
    final isValid = formKey.currentState!.validate();
    if (!isValid) return;

    try {
      final response = await requestHelper.post(
        '/api/services/zyber/auth/login',
        {'phone_number': phoneTextInputController.text.trim()},
        log: false,
      );

      if (response['status'] == 200) {
        String status = response['message'];
        showSuccessToast(context, 'PayGo', status);
        context.push(
          Routes.verfySMS,
          extra: phoneTextInputController.text.trim(),
        );
      } else if (response['status'] == 400) {
        String status = response['message'];
        showSuccessToast(context, 'PayGo', status);
        context.push(
          Routes.verfySMS,
          extra: phoneTextInputController.text.trim(),
        );
      } else {
        String status = response['message'];
        showErrorToast(context, 'PayGo', status);
      }
    } catch (error) {
      showErrorToast(context, 'PayGo', error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.ui,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: Form(
          key: formKey,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 40),

                // Row(
                //   mainAxisAlignment: MainAxisAlignment.end,
                //   children: [LanguageSelectionButton()],
                // ),
                SizedBox(height: 30),
                Image.asset('assets/images/logo.png', width: 200, height: 200),
                Text(
                  'Hush kelibsiz',
                  style: AppStyle.fontStyle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.grade1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    style: AppStyle.fontStyle.copyWith(color: AppColors.grade1),
                    controller: phoneTextInputController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_phoneNumberFormatter],
                    validator: (phone) {
                      if (phone == null || phone.isEmpty) {
                        return 'Telefon raqamingizni kiriting';
                      } else if (!RegExp(
                        r'^\+998 \(\d{2}\) \d{3} \d{2} \d{2}$',
                      ).hasMatch(phone)) {
                        return 'Telefon raqamingizni to\'g\'ri kiriting';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.asset(
                          'assets/icons/phone.svg',
                          width: 10,
                          height: 10,
                          color: AppColors.grade1,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Telefon raqam',
                      hintStyle: AppStyle.fontStyle.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                GradientButton(
                  onPressed: () {
                    context.push(Routes.homeScreen);
                  },

                  // login,
                  text: 'Kirish',
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Akkuntingiz yo\'qmi?',
                      style: AppStyle.fontStyle,
                    ).tr(),
                    const SizedBox(width: 5),
                    TextButton(
                      onPressed: () {
                        context.push(Routes.register);
                      },
                      child: Text(
                        'Ro\'yxatdan o\'tish',
                        style: AppStyle.fontStyle.copyWith(
                          color: AppColors.grade1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
