// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:local_auth/local_auth.dart';
// import 'package:mengliyevsebook/services/db/cache.dart';
// import 'package:mengliyevsebook/style/app_colors.dart';
// import '../../app/router.dart';

// class PasscodeScreen extends ConsumerStatefulWidget {
//   const PasscodeScreen({super.key});

//   @override
//   ConsumerState createState() => _PasscodeScreenState();
// }

// class _PasscodeScreenState extends ConsumerState<PasscodeScreen> {
//   String _enteredPasscode = '';
//   bool _isConfirmationMode = false;
//   String _firstPasscode = '';

//   void _onPasscodeDigitPress(String digit, String lang) async {
//     setState(() {
//       if (_enteredPasscode.length < 4) {
//         _enteredPasscode += digit;
//       }
//       if (_enteredPasscode.length == 4) {
//         if (!_isConfirmationMode) {
//           _firstPasscode = _enteredPasscode;
//           _enteredPasscode = '';
//           _isConfirmationMode = true;
//         } else {
//           if (_enteredPasscode == _firstPasscode) {
//             _savePasscode(_firstPasscode);

//             GoRouter.of(context).go(Routes.homeScreen);
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text("enter_true_pin_code".tr()),
//               ),
//             );
//             _enteredPasscode = '';
//           }
//           _enteredPasscode = '';
//           _isConfirmationMode = false;
//         }
//       }
//     });
//   }

//   void _onBackspacePress() {
//     setState(() {
//       if (_enteredPasscode.isNotEmpty) {
//         _enteredPasscode =
//             _enteredPasscode.substring(0, _enteredPasscode.length - 1);
//       }
//     });
//   }

//   final LocalAuthentication auth = LocalAuthentication();
//   Future<void> _savePasscode(String passcode) async {
//     await cache.setString('passcode', passcode);
//     await cache.setBool('firstPasscode', true);

//     bool authenticated = false;
//     try {
//       authenticated = await auth.authenticate(
//         localizedReason: 'Barmoq izi yoki Face ID bilan tasdiqlang',
//         options: const AuthenticationOptions(
//           stickyAuth: true,
//           biometricOnly: true,
//         ),
//       );
//     } catch (e) {
//       print("❌ Biometrik autentifikatsiya xatosi: $e");
//     }

//     if (authenticated) {
//       await cache.setBool('biometric_enabled', true);
//       GoRouter.of(context).go(Routes.homeScreen);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content:
//               Text("Biometrik autentifikatsiya muvaffaqiyatsiz tugadi".tr()),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Column(
//         children: [
//           SizedBox(
//             height: 50,
//           ),
//           Image.asset(
//             'assets/images/logo.png',
//             width: 106,
//             height: 106,
//           ),
//           SizedBox(
//             height: 20,
//           ),
//           _isConfirmationMode
//               ? Text(
//                   'confirm_pin_code'.tr(),
//                   style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xff797979)),
//                 )
//               : Text(
//                   'enter_pin_code'.tr(),
//                   style: const TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xff797979)),
//                 ),
//           SizedBox(
//             height: 20,
//           ),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               _buildPasscodeDigit(
//                   _enteredPasscode.isNotEmpty ? _enteredPasscode[0] : '',
//                   _enteredPasscode.isNotEmpty),
//               _buildPasscodeDigit(
//                   _enteredPasscode.length >= 2 ? _enteredPasscode[1] : '',
//                   1 < _enteredPasscode.length),
//               _buildPasscodeDigit(
//                   _enteredPasscode.length >= 3 ? _enteredPasscode[2] : '',
//                   2 < _enteredPasscode.length),
//               _buildPasscodeDigit(
//                   _enteredPasscode.length >= 4 ? _enteredPasscode[3] : '',
//                   3 < _enteredPasscode.length),
//             ],
//           ),
//           SizedBox(
//             height: 20,
//           ),
//           Expanded(
//             child: Container(
//               decoration: const BoxDecoration(
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(30),
//                   topRight: Radius.circular(30),
//                 ),
//                 color: Color(0xffFFFFFF),
//               ),
//               child: Column(
//                 children: [
//                   SizedBox(
//                     height: 60,
//                   ),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       _buildPasscodeKeyboardButton('1', context),
//                       _buildPasscodeKeyboardButton('2', context),
//                       _buildPasscodeKeyboardButton('3', context),
//                     ],
//                   ),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       _buildPasscodeKeyboardButton('4', context),
//                       _buildPasscodeKeyboardButton('5', context),
//                       _buildPasscodeKeyboardButton('6', context),
//                     ],
//                   ),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       _buildPasscodeKeyboardButton('7', context),
//                       _buildPasscodeKeyboardButton('8', context),
//                       _buildPasscodeKeyboardButton('9', context),
//                     ],
//                   ),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         margin: const EdgeInsets.symmetric(
//                             horizontal: 10, vertical: 5),
//                         width: 80,
//                         height: 50,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(10),
//                           color: Colors.transparent,
//                         ),
//                       ),
//                       _buildPasscodeKeyboardButton('0', context),
//                       InkWell(
//                         onTap: () {
//                           _onBackspacePress();
//                         },
//                         child: Container(
//                           margin: const EdgeInsets.symmetric(
//                             horizontal: 10,
//                             vertical: 5,
//                           ),
//                           width: 80,
//                           height: 50,
//                           decoration: const BoxDecoration(
//                             shape: BoxShape.circle,
//                             color: Colors.transparent,
//                           ),
//                           child: const Icon(
//                             Icons.backspace_outlined,
//                             size: 30,
//                             color: Colors.black,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPasscodeDigit(String digit, bool isActive) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 10),
//       width: 30,
//       height: 30,
//       decoration: BoxDecoration(
//           border: Border.all(width: 1, color: Colors.grey.shade300),
//           borderRadius: BorderRadius.circular(30),
//           color: isActive ? AppColors.grade1 : Colors.white),
//       // child: Center(
//       //   child: isActive
//       //       ? Text(
//       //           digit,
//       //           style: const TextStyle(fontSize: 24, color: Colors.white),
//       //         )
//       //       : const Text(
//       //           "*",
//       //           style: TextStyle(fontSize: 24, color: Colors.white),
//       //         ),
//       // ),
//     );
//   }

//   Widget _buildPasscodeKeyboardButton(String label, BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       width: 90,
//       height: 80,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(10),
//         color: Colors.white,
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(40),
//         onTap: () => _onPasscodeDigitPress(label, context.locale.languageCode),
//         child: Center(
//           child: Text(
//             label,
//             style: const TextStyle(
//               fontSize: 24,
//               color: Colors.black,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
