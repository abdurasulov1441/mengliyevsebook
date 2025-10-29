import 'package:go_router/go_router.dart';
import 'package:mengliyevsebook/pages/admin/admin_page.dart';
import 'package:mengliyevsebook/pages/home_screen.dart';
import 'package:mengliyevsebook/pages/sign/login_screen.dart';
import 'package:mengliyevsebook/pages/sign/signup_screen.dart';
import 'package:mengliyevsebook/pages/sign/smsverify.dart';

abstract class Routes {
  static const homeScreen = '/homeScreen';
  static const adminPage = '/adminPage';
  static const register = '/register';
  static const verfySMS = '/verfySMS';
  static const loginScreen = '/loginScreen';
}

String _initialLocation() {
  return Routes.loginScreen;

  // final userToken = cache.getString("user_token");
  // String? refreshToken = cache.getString('refresh_token');
  // print('Refresh Token: $refreshToken');

  // if (userToken != null) {
  //   return Routes.homeScreen;
  // } else {
  //   return Routes.loginScreen;
  // }
}

Object? _initialExtra() {
  return {};
}

final router = GoRouter(
  initialLocation: _initialLocation(),
  initialExtra: _initialExtra(),
  routes: [
    GoRoute(
      path: Routes.homeScreen,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: Routes.adminPage,
      builder: (context, state) => const AdminPage(),
    ),
    GoRoute(
      path: Routes.loginScreen,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.register,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: Routes.verfySMS,
      builder: (context, state) {
        final phoneNumber = state.extra as String;
        return VerificationScreen(phoneNumber: phoneNumber);
      },
    ),
  ],
);
