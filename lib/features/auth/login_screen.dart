import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/network_probe.dart';
import '../../core/staff_prefs.dart';

class AuthController extends ChangeNotifier {
  final _sb = Supabase.instance.client;
  bool muat = true;
  bool masuk = false;
  String nama = 'Admin';
  String? error;

  bool _peranAdmin(String? peran) =>
      (peran ?? '').trim().toLowerCase() == 'admin';

  bool _loginMati(dynamic v) {
    if (v == false || v == 0) return true;
    final t = v?.toString().trim().toLowerCase() ?? '';
    return t == 'false' || t == 'f' || t == '0';
  }

  Future<Map<String, dynamic>?> _profil(String email) async {
    final row = await _sb
        .from('users')
        .select('nama, is_login, peran')
        .eq('email', email)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<void> cekSesi() async {
    muat = true;
    error = null;
    notifyListeners();
    final local = await StaffPrefs.localIsLogin();
    final saved = await StaffPrefs.savedEmail();
    final sesi = _sb.auth.currentSession;
    final emailSesi = sesi?.user.email;
    if (local &&
        saved != null &&
        sesi != null &&
        emailSesi != null &&
        saved.trim().toLowerCase() == emailSesi.trim().toLowerCase()) {
      if (!await NetworkProbe.hasConnection()) {
        nama = saved;
        muat = false;
        masuk = true;
        notifyListeners();
        return;
      }
      try {
        final profil = await _profil(saved);
        if (profil == null ||
            _loginMati(profil['is_login']) ||
            !_peranAdmin(profil['peran']?.toString())) {
          await _keluarLokal();
          muat = false;
          masuk = false;
          notifyListeners();
          return;
        }
        nama = profil['nama']?.toString() ?? 'Admin';
        muat = false;
        masuk = true;
        notifyListeners();
        return;
      } catch (_) {}
    }
    if (sesi != null) {
      try {
        await _sb.auth.signOut();
      } catch (_) {}
    }
    muat = false;
    masuk = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    muat = true;
    error = null;
    notifyListeners();
    if (!await NetworkProbe.hasConnection()) {
      error = 'Tidak ada internet. Sambungkan, lalu coba masuk lagi.';
      muat = false;
      notifyListeners();
      return;
    }
    try {
      final res = await _sb.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) {
        error = 'Email atau kata sandi tidak sesuai.';
        muat = false;
        notifyListeners();
        return;
      }
      final current = res.user!.email!;
      final profil = await _profil(current);
      if (!_peranAdmin(profil?['peran']?.toString())) {
        await _sb.auth.signOut();
        error = 'Akun ini bukan admin. Gunakan akun peran admin.';
        muat = false;
        notifyListeners();
        return;
      }
      await _sb.rpc('apply_own_is_login', params: {'p_is_login': true});
      await StaffPrefs.tandaiMasuk(current);
      nama = profil?['nama']?.toString() ?? 'Admin';
      muat = false;
      masuk = true;
      notifyListeners();
    } on AuthException catch (e) {
      error = e.message.toLowerCase().contains('invalid')
          ? 'Email atau kata sandi tidak sesuai.'
          : 'Tidak bisa masuk sekarang. Periksa internet, lalu coba lagi.';
      muat = false;
      notifyListeners();
    } catch (_) {
      error = 'Tidak bisa masuk sekarang. Periksa internet, lalu coba lagi.';
      muat = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (!await NetworkProbe.hasConnection()) {
      error = 'Tidak ada internet. Sambungkan, lalu tekan Keluar lagi.';
      notifyListeners();
      return;
    }
    try {
      await _sb.rpc('apply_own_is_login', params: {'p_is_login': false});
    } catch (_) {}
    await _keluarLokal();
    masuk = false;
    notifyListeners();
  }

  Future<void> _keluarLokal() async {
    await StaffPrefs.tandaiKeluar();
    try {
      await _sb.auth.signOut();
    } catch (_) {}
  }
}

class LoginScreen extends StatefulWidget {
  final AuthController auth;
  const LoginScreen({super.key, required this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _sandi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const OutlineInputBorder garisBiru = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppTheme.seed, width: 1.2),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Obos Admin',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.seed,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Untuk bagian admin',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      enabledBorder: garisBiru,
                      focusedBorder: garisBiru,
                      border: garisBiru,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sandi,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      enabledBorder: garisBiru,
                      focusedBorder: garisBiru,
                      border: garisBiru,
                      suffixIcon: IconButton(
                        color: AppTheme.seed,
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        final e = _email.text.trim();
                        final p = _sandi.text;
                        if (e.isEmpty || p.isEmpty) return;
                        widget.auth.login(e, p);
                      },
                      child: const Text('Masuk'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
