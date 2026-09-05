class BarisMutasi {
  final String? tanggalMutasi;
  final int jumlah;
  final String berita;
  final String rekening;

  const BarisMutasi({
    this.tanggalMutasi,
    required this.jumlah,
    required this.berita,
    required this.rekening,
  });

  Map<String, dynamic> toRpc() => {
    'tanggal_mutasi': tanggalMutasi,
    'jumlah': jumlah,
    'berita': berita,
    'rekening': rekening,
  };
}

class HasilMutasiCsv {
  final List<BarisMutasi> baris;
  final String? error;

  const HasilMutasiCsv(this.baris, [this.error]);
}

/// Parser mutasi bank CSV (bukan workbook harian SETORAN.xlsx).
class MutasiCsv {
  static const _jumlah = {
    'jumlah',
    'amount',
    'kredit',
    'credit',
    'nominal',
    'nilai',
    'transfer',
    'masuk',
    'kreditmutasi',
    'creditamount',
    'transactionamount',
    'nominalkredit',
  };

  static const _debit = {
    'debit',
    'debet',
    'keluar',
    'nominaldebit',
    'nominaldebet',
    'db',
  };

  static const _jenis = {
    'jenis',
    'type',
    'tipe',
    'dc',
    'crdb',
    'mutasi',
    'dk',
  };

  static const _tanggal = {
    'tanggal',
    'date',
    'tgl',
    'waktu',
    'posting',
    'tanggaltransaksi',
    'transactiondate',
    'tgltransaksi',
  };

  static const _berita = {
    'berita',
    'keterangan',
    'deskripsi',
    'remark',
    'narasi',
    'uraian',
    'narrative',
    'description',
    'keterangantransaksi',
  };

  static const _rekening = {
    'rekening',
    'account',
    'norek',
    'norekening',
    'akun',
    'namarekening',
    'accountname',
    'accountno',
  };

  static HasilMutasiCsv parse(String teks) {
    final raw = teks.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (raw.isEmpty) {
      return const HasilMutasiCsv([], 'Berkas CSV kosong.');
    }
    final lines = raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty);
    if (lines.isEmpty) {
      return const HasilMutasiCsv([], 'Berkas CSV kosong.');
    }
    final daftar = lines.toList();
    final sep = _pemisah(daftar.first);
    final header = _pecah(daftar.first, sep).map(_kunci).toList();
    final iJumlah = _cari(header, _jumlah);
    final iDebit = _cari(header, _debit);
    final iTgl = _cari(header, _tanggal);
    final iBerita = _cari(header, _berita);
    final iRek = _cari(header, _rekening);
    final iJenis = _cari(header, _jenis);
    if (iJumlah == null && iDebit == null) {
      return const HasilMutasiCsv(
        [],
        'Kolom jumlah/kredit tidak ketemu. Pakai header Jumlah, Kredit, atau Nominal.',
      );
    }
    final hasil = <BarisMutasi>[];
    for (var i = 1; i < daftar.length; i++) {
      final kol = _pecah(daftar[i], sep);
      if (iJenis != null && _jenisDebit(_isi(kol, iJenis))) continue;
      final kredit = iJumlah == null ? 0 : _uang(kol, iJumlah);
      final debit = iDebit == null ? 0 : _uang(kol, iDebit);
      if (debit > 0 && kredit <= 0) continue;
      if (kredit < 0) continue;
      final jumlah = kredit;
      if (jumlah <= 0) continue;
      if (beritaDebet(iBerita == null ? '' : _isi(kol, iBerita))) {
        continue;
      }
      hasil.add(
        BarisMutasi(
          tanggalMutasi: iTgl == null ? null : _tanggalIso(_isi(kol, iTgl)),
          jumlah: jumlah,
          berita: iBerita == null ? '' : _isi(kol, iBerita),
          rekening: iRek == null ? '' : _isi(kol, iRek),
        ),
      );
    }
    if (hasil.isEmpty) {
      return const HasilMutasiCsv(
        [],
        'Tidak ada baris kredit yang bisa dibaca.',
      );
    }
    return HasilMutasiCsv(hasil);
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

  static bool _jenisDebit(String s) {
    final t = s.trim().toUpperCase();
    return t == 'DB' ||
        t == 'D' ||
        t == 'DEBIT' ||
        t == 'DEBET' ||
        t == 'KELUAR' ||
        t == 'DR';
  }

  static final _reDebetBerita = RegExp(
    r'(^|[^A-Z0-9])(DB|DEBET|DEBIT)([^A-Z0-9]|$)',
    caseSensitive: false,
  );

  static bool beritaDebet(String s) => _reDebetBerita.hasMatch(s);

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
    if (n != null) {
      if (n < 0) return 0;
      return n.round();
    }
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  static String? _tanggalIso(String s) {
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) {
      return '${iso.year.toString().padLeft(4, '0')}-'
          '${iso.month.toString().padLeft(2, '0')}-'
          '${iso.day.toString().padLeft(2, '0')}';
    }
    final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$').firstMatch(s);
    if (m != null) {
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
      return '${y.toString().padLeft(4, '0')}-'
          '${mo.toString().padLeft(2, '0')}-'
          '${d.toString().padLeft(2, '0')}';
    }
    final m2 = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})$').firstMatch(s);
    if (m2 != null) {
      final d = int.parse(m2.group(1)!);
      final mo = int.parse(m2.group(2)!);
      if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
      final y = DateTime.now().year;
      return '$y-'
          '${mo.toString().padLeft(2, '0')}-'
          '${d.toString().padLeft(2, '0')}';
    }
    return null;
  }
}
