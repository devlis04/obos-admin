import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Gulir vertikal halaman + scrollbar yang selalu kelihatan.
class GulirHalaman extends StatelessWidget {
  const GulirHalaman({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: controller,
        primary: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        child: child,
      ),
    );
  }
}

/// Tabel lebar: geser kiri-kanan, roda mouse vertikal tetap menggulir halaman.
class GulirMendatar extends StatelessWidget {
  const GulirMendatar({
    super.key,
    required this.induk,
    required this.child,
  });

  final ScrollController induk;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent || !induk.hasClients) return;
        if (event.scrollDelta.dy.abs() < event.scrollDelta.dx.abs()) return;
        final pos = induk.position;
        final next = (pos.pixels + event.scrollDelta.dy).clamp(
          pos.minScrollExtent,
          pos.maxScrollExtent,
        );
        if (next != pos.pixels) {
          induk.jumpTo(next);
        }
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        primary: false,
        child: child,
      ),
    );
  }
}
