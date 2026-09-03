import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

class BarisMasukCsv {
  final String kode;
  final String nama;
  final int qty;
  final int harga;

  const BarisMasukCsv({
    required this.kode,
    required this.nama,
    required this.qty,
    required this.harga,
  });
}

class HasilMasukCsv {
  final List<BarisMasukCsv> baris;
  final String? error;

  const HasilMasukCsv(this.baris, [this.error]);
}

class BarangMasukCsv {
  static const namaBerkas = 'barang_masuk.csv';

  static const template =
      'kode_barang;nama_barang;qty;harga_beli\r\n';

  static Uint8List bytesTemplate([
    List<({String kode, String nama})> katalog = const [],
  ]) {
    final buf = StringBuffer()
      ..write('\uFEFF')
      ..write(template);
    for (final b in katalog) {
      final kode = b.kode.trim();
      if (kode.isEmpty) continue;
      buf
        ..write(_csvSel(kode))
        ..write(';')
        ..write(_csvSel(b.nama.trim()))
        ..write(';;\r\n');
    }
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }

  static const namaBerkasSku = 'sku_baru.csv';

  static Uint8List bytesTemplateSkuBaru(BarisMasukCsv contoh) {
    final buf = StringBuffer()
      ..write('\uFEFF')
      ..write(template)
      ..write(_csvSel(contoh.kode))
      ..write(';')
      ..write(_csvSel(contoh.nama))
      ..write(';')
      ..write(contoh.qty)
      ..write(';')
      ..write(contoh.harga)
      ..write('\r\n');
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }

  static BarisMasukCsv contohSkuBaru(
    List<({String kode, String nama, int harga})> katalog,
  ) {
    if (katalog.isEmpty) {
      return const BarisMasukCsv(
        kode: '1',
        nama: 'Contoh nama barang',
        qty: 1,
        harga: 10000,
      );
    }
    ({String kode, String nama, int harga})? terbaik;
    var nilai = -1;
    for (final b in katalog) {
      final n = int.tryParse(b.kode.trim());
      if (n == null) continue;
      if (n > nilai) {
        nilai = n;
        terbaik = b;
      }
    }
    terbaik ??= katalog.reduce(
      (a, b) => a.kode.compareTo(b.kode) >= 0 ? a : b,
    );
    var harga = terbaik.harga;
    if (harga <= 0) {
      for (final b in katalog) {
        if (b.harga > 0) {
          harga = b.harga;
          break;
        }
      }
    }
    if (harga <= 0) harga = 10000;
    final nama = terbaik.nama.trim().isEmpty
        ? 'Contoh nama barang'
        : terbaik.nama.trim();
    return BarisMasukCsv(
      kode: terbaik.kode,
      nama: nama,
      qty: 1,
      harga: harga,
    );
  }

  static String _namaRapi(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String? cekCocokKatalog(
    List<BarisMasukCsv> baris,
    Map<String, String> namaByKode,
  ) {
    for (final b in baris) {
      final namaDb = namaByKode[b.kode];
      if (namaDb == null) {
        return 'Kode ${b.kode} tidak ada di katalog. SKU baru unggah di Item baru.';
      }
      if (_namaRapi(namaDb) != _namaRapi(b.nama)) {
        return 'Nama ${b.kode} tidak cocok. Database: $namaDb. Berkas: ${b.nama}.';
      }
    }
    return null;
  }

  static String? cekSkuBaru(
    List<BarisMasukCsv> baris,
    Set<String> kodeAda,
  ) {
    for (final b in baris) {
      if (b.nama.trim().isEmpty) {
        return 'SKU baru ${b.kode}: nama wajib.';
      }
      if (kodeAda.contains(b.kode)) {
        return 'Kode ${b.kode} sudah ada. Jangan unggah sebagai SKU baru.';
      }
    }
    return null;
  }

  static const _kode = {
    'kode',
    'kodebarang',
    'sku',
    'kodebrg',
  };

  static const _nama = {
    'nama',
    'namabarang',
    'namabrg',
    'barang',
  };

  static const _qty = {
    'qty',
    'jumlah',
    'qtymasuk',
    'qyt',
  };

  static const _harga = {
    'harga',
    'hargabeli',
    'beli',
    'hargabeliunit',
  };

  static HasilMasukCsv parseBerkas(Uint8List bytes, String namaBerkas) {
    final nama = namaBerkas.trim().toLowerCase();
    if (nama.endsWith('.xls') && !nama.endsWith('.xlsx')) {
      return const HasilMasukCsv(
        [],
        'File .xls lama tidak dibaca. Simpan sebagai .xlsx atau CSV.',
      );
    }
    if (nama.endsWith('.xlsx')) {
      return _parseExcel(bytes);
    }
    return parse(utf8.decode(bytes, allowMalformed: true));
  }

  static HasilMasukCsv parse(String teks) {
    final raw = teks.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (raw.isEmpty) {
      return const HasilMasukCsv([], 'Berkas kosong.');
    }
    final daftar = raw
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (daftar.isEmpty) {
      return const HasilMasukCsv([], 'Berkas kosong.');
    }
    final sep = _pemisah(daftar.first);
    final grid = [for (final l in daftar) _pecah(l, sep)];
    return _dariGrid(grid);
  }

  static HasilMasukCsv _parseExcel(Uint8List bytes) {
    try {
      final book = Excel.decodeBytes(bytes);
      if (book.tables.isEmpty) {
        return const HasilMasukCsv([], 'Workbook Excel kosong.');
      }
      final sheet = book.tables.values.first;
      final grid = <List<String>>[];
      for (final row in sheet.rows) {
        final kol = [for (final c in row) _teksSel(c)];
        if (kol.every((s) => s.isEmpty)) continue;
        grid.add(kol);
      }
      return _dariGrid(grid);
    } catch (_) {
      return const HasilMasukCsv(
        [],
        'Excel tidak bisa dibaca. Simpan sebagai CSV, lalu unggah lagi.',
      );
    }
  }

  static HasilMasukCsv _dariGrid(List<List<String>> grid) {
    if (grid.isEmpty) {
      return const HasilMasukCsv([], 'Berkas kosong.');
    }
    final header = grid.first.map(_kunci).toList();
    final iKode = _cari(header, _kode);
    final iNama = _cari(header, _nama);
    final iQty = _cari(header, _qty);
    final iHarga = _cari(header, _harga);
    if (iKode == null || iNama == null || iQty == null || iHarga == null) {
      return const HasilMasukCsv(
        [],
        'Header wajib: kode_barang, nama_barang, qty, harga_beli.',
      );
    }
    final gabung = <String, BarisMasukCsv>{};
    for (var i = 1; i < grid.length; i++) {
      final kol = grid[i];
      final kode = _kodeBarang(_isi(kol, iKode));
      if (kode.isEmpty) continue;
      final qty = _uang(kol, iQty);
      final harga = _uang(kol, iHarga);
      if (qty <= 0 || harga <= 0) continue;
      final nama = _isi(kol, iNama);
      final lama = gabung[kode];
      if (lama == null) {
        gabung[kode] = BarisMasukCsv(
          kode: kode,
          nama: nama,
          qty: qty,
          harga: harga,
        );
      } else {
        gabung[kode] = BarisMasukCsv(
          kode: kode,
          nama: lama.nama.isEmpty ? nama : lama.nama,
          qty: lama.qty + qty,
          harga: harga > lama.harga ? harga : lama.harga,
        );
      }
    }
    if (gabung.isEmpty) {
      return const HasilMasukCsv(
        [],
        'Tidak ada baris dengan kode, qty, dan harga beli.',
      );
    }
    return HasilMasukCsv(gabung.values.toList());
  }

  static String _teksSel(Data? d) {
    if (d == null) return '';
    final v = d.value;
    if (v == null) return '';
    return v.toString().trim();
  }

  static String _pemisah(String header) {
    final titik = ';'.allMatches(header).length;
    final koma = ','.allMatches(header).length;
    final tab = '\t'.allMatches(header).length;
    if (tab > 0 && tab >= titik && tab >= koma) return '\t';
    if (titik > koma) return ';';
    return ',';
  }

  static List<String> _pecah(String line, String sep) {
    final out = <String>[];
    final buf = StringBuffer();
    var kutip = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (kutip && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          kutip = !kutip;
        }
      } else if (c == sep && !kutip) {
        out.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString().trim());
    return out;
  }

  static String _csvSel(String s) {
    if (s.contains(';') ||
        s.contains('"') ||
        s.contains(',') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _kunci(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int? _cari(List<String> header, Set<String> nama) {
    for (var i = 0; i < header.length; i++) {
      if (nama.contains(header[i])) return i;
    }
    return null;
  }

  static String _isi(List<String> kol, int i) =>
      i >= 0 && i < kol.length ? kol[i].trim() : '';

  static String _kodeBarang(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    final m = RegExp(r'^(\d+)\.0+$').firstMatch(t);
    if (m != null) return m.group(1)!;
    return t;
  }

  static int _uang(List<String> kol, int i) {
    final s = _isi(kol, i);
    if (s.isEmpty) return 0;
    var t = s.replaceAll(RegExp(r'\s'), '').replaceAll('Rp', '');
    if (t.contains(',') && t.contains('.')) {
      if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        t = t.replaceAll(',', '');
      }
    } else if (RegExp(r',\d{1,2}$').hasMatch(t)) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      t = t.replaceAll('.', '');
    }
    final n = num.tryParse(t);
    if (n != null) return n.round().abs();
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }
}
