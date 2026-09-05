import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../setoran/setoran_screen.dart';

class AdminShell extends StatefulWidget {
  final AuthController auth;
  const AdminShell({super.key, required this.auth});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _bukaMenu() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: NavigationDrawer(
        selectedIndex: 0,
        onDestinationSelected: (_) => Navigator.of(context).pop(),
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
      body: SetoranScreen(auth: widget.auth, bukaMenu: _bukaMenu),
    );
  }
}
