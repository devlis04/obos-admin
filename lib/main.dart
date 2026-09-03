import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'core/ui_feedback.dart';
import 'features/auth/login_screen.dart';
import 'features/home/admin_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');
  await dotenv.load(fileName: 'assets/supabase_config.txt');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    // ignore: deprecated_member_use
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    postgrestOptions: const PostgrestClientOptions(schema: 'gudang'),
  );
  runApp(const ObosAdminApp());
}

class ObosAdminApp extends StatefulWidget {
  const ObosAdminApp({super.key});

  @override
  State<ObosAdminApp> createState() => _ObosAdminAppState();
}

class _ObosAdminAppState extends State<ObosAdminApp> {
  final _auth = AuthController();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuth);
    _auth.cekSesi();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _auth.dispose();
    super.dispose();
  }

  void _onAuth() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Obos Admin',
      theme: AppTheme.light(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      home: _auth.muat
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _auth.masuk
          ? AdminShell(auth: _auth)
          : _LoginWithError(auth: _auth),
    );
  }
}

class _LoginWithError extends StatelessWidget {
  final AuthController auth;
  const _LoginWithError({required this.auth});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final err = auth.error;
      if (err != null && err.isNotEmpty && context.mounted) {
        showAppSnackBar(context, message: err);
        auth.error = null;
      }
    });
    return LoginScreen(auth: auth);
  }
}
