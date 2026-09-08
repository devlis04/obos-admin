import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../karyawan/karyawan_screen.dart';
import '../setoran/setoran_screen.dart';

class AdminShell extends StatefulWidget {
  final AuthController auth;
  const AdminShell({super.key, required this.auth});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _halaman = 0;

  void _bukaMenu() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: NavigationDrawer(
        selectedIndex: _halaman,
        onDestinationSelected: (i) {
          Navigator.of(context).pop();
          setState(() => _halaman = i);
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 20, 16, 12),
            child: Text(
              'Obos Admin',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: Text('Setoran'),
          ),
          const NavigationDrawerDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: Text('Data karyawan'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 28, 8),
            child: Divider(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Keluar'),
              onTap: () {
                Navigator.of(context).pop();
                widget.auth.logout();
              },
            ),
          ),
        ],
      ),
      body: _halaman == 0
          ? SetoranScreen(auth: widget.auth, bukaMenu: _bukaMenu)
          : KaryawanScreen(auth: widget.auth, bukaMenu: _bukaMenu),
    );
  }
}
