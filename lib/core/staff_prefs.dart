import 'package:shared_preferences/shared_preferences.dart';

class StaffPrefs {
  static const _isLogin = 'is_login';
  static const _email = 'saved_user_email';

  static Future<bool> localIsLogin() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_isLogin) ?? false;
  }

  static Future<String?> savedEmail() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_email);
  }

  static Future<void> tandaiMasuk(String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_isLogin, true);
    await p.setString(_email, email);
  }

  static Future<void> tandaiKeluar() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_isLogin, false);
    await p.remove(_email);
  }
}
