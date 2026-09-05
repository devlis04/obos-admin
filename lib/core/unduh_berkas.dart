import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void unduhBerkas({
  required Uint8List bytes,
  required String nama,
  String mime = 'application/octet-stream',
}) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nama
    ..rel = 'noopener'
    ..style.display = 'none';
  web.document.body?.appendChild(a);
  a.click();
  Timer(const Duration(seconds: 10), () {
    a.remove();
    web.URL.revokeObjectURL(url);
  });
}

void unduhCsv({required String nama, required String isi}) {
  unduhBerkas(
    bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(isi)]),
    nama: nama,
    mime: 'text/csv;charset=utf-8',
  );
}
