// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:go_router/go_router.dart';
// import 'package:local_auth/local_auth.dart';
// import 'package:logger/logger.dart';
// import 'package:mengliyevsebook/services/db/cache.dart';
// import 'package:mengliyevsebook/style/app_colors.dart';
// import '../../app/router.dart';

// class InitialPasscode extends StatefulWidget {
//   const InitialPasscode({super.key});

//   @override
//   _InitialPasscodeState createState() => _InitialPasscodeState();
// }

// class _InitialPasscodeState extends State<InitialPasscode> {
//   String _enteredPasscode = '';
//   bool isChecked = false;

//   @override
//   void initState() {
//     _getAvailableBiometrics();
//     getValueFaceId();
//     getPasscode();

//     super.initState();
//     auth.isDeviceSupported().then((bool isSupported) => setState(() =>
//         _supportState =
//             isSupported ? _SupportState.supported : _SupportState.unsupported));
//   }

//   void getValueFaceId() async {
//     _authenticateWithBiometrics();

//     setState(() {});
//   }

//   String? passCode;

//   void getPasscode() async {
//     passCode = cache.getString("passcode");
//   }

//   int _shakeCount = 0;
//   bool _isShaking = false;
//   bool wrongPinCode = false;

//   void _startShakeAnimation() async {
//     while (_isShaking && _shakeCount < 4) {
//       await Future.delayed(const Duration(milliseconds: 100));
//       setState(() {
//         _shakeCount++;
//       });
//     }
//     setState(() {
//       _isShaking = false;
//       _shakeCount = 0;
//     });
//   }

//   List<BiometricType>? _availableBiometrics;

//   Future<void> _getAvailableBiometrics() async {
//     late List<BiometricType> availableBiometrics;
//     try {
//       availableBiometrics = await auth.getAvailableBiometrics();
//     } on PlatformException catch (e) {
//       availableBiometrics = <BiometricType>[];
//       print(e);
//     }
//     if (!mounted) {
//       return;
//     }

//     setState(() {
//       _availableBiometrics = availableBiometrics;
//     });
//   }

//   void checkPasscode(String digit) async {
//     setState(() {
//       if (_enteredPasscode.length < 4) {
//         _enteredPasscode += digit;
//       }

//       if (_enteredPasscode.length == 4) {
//         if (_enteredPasscode == passCode) {
//           GoRouter.of(context).go(Routes.homeScreen);
//         } else {
//           _isShaking = true;
//           wrongPinCode = true;
//           _startShakeAnimation();
//           print("3");
//         }
//         _enteredPasscode = '';
//         print("4");

//         setState(() {});
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

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SizedBox(
//               height: 80,
//             ),
//             Image.asset(
//               'assets/images/logo.png',
//               width: 106,
//               height: 106,
//             ),
//             Text("enter_pin_code".tr(),
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black,
//                 )),
//             SizedBox(
//               height: 40,
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 _buildPasscodeDigit(
//                     _enteredPasscode.isNotEmpty ? _enteredPasscode[0] : '',
//                     _enteredPasscode.isNotEmpty),
//                 _buildPasscodeDigit(
//                     _enteredPasscode.length >= 2 ? _enteredPasscode[1] : '',
//                     1 < _enteredPasscode.length),
//                 _buildPasscodeDigit(
//                     _enteredPasscode.length >= 3 ? _enteredPasscode[2] : '',
//                     2 < _enteredPasscode.length),
//                 _buildPasscodeDigit(
//                     _enteredPasscode.length >= 4 ? _enteredPasscode[3] : '',
//                     3 < _enteredPasscode.length),
//               ],
//             ),
//             SizedBox(
//               height: 20,
//             ),
//             Expanded(
//               child: Container(
//                 decoration: const BoxDecoration(
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(30),
//                     topRight: Radius.circular(30),
//                   ),
//                   color: Color(0xffFFFFFF),
//                 ),
//                 child: Column(
//                   children: [
//                     SizedBox(
//                       height: 60,
//                     ),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         _buildPasscodeKeyboardButton('1'),
//                         _buildPasscodeKeyboardButton('2'),
//                         _buildPasscodeKeyboardButton('3'),
//                       ],
//                     ),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         _buildPasscodeKeyboardButton('4'),
//                         _buildPasscodeKeyboardButton('5'),
//                         _buildPasscodeKeyboardButton('6'),
//                       ],
//                     ),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         _buildPasscodeKeyboardButton('7'),
//                         _buildPasscodeKeyboardButton('8'),
//                         _buildPasscodeKeyboardButton('9'),
//                       ],
//                     ),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         InkWell(
//                           customBorder: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           onTap: () async {
//                             await cache.clear();
//                             GoRouter.of(context).go(Routes.roleSelect);
//                           },
//                           child: Container(
//                             margin: const EdgeInsets.symmetric(
//                                 horizontal: 10, vertical: 5),
//                             width: 80,
//                             height: 50,
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(24),
//                             ),
//                             child: const Center(
//                                 child: Icon(Icons.arrow_back,
//                                     color: Colors.black)),
//                           ),
//                         ),
//                         _buildPasscodeKeyboardButton('0'),
//                         _enteredPasscode.isNotEmpty
//                             ? InkWell(
//                                 customBorder: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 onTap: () {
//                                   _onBackspacePress();
//                                 },
//                                 child: Container(
//                                   margin: const EdgeInsets.symmetric(
//                                       horizontal: 10, vertical: 5),
//                                   width: 80,
//                                   height: 50,
//                                   decoration: const BoxDecoration(
//                                       shape: BoxShape.circle,
//                                       color: Colors.transparent),
//                                   child: const Icon(
//                                     Icons.backspace_outlined,
//                                     size: 30,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                               )
//                             : Container(
//                                 margin: const EdgeInsets.symmetric(
//                                     horizontal: 10, vertical: 5),
//                                 width: 80,
//                                 height: 50,
//                                 decoration: const BoxDecoration(
//                                     shape: BoxShape.circle,
//                                     color: Colors.transparent),
//                                 child: _supportState == _SupportState.supported
//                                     ? IconButton(
//                                         color: Colors.black,
//                                         onPressed: () {
//                                           Logger().e("Pressed");
//                                           _authenticateWithBiometrics();
//                                         },
//                                         icon: Icon(
//                                             _availableBiometrics?.length == 1
//                                                 ? Icons.face
//                                                 : Icons.fingerprint),
//                                       )
//                                     : const Text(''),
//                               ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(
//               height: 10,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   final LocalAuthentication auth = LocalAuthentication();
//   String _authorized = 'Not Authorized';

//   Future<void> _authenticateWithBiometrics() async {
//     bool authenticated = false;
//     try {
//       setState(() {
//         _authorized = 'Authenticating';
//       });
//       authenticated = await auth.authenticate(
//         localizedReason: 'Barmoq izi orqali tizimga kiring',
//         options: const AuthenticationOptions(
//           stickyAuth: true,
//           biometricOnly: true,
//         ),
//       );
//       setState(() {
//         _authorized = 'Authenticating';
//       });
//     } on PlatformException catch (e) {
//       print(e);
//       setState(() {
//         _authorized = 'Error - ${e.message}';
//       });
//       return;
//     }
//     if (!mounted) {
//       return;
//     }

//     final String message = authenticated ? 'Authorized' : 'Not Authorized';
//     setState(() {
//       _authorized = message;
//       if (_authorized == 'Authorized') {
//         return GoRouter.of(context).go(Routes.homeScreen);
//       }
//     });
//   }

//   _SupportState _supportState = _SupportState.unknown;

//   Widget _buildPasscodeDigit(String digit, bool isActive) {
//     final Color circleColor = isActive ? AppColors.grade1 : Colors.white;
//     return TweenAnimationBuilder<double>(
//       duration: const Duration(milliseconds: 100),
//       tween: Tween<double>(begin: 0.0, end: _isShaking ? 10.0 : 0.0),
//       onEnd: () {
//         if (_isShaking && _shakeCount < 4) {
//           setState(() {
//             _shakeCount++;
//           });
//         }
//       },
//       builder: (BuildContext context, double value, Widget? child) {
//         return Transform.translate(
//           offset: Offset(_shakeCount % 2 == 0 ? value : -value, 0.0),
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 10),
//             width: 30,
//             height: 30,
//             decoration: BoxDecoration(
//               border: Border.all(width: 1, color: Colors.grey.shade300),
//               borderRadius: BorderRadius.circular(30),
//               color: _isShaking ? const Color(0xff7F2828) : circleColor,
//             ),
//             // child: Center(
//             //   child: isActive
//             //       ? Text(
//             //           digit,
//             //           style: const TextStyle(fontSize: 24, color: Colors.white),
//             //         )
//             //       : const Text(
//             //           "*",
//             //           style: TextStyle(fontSize: 24, color: Colors.white),
//             //         ),
//             // ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildPasscodeKeyboardButton(String label) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       width: 90,
//       height: 80,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(10),
//         color: Colors.white,
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: TextButton(
//         style: ButtonStyle(
//           overlayColor: WidgetStateProperty.all(Colors.transparent),
//         ),
//         onPressed: () => checkPasscode(label),
//         child: Text(
//           label,
//           style: const TextStyle(
//             fontSize: 28,
//             color: Colors.black,
//           ),
//         ),
//       ),
//     );
//   }
// }

// enum _SupportState {
//   unknown,
//   supported,
//   unsupported,
// }
