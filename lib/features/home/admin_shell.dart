import 'package:flutter/material.dart';

import '../arsip/arsip_screen.dart';
import '../auth/login_screen.dart';
import '../gaji/gaji_screen.dart';
import '../setoran/setoran_screen.dart';

class AdminShell extends StatefulWidget {
  final AuthController auth;
  const AdminShell({super.key, required this.auth});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  late final _pages = [
    SetoranScreen(auth: widget.auth),
    ArsipScreen(auth: widget.auth),
    GajiScreen(auth: widget.auth),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              extended: true,
              minExtendedWidth: 168,
              backgroundColor: Colors.white,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments),
                  label: Text('Setoran'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Arsip'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('Gaji'),
                ),
              ],
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              sizing: StackFit.expand,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.payments_outlined),
                  selectedIcon: Icon(Icons.payments),
                  label: 'Setoran',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Arsip',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Gaji',
                ),
              ],
            ),
    );
  }
}
