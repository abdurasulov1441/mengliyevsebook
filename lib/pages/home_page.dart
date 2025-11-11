import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mengliyevsebook/app/router.dart';
import 'package:mengliyevsebook/pages/sign/login_screen.dart';
import 'package:mengliyevsebook/pages/user_page/user_home.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/utils/Errorpage.dart';
import 'package:mengliyevsebook/pages/admin/admin_page.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Map<String, dynamic>?> _futureUserStatus;

  Future<Map<String, dynamic>?> checkUserStatus() async {
    try {
      final response = await requestHelper.getWithAuth(
        '/api/users/${cache.getInt('user_id')}',
        log: true,
      );

      return response as Map<String, dynamic>?;
    } on UnauthenticatedError {
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _futureUserStatus = checkUserStatus();
  }

  void retryFetchUserStatus() {
    setState(() {
      _futureUserStatus = checkUserStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userToken = cache.getString('user_token');
    return FutureBuilder<Map<String, dynamic>?>(
      future: _futureUserStatus,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Image.asset('assets/images/logo.png', width: 200),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset('assets/images/logo.png', width: 200),
                ),
                Text('Internet bilan aloqa yo\'q'),
                ElevatedButton(
                  onPressed: retryFetchUserStatus,
                  child: Text('Qayta urinish'),
                ),
                SizedBox(height: 20),
                if (userToken != null)
                  ElevatedButton(
                    onPressed: () {
                      cache.clear();
                      context.go(Routes.loginScreen);
                    },
                    child: Text('Akkauntdan chiqish'),
                  ),
              ],
            ),
          );
        } else {
          final userData = snapshot.data!;

          final int? roleId = userData['role_id'] as int?;

          // if (roleId == null) {
          //   return const RoleSelectionPage();
          // }

          switch (roleId) {
            case 0:
              return const LoginScreen();
            case 1:
              return const UserHome();
            case 2:
              return const AdminPage();
            default:
              return const ErrorPage();
          }
        }
      },
    );
  }
}
