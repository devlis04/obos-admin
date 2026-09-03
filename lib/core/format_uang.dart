import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _uang = NumberFormat.decimalPattern('id');

String formatUang(num? n) => _uang.format(n ?? 0);

int angkaTeks(String s) {
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}

class FormatRibuan extends TextInputFormatter {
  const FormatRibuan({this.kosong = '0'});

  final String kosong;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return TextEditingValue(
        text: kosong,
        selection: TextSelection.collapsed(offset: kosong.length),
      );
    }
    final teks = formatUang(int.parse(digits));
    return TextEditingValue(
      text: teks,
      selection: TextSelection.collapsed(offset: teks.length),
    );
  }
}
