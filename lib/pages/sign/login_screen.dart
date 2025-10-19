import 'package:email_validator/email_validator.dart';
import 'package:mengliyevsebook/app/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:mengliyevsebook/services/style/app_style.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isHiddenPassword = true;
  TextEditingController emailTextInputController = TextEditingController();
  TextEditingController passwordTextInputController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailTextInputController.dispose();
    passwordTextInputController.dispose();
    super.dispose();
  }

  void togglePasswordView() {
    setState(() {
      isHiddenPassword = !isHiddenPassword;
    });
  }

  // Future<void> login() async {
  //   final isValid = formKey.currentState!.validate();
  //   if (!isValid) return;

  //   try {
  //     await FirebaseAuth.instance.signInWithEmailAndPassword(
  //       email: emailTextInputController.text.trim(),
  //       password: passwordTextInputController.text.trim(),
  //     );
  //     context.go(Routes.loginScreen);
  //   } on FirebaseAuthException catch (e) {
  //     String message = 'Xatolik yuz berdi';
  //     if (e.code == 'user-not-found') {
  //       message = 'Foydalanuvchi topilmadi';
  //     } else if (e.code == 'wrong-password') {
  //       message = 'Noto‘g‘ri parol';
  //     }
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text(message)));
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 100),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Xush kelibsiz!',
                    style: AppStyle.fontStyle.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Tizimga kirishingiz mumkin',
                    style: AppStyle.fontStyle.copyWith(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  style: AppStyle.fontStyle,
                  controller: emailTextInputController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.grade1,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Emailingizni kiriting',
                    hintStyle: AppStyle.fontStyle.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                  validator: (email) =>
                      email != null && !EmailValidator.validate(email)
                      ? 'To\'g\'ri email kiriting'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  style: AppStyle.fontStyle,
                  controller: passwordTextInputController,
                  obscureText: isHiddenPassword,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.grade1,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Parolingizni kiriting',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isHiddenPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.grade1,
                      ),
                      onPressed: togglePasswordView,
                    ),
                  ),
                  validator: (value) => value != null && value.length < 6
                      ? 'Parol kamida 6 belgidan iborat bo\'lishi kerak'
                      : null,
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      // login();
                      context.push(Routes.homeScreen);
                    },
                    child: Text(
                      'Kirish',
                      style: AppStyle.fontStyle.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        // context.push(Routes.resetPasswordPage);
                      },
                      child: Text(
                        'Parolni unutdingizmi?',
                        style: AppStyle.fontStyle.copyWith(),
                      ),
                    ),
                  ],
                ),
                Center(
                  child: TextButton(
                    onPressed: () => context.push(Routes.loginScreen),
                    child: Text(
                      'Hisobingiz yo‘qmi? Ro‘yxatdan o‘ting',
                      style: AppStyle.fontStyle.copyWith(),
                    ),
                  ),
                ),

                Center(
                  child: TextButton(
                    onPressed: () => context.push(Routes.adminPage),
                    child: Text(
                      'Admin sifatida kirish',
                      style: AppStyle.fontStyle.copyWith(),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
