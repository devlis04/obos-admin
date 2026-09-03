import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_dialog.dart';
import '../../core/app_theme.dart';
import '../../core/format_uang.dart';
import '../../core/network_probe.dart';
import '../../core/ui_feedback.dart';
import '../../core/unduh_berkas.dart';
import '../auth/login_screen.dart';
import 'mutasi_csv.dart';
import 'barang_masuk_csv.dart';

/// Cek harian setara sheet SETORAN Excel. Peta kolom: setoran_excel.md
class SetoranScreen extends StatefulWidget {
  final AuthController auth;
  const SetoranScreen({super.key, required this.auth});

  @override
  State<SetoranScreen> createState() => _SetoranScreenState();
}

class _SetoranScreenState extends State<SetoranScreen> {
  static const _rute = ['SBGP01', 'SBGP02', 'SBGP03', 'SBGP04'];
  static const _pecahanTunai = [
    (nilai: 100000, jenis: 'Lembar', label: '100.000'),
    (nilai: 50000, jenis: 'Lembar', label: '50.000'),
    (nilai: 20000, jenis: 'Lembar', label: '20.000'),
    (nilai: 10000, jenis: 'Lembar', label: '10.000'),
    (nilai: 5000, jenis: 'Lembar', label: '5.000'),
    (nilai: 2000, jenis: 'Lembar', label: '2.000'),
    (nilai: 1000, jenis: 'Lembar', label: '1.000'),
    (nilai: 1000, jenis: 'Koin', label: '1.000'),
    (nilai: 500, jenis: 'Koin', label: '500'),
  ];
  static const _lebarRute = 232.0;
  static const _lebarNilai = 236.0;
  static const _teksIsi = 14.0;
  static const _garisKolom = TableBorder(
    verticalInside: BorderSide(color: Color(0xFF8FB4D9), width: 1),
  );
  final _sb = Supabase.instance.client;
  DateTime _hari = DateTime.now();
  bool _muat = true;
  bool _proses = false;
  List<Map<String, dynamic>> _truk = [];
  List<Map<String, dynamic>> _mutasi = [];
  List<Map<String, dynamic>> _pengirim = [];
  List<Map<String, dynamic>> _gudang = [];
  List<Map<String, dynamic>> _masuk = [];

  String get _iso => DateFormat('yyyy-MM-dd').format(_hari);

  String get _judulHari => DateFormat('EEEE d/MM/yyyy', 'id').format(_hari);

  @override
  void initState() {
    super.initState();
    _hari = DateTime(_hari.year, _hari.month, _hari.day);
    _muatData();
  }

  int _angka(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  List<int> _qtyPecahan(Map<String, dynamic> row) {
    dynamic raw = row['pecahan_tunai'];
    if (raw is String && raw.isNotEmpty) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = null;
      }
    }
    if (raw is! List || raw.length != _pecahanTunai.length) {
      return List<int>.filled(_pecahanTunai.length, 0);
    }
    return raw.map(_angka).toList();
  }

  void _timpaBarisTruk(String rute, Map<String, dynamic> ubah) {
    final i = _truk.indexWhere(
      (r) => r['rute_pengirim']?.toString() == rute,
    );
    if (i < 0) return;
    final row = Map<String, dynamic>.from(_truk[i])..addAll(ubah);
    _selesaiHitung(row);
    setState(() {
      final next = List<Map<String, dynamic>>.from(_truk);
      next[i] = row;
      _truk = next;
    });
  }

  void _selesaiHitung(Map<String, dynamic> row) {
    final kasbon =
        _angka(row['kasbon_supir']) + _angka(row['kasbon_kenek']);
    final tunaiAdmin = _angka(row['tunai_admin']);
    final mutasi = _angka(row['transfer_mutasi']);
    row['tunai_beda'] = row['sudah_setor'] == true &&
        tunaiAdmin > 0 &&
        tunaiAdmin != _angka(row['tunai']);
    row['transfer_beda'] = row['sudah_setor'] == true &&
        mutasi > 0 &&
        mutasi != _angka(row['transfer']);
    row['sesa_cek'] = _angka(row['actual']) -
        mutasi -
        tunaiAdmin -
        _angka(row['bop']) -
        _angka(row['retur']) -
        kasbon;
  }

  void _pasangMutasi(List<Map<String, dynamic>> mutasi) {
    final jumlah = <String, int>{};
    for (final m in mutasi) {
      final st = m['status_cocok']?.toString() ?? '';
      if (st != 'cocok' && st != 'manual') continue;
      final rute = m['rute_pengirim']?.toString() ?? '';
      if (rute.isEmpty) continue;
      jumlah[rute] = (jumlah[rute] ?? 0) + _angka(m['jumlah']);
    }
    setState(() {
      _mutasi = mutasi;
      _truk = _truk.map((lama) {
        final row = Map<String, dynamic>.from(lama);
        final rute = row['rute_pengirim']?.toString() ?? '';
        row['transfer_mutasi'] = jumlah[rute] ?? 0;
        _selesaiHitung(row);
        return row;
      }).toList();
    });
  }

  Future<void> _muatMutasiSaja() async {
    final raw = await _sb.rpc(
      'admin_mutasi_lihat',
      params: {'p_tanggal': _iso},
    );
    if (!mounted) return;
    _pasangMutasi(
      (raw is List)
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [],
    );
  }

  Future<bool> _adaNet() async {
    if (await NetworkProbe.hasConnection()) return true;
    if (!mounted) return false;
    showAppSnackBar(
      context,
      message: 'Tidak ada internet. Sambungkan, lalu coba lagi.',
      warna: AppSnackBarTone.kuning,
    );
    return false;
  }

  Future<void> _muatData({bool layarPenuh = false}) async {
    if (layarPenuh && mounted) setState(() => _muat = true);
    if (!await NetworkProbe.hasConnection()) {
      if (!mounted) return;
      if (layarPenuh) setState(() => _muat = false);
      showAppSnackBar(
        context,
        message: 'Tidak ada internet. Data setoran tidak diunduh.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    try {
      final truk = await _sb.rpc(
        'admin_setoran_hari',
        params: {'p_tanggal': _iso},
      );
      final mutasi = await _sb.rpc(
        'admin_mutasi_lihat',
        params: {'p_tanggal': _iso},
      );
      List<Map<String, dynamic>> pengirim = [];
      List<Map<String, dynamic>> gudang = [];
      try {
        final orang = await _sb
            .from('karyawan')
            .select('nama_kunci,nama,urutan,peran')
            .inFilter('peran', ['pengirim', 'gudang'])
            .eq('aktif', true)
            .order('urutan');
        final absen = await _sb
            .from('absensi')
            .select('nama_kunci,hadir')
            .eq('tanggal', _iso);
        final hadir = <String, bool>{};
        for (final e in absen) {
          final m = Map<String, dynamic>.from(e);
          final k = m['nama_kunci']?.toString() ?? '';
          if (k.isNotEmpty) hadir[k] = m['hadir'] == true;
        }
        final isi = orang.map((e) {
          final m = Map<String, dynamic>.from(e);
          final k = m['nama_kunci']?.toString() ?? '';
          m['hadir'] = hadir[k] == true;
          return m;
        }).toList();
        pengirim = isi
            .where((m) => m['peran']?.toString() == 'pengirim')
            .toList();
        gudang = isi
            .where((m) => m['peran']?.toString() == 'gudang')
            .toList();
      } catch (_) {
        pengirim = [];
        gudang = [];
      }
      List<Map<String, dynamic>> masuk = [];
      try {
        final rawMasuk = await _sb.rpc(
          'admin_barang_masuk_hari',
          params: {'p_tanggal': _iso},
        );
        if (rawMasuk is List) {
          masuk = rawMasuk
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {
        masuk = [];
      }
      if (!mounted) return;
      setState(() {
        _truk = (truk is List)
            ? truk.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _mutasi = (mutasi is List)
            ? mutasi.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        _pengirim = pengirim;
        _gudang = gudang;
        _masuk = masuk;
        _muat = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (layarPenuh) {
        setState(() {
          _truk = [];
          _mutasi = [];
          _pengirim = [];
          _gudang = [];
          _masuk = [];
          _muat = false;
        });
      }
      showAppSnackBar(
        context,
        message:
            'Gagal memuat setoran. Jalankan admin_setoran.sql di Supabase, lalu coba lagi.',
      );
    }
  }

  Future<void> _muatMasukSaja() async {
    if (!await NetworkProbe.hasConnection()) return;
    try {
      final rawMasuk = await _sb.rpc(
        'admin_barang_masuk_hari',
        params: {'p_tanggal': _iso},
      );
      if (!mounted) return;
      setState(() {
        _masuk = rawMasuk is List
            ? rawMasuk.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
      });
    } catch (_) {}
  }

  int _idDariRpc(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<List<({int id, String nama})>> _muatDaftarSupplier() async {
    final raw = await _sb.rpc('admin_supplier_lihat');
    final out = <({int id, String nama})>[];
    if (raw is! List) return out;
    for (final e in raw) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final id = _idDariRpc(m['id']);
      final nama = (m['nama']?.toString() ?? '').trim();
      if (id <= 0 || nama.isEmpty) continue;
      out.add((id: id, nama: nama));
    }
    return out;
  }

  Future<void> _dialogBarangMasuk() async {
    if (_proses) return;
    if (!await _adaNet()) return;
    final baris = <_BarisMasuk>[];
    var daftarSupplier = <({int id, String nama})>[];
    var idSupplier = 0;
    final hargaSupplier = <String, int>{};
    try {
      daftarSupplier = await _muatDaftarSupplier();
      if (daftarSupplier.isNotEmpty) {
        idSupplier = daftarSupplier.first.id;
        final raw = await _sb.rpc(
          'admin_barang_masuk_lihat',
          params: {'p_tanggal': _iso, 'p_id_supplier': idSupplier},
        );
        final hargaRaw = await _sb.rpc(
          'admin_supplier_harga_lihat',
          params: {'p_id_supplier': idSupplier},
        );
        if (hargaRaw is List) {
          for (final e in hargaRaw) {
            if (e is! Map) continue;
            final m = Map<String, dynamic>.from(e);
            final kode = m['kode_barang']?.toString() ?? '';
            if (kode.isEmpty) continue;
            hargaSupplier[kode] = _angka(m['harga_beli']);
          }
        }
        if (raw is List) {
          for (final e in raw) {
            if (e is! Map) continue;
            final m = Map<String, dynamic>.from(e);
            baris.add(
              _BarisMasuk(
                kode: m['kode_barang']?.toString() ?? '',
                nama: m['nama_barang']?.toString() ?? '',
                qtySudah: _angka(m['qty']),
                nilaiSudah: _angka(m['nilai']),
                hargaAwal: _angka(m['harga_beli']),
              ),
            );
          }
        }
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message:
            'Gagal memuat barang masuk. Jalankan ulang arsip_harian.sql di Supabase.',
      );
      return;
    }
    if (!mounted) {
      for (final b in baris) {
        b.dispose();
      }
      return;
    }

    final cariCtrl = TextEditingController();
    final namaSupplierCtrl = TextEditingController();
    final kodeBaruCtrl = TextEditingController();
    final namaBaruCtrl = TextEditingController();
    final qtyBaruCtrl = TextEditingController();
    final hargaBaruCtrl = TextEditingController();
    var saran = <({String kode, String nama, int harga})>[];
    var tampilSkuBaru = false;
    var tampilSupplierBaru = false;
    Timer? tunda;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            void tambahBarang(
              String kode,
              String nama, {
              int qty = 0,
              int harga = 0,
            }) {
              final kodeN = kode.trim();
              if (kodeN.isEmpty) return;
              for (final b in baris) {
                if (b.kode == kodeN) {
                  cariCtrl.clear();
                  saran = [];
                  setLocal(() {});
                  return;
                }
              }
              baris.add(
                _BarisMasuk(
                  kode: kodeN,
                  nama: nama.trim(),
                  qtySudah: 0,
                  hargaAwal: hargaSupplier[kodeN] ?? harga,
                  qtyTambah: qty,
                ),
              );
              cariCtrl.clear();
              saran = [];
              setLocal(() {});
            }

            void terapkanBerkas(List<BarisMasukCsv> items) {
              for (final it in items) {
                _BarisMasuk? ada;
                for (final b in baris) {
                  if (b.kode == it.kode) {
                    ada = b;
                    break;
                  }
                }
                if (ada != null) {
                  ada.qtyCtrl.text = formatUang(ada.qty + it.qty);
                  final hargaPakai = it.harga > ada.harga ? it.harga : ada.harga;
                  if (hargaPakai > 0) {
                    ada.hargaCtrl.text = formatUang(hargaPakai);
                  }
                } else {
                  final hargaLama = hargaSupplier[it.kode] ?? 0;
                  baris.add(
                    _BarisMasuk(
                      kode: it.kode,
                      nama: it.nama,
                      qtySudah: 0,
                      hargaAwal: it.harga > hargaLama ? it.harga : hargaLama,
                      qtyTambah: it.qty,
                    ),
                  );
                }
              }
              setLocal(() {});
            }

            Future<List<({String kode, String nama, int harga})>?> muatKatalog() async {
              if (!await _adaNet()) return null;
              try {
                final raw = await _sb.rpc('admin_barang_katalog');
                final katalog = <({String kode, String nama, int harga})>[];
                if (raw is List) {
                  for (final e in raw) {
                    if (e is! Map) continue;
                    final m = Map<String, dynamic>.from(e);
                    final kode = (m['kode_barang']?.toString() ?? '').trim();
                    if (kode.isEmpty) continue;
                    katalog.add((
                      kode: kode,
                      nama: (m['nama_barang']?.toString() ?? '').trim(),
                      harga: _angka(m['harga_beli']),
                    ));
                  }
                }
                return katalog;
              } catch (_) {
                if (!mounted) return null;
                showAppSnackBar(
                  this.context,
                  message:
                      'Gagal memuat katalog. Jalankan ulang arsip_harian.sql di Supabase.',
                );
                return null;
              }
            }

            Future<void> unduhTemplate() async {
              final katalog = await muatKatalog();
              if (katalog == null || !mounted) return;
              unduhBerkas(
                bytes: BarangMasukCsv.bytesTemplate([
                  for (final b in katalog) (kode: b.kode, nama: b.nama),
                ]),
                nama: BarangMasukCsv.namaBerkas,
              );
              showAppSnackBar(
                this.context,
                message:
                    'Template ${BarangMasukCsv.namaBerkas}: ${katalog.length} barang. Isi qty dan harga beli.',
                warna: AppSnackBarTone.hijau,
              );
            }

            Future<void> unduhTemplateSku() async {
              final katalog = await muatKatalog();
              if (katalog == null || !mounted) return;
              final contoh = BarangMasukCsv.contohSkuBaru(katalog);
              unduhBerkas(
                bytes: BarangMasukCsv.bytesTemplateSkuBaru(contoh),
                nama: BarangMasukCsv.namaBerkasSku,
              );
              showAppSnackBar(
                this.context,
                message:
                    'Template ${BarangMasukCsv.namaBerkasSku}: ganti baris contoh, lalu unggah SKU baru.',
                warna: AppSnackBarTone.hijau,
              );
            }

            Future<HasilMasukCsv?> pilihBerkasMasuk() async {
              final pick = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: const ['csv', 'txt', 'xlsx'],
                withData: true,
              );
              if (pick == null || pick.files.isEmpty) return null;
              if (!mounted) return null;
              final f = pick.files.single;
              final bytes = f.bytes;
              if (bytes == null) {
                showAppSnackBar(
                  this.context,
                  message: 'Berkas tidak bisa dibaca.',
                );
                return null;
              }
              final hasil = BarangMasukCsv.parseBerkas(bytes, f.name);
              if (hasil.error != null) {
                showAppSnackBar(this.context, message: hasil.error!);
                return null;
              }
              return hasil;
            }

            Future<void> unggahBerkas() async {
              if (idSupplier <= 0) {
                showAppSnackBar(
                  this.context,
                  message: 'Pilih atau tambah supplier dulu.',
                  warna: AppSnackBarTone.kuning,
                );
                return;
              }
              final hasil = await pilihBerkasMasuk();
              if (hasil == null || !mounted) return;
              final katalog = await muatKatalog();
              if (katalog == null || !mounted) return;
              final namaByKode = {
                for (final b in katalog) b.kode: b.nama,
              };
              final salah = BarangMasukCsv.cekCocokKatalog(
                hasil.baris,
                namaByKode,
              );
              if (salah != null) {
                showAppSnackBar(
                  this.context,
                  message: salah,
                  warna: AppSnackBarTone.kuning,
                );
                return;
              }
              terapkanBerkas(hasil.baris);
              showAppSnackBar(
                this.context,
                message:
                    '${hasil.baris.length} barang dari berkas. Periksa, lalu Simpan.',
                warna: AppSnackBarTone.hijau,
              );
            }

            Future<void> unggahSkuBaru() async {
              if (idSupplier <= 0) {
                showAppSnackBar(
                  this.context,
                  message: 'Pilih atau tambah supplier dulu.',
                  warna: AppSnackBarTone.kuning,
                );
                return;
              }
              final hasil = await pilihBerkasMasuk();
              if (hasil == null || !mounted) return;
              final katalog = await muatKatalog();
              if (katalog == null || !mounted) return;
              final salah = BarangMasukCsv.cekSkuBaru(
                hasil.baris,
                {for (final b in katalog) b.kode},
              );
              if (salah != null) {
                showAppSnackBar(
                  this.context,
                  message: salah,
                  warna: AppSnackBarTone.kuning,
                );
                return;
              }
              terapkanBerkas(hasil.baris);
              showAppSnackBar(
                this.context,
                message:
                    '${hasil.baris.length} SKU baru dari berkas. Periksa, lalu Simpan.',
                warna: AppSnackBarTone.hijau,
              );
            }

            Future<void> pilihSupplier(int id) async {
              for (final b in baris) {
                b.dispose();
              }
              baris.clear();
              hargaSupplier.clear();
              try {
                final raw = await _sb.rpc(
                  'admin_barang_masuk_lihat',
                  params: {'p_tanggal': _iso, 'p_id_supplier': id},
                );
                final hargaRaw = await _sb.rpc(
                  'admin_supplier_harga_lihat',
                  params: {'p_id_supplier': id},
                );
                if (hargaRaw is List) {
                  for (final e in hargaRaw) {
                    if (e is! Map) continue;
                    final m = Map<String, dynamic>.from(e);
                    final kode = m['kode_barang']?.toString() ?? '';
                    if (kode.isEmpty) continue;
                    hargaSupplier[kode] = _angka(m['harga_beli']);
                  }
                }
                if (raw is List) {
                  for (final e in raw) {
                    if (e is! Map) continue;
                    final m = Map<String, dynamic>.from(e);
                    baris.add(
                      _BarisMasuk(
                        kode: m['kode_barang']?.toString() ?? '',
                        nama: m['nama_barang']?.toString() ?? '',
                        qtySudah: _angka(m['qty']),
                        nilaiSudah: _angka(m['nilai']),
                        hargaAwal: _angka(m['harga_beli']),
                      ),
                    );
                  }
                }
                idSupplier = id;
                if (ctx.mounted) setLocal(() {});
              } catch (_) {
                if (!mounted) return;
                showAppSnackBar(
                  this.context,
                  message: 'Gagal memuat data supplier.',
                );
              }
            }

            Future<void> tambahSupplier() async {
              final nama = namaSupplierCtrl.text.trim();
              if (nama.isEmpty) {
                showAppSnackBar(
                  this.context,
                  message: 'Isi nama supplier.',
                  warna: AppSnackBarTone.kuning,
                );
                return;
              }
              try {
                final id = _idDariRpc(
                  await _sb.rpc(
                    'admin_supplier_tambah',
                    params: {'p_nama': nama},
                  ),
                );
                if (!mounted) return;
                if (id <= 0) {
                  showAppSnackBar(
                    this.context,
                    message: 'Gagal menambah supplier.',
                  );
                  return;
                }
                daftarSupplier = await _muatDaftarSupplier();
                if (!mounted) return;
                namaSupplierCtrl.clear();
                tampilSupplierBaru = false;
                await pilihSupplier(id);
              } catch (_) {
                if (!mounted) return;
                showAppSnackBar(
                  this.context,
                  message: 'Gagal menambah supplier.',
                );
              }
            }

            void cariBarang(String q) {
              tunda?.cancel();
              final teks = q.trim();
              if (teks.length < 2) {
                setLocal(() => saran = []);
                return;
              }
              tunda = Timer(const Duration(milliseconds: 280), () async {
                try {
                  final raw = await _sb.rpc(
                    'admin_barang_cari',
                    params: {'p_cari': teks},
                  );
                  final next = <({String kode, String nama, int harga})>[];
                  if (raw is List) {
                    for (final e in raw) {
                      if (e is! Map) continue;
                      final m = Map<String, dynamic>.from(e);
                      next.add((
                        kode: m['kode_barang']?.toString() ?? '',
                        nama: m['nama_barang']?.toString() ?? '',
                        harga: _angka(m['harga_beli']),
                      ));
                    }
                  }
                  if (!ctx.mounted) return;
                  setLocal(() => saran = next);
                } catch (_) {
                  if (!ctx.mounted) return;
                  setLocal(() => saran = []);
                }
              });
            }

            void tambahBaru() {
              final kode = kodeBaruCtrl.text.trim();
              final nama = namaBaruCtrl.text.trim();
              final qty = angkaTeks(qtyBaruCtrl.text);
              final harga = angkaTeks(hargaBaruCtrl.text);
              if (kode.isEmpty || nama.isEmpty || qty <= 0 || harga <= 0) {
                showAppSnackBar(
                  this.context,
                  message: 'Item baru: isi kode, nama, qty, dan harga beli.',
                  warna: AppSnackBarTone.kuning,
                );
                return;
              }
              tambahBarang(kode, nama, qty: qty, harga: harga);
              kodeBaruCtrl.clear();
              namaBaruCtrl.clear();
              qtyBaruCtrl.clear();
              hargaBaruCtrl.clear();
            }

            int totalInput() => baris.fold<int>(0, (a, b) => a + b.nilai);
            int totalHariIni() =>
                baris.fold<int>(0, (a, b) => a + b.nilaiSudah) + totalInput();

            Future<void> simpan() async {
              if (idSupplier <= 0) {
                showAppSnackBar(
                  this.context,
                  message: 'Pilih atau tambah supplier dulu.',
                  warna: AppSnackBarTone.kuning,
                );
                return;
              }
              for (final b in baris) {
                if (b.kode.isEmpty || b.qty <= 0) continue;
                if (b.harga <= 0) {
                  showAppSnackBar(
                    this.context,
                    message: 'Harga beli wajib diisi untuk setiap qty masuk.',
                    warna: AppSnackBarTone.kuning,
                  );
                  return;
                }
              }
              final kirim = [
                for (final b in baris)
                  if (b.kode.isNotEmpty && b.qty > 0 && b.harga > 0)
                    {
                      'kode_barang': b.kode,
                      'nama_barang': b.nama,
                      'qty': b.qty,
                      'harga_beli': b.harga,
                    },
              ];
              if (kirim.isEmpty) {
                showAppSnackBar(
                  this.context,
                  message: 'Isi qty dan harga beli.',
                  warna: AppSnackBarTone.kuning,
                );
                return;
              }
              if (!await _adaNet()) return;
              try {
                final ok = await _sb.rpc(
                  'admin_barang_masuk_simpan',
                  params: {
                    'p_tanggal': _iso,
                    'p_id_supplier': idSupplier,
                    'p_baris': kirim,
                    'p_keterangan': '',
                  },
                );
                if (!mounted) return;
                if (ok == true) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  showAppSnackBar(
                    this.context,
                    message: 'Barang masuk $_iso disimpan.',
                    warna: AppSnackBarTone.hijau,
                  );
                  await _muatMasukSaja();
                } else {
                  showAppSnackBar(
                    this.context,
                    message: 'Gagal simpan. Arsip hari mungkin sudah dikunci.',
                    warna: AppSnackBarTone.kuning,
                  );
                }
              } catch (_) {
                if (!mounted) return;
                showAppSnackBar(
                  this.context,
                  message:
                      'Gagal simpan. Jalankan ulang arsip_harian.sql di Supabase.',
                );
              }
            }

            return AppDialog(
              title: const Text('Barang masuk'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih supplier dulu. Harga beli disimpan per supplier. Qty × harga, lalu ditambah ke stok.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey(idSupplier),
                      initialValue: idSupplier > 0 ? idSupplier : null,
                      isDense: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Supplier',
                      ),
                      items: [
                        for (final s in daftarSupplier)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text(s.nama),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) pilihSupplier(v);
                      },
                    ),
                    InkWell(
                      onTap: () =>
                          setLocal(() => tampilSupplierBaru = !tampilSupplierBaru),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Supplier baru',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              tampilSupplierBaru ? 'Sembunyikan' : 'Tampilkan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.seed,
                              ),
                            ),
                            Icon(
                              tampilSupplierBaru
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppTheme.seed,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (tampilSupplierBaru) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: namaSupplierCtrl,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Nama supplier baru',
                                hintStyle: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: tambahSupplier,
                            child: const Text('Tambah'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    _barisNilai('Total input', totalInput(), tebal: true),
                    _barisNilai('Total supplier ini', totalHariIni()),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cariCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Cari barang yang sudah ada',
                        hintStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 18),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onChanged: cariBarang,
                    ),
                    if (saran.isNotEmpty)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final s in saran)
                            ListTile(
                              dense: true,
                              title: Text(s.nama),
                              subtitle: Text(s.kode),
                              onTap: () =>
                                  tambahBarang(s.kode, s.nama, harga: s.harga),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: unduhTemplate,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Template'),
                        ),
                        TextButton.icon(
                          onPressed: unggahBerkas,
                          icon: const Icon(Icons.upload_file_outlined, size: 18),
                          label: const Text('Unggah barang masuk'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () =>
                          setLocal(() => tampilSkuBaru = !tampilSkuBaru),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Item baru',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              tampilSkuBaru ? 'Sembunyikan' : 'Tampilkan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.seed,
                              ),
                            ),
                            Icon(
                              tampilSkuBaru
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppTheme.seed,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (tampilSkuBaru) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: kodeBaruCtrl,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Kode',
                              hintStyle: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: namaBaruCtrl,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Nama',
                              hintStyle: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: qtyBaruCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12),
                            inputFormatters: const [FormatRibuan()],
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Qty',
                              hintStyle: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: hargaBaruCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12),
                            inputFormatters: const [FormatRibuan()],
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Harga beli',
                              hintStyle: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: tambahBaru,
                          child: const Text('Tambah'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: unduhTemplateSku,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Template SKU baru'),
                        ),
                        TextButton.icon(
                          onPressed: unggahSkuBaru,
                          icon: const Icon(
                            Icons.upload_file_outlined,
                            size: 18,
                          ),
                          label: const Text('Unggah SKU baru'),
                        ),
                      ],
                    ),
                    ],
                    const SizedBox(height: 12),
                    if (baris.isEmpty)
                      Text(
                        'Belum ada barang masuk tanggal ini.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      ...baris.asMap().entries.map((e) {
                        final i = e.key;
                        final b = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.nama.isEmpty ? b.kode : b.nama,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      b.qtySudah > 0
                                          ? '${b.kode} · hari ini ${formatUang(b.qtySudah)} / ${formatUang(b.nilaiSudah)}'
                                          : b.kode,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  b.nilai > 0 ? formatUang(b.nilai) : '–',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 64,
                                child: TextField(
                                  controller: b.qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                  inputFormatters: const [FormatRibuan()],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: '+Qty',
                                    hintStyle: TextStyle(fontSize: 11),
                                  ),
                                  onChanged: (_) => setLocal(() {}),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 88,
                                child: TextField(
                                  controller: b.hargaCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.right,
                                  inputFormatters: const [FormatRibuan()],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Harga',
                                    hintStyle: TextStyle(fontSize: 11),
                                  ),
                                  onChanged: (_) => setLocal(() {}),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                iconSize: 18,
                                onPressed: () {
                                  b.dispose();
                                  baris.removeAt(i);
                                  setLocal(() {});
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
                FilledButton(
                  onPressed: simpan,
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
    tunda?.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    cariCtrl.dispose();
    namaSupplierCtrl.dispose();
    kodeBaruCtrl.dispose();
    namaBaruCtrl.dispose();
    qtyBaruCtrl.dispose();
    hargaBaruCtrl.dispose();
    for (final b in baris) {
      b.dispose();
    }
  }

  Future<void> _cekOpname() async {
    if (_proses) return;
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      final header = await _sb
          .from('stok_opname')
          .select('status')
          .eq('tanggal', _iso)
          .limit(1);
      if (!mounted) return;
      if (header.isEmpty) {
        setState(() => _proses = false);
        showAppSnackBar(
          context,
          message: 'Belum ada input opname dari aplikasi gudang.',
          warna: AppSnackBarTone.kuning,
        );
        return;
      }
      final raw = await _sb.rpc(
        'admin_opname_lihat',
        params: {'p_tanggal': _iso},
      );
      if (!mounted) return;
      setState(() => _proses = false);
      if (raw is! List || raw.isEmpty) {
        showAppSnackBar(
          context,
          message: 'Belum ada input opname dari aplikasi gudang.',
          warna: AppSnackBarTone.kuning,
        );
        return;
      }
      final semua = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final beda = semua.where((r) => _angka(r['selisih_qty']) != 0).toList();
      if (beda.isEmpty) {
        showAppSnackBar(
          context,
          message: 'Opname cocok. Tidak ada selisih.',
          warna: AppSnackBarTone.hijau,
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: Text('Selisih opname (${beda.length})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in beda)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['nama_barang'] ?? r['kode_barang']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${r['kode_barang']}  ·  sistem ${r['sisa'] ?? 0}  ·  '
                        'fisik ${r['stok_fisik'] ?? 0}  ·  '
                        'selisih ${_angka(r['selisih_qty'])}  ·  '
                        'Rp ${formatUang(_angka(r['nilai_selisih']))}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _proses = false);
      showAppSnackBar(
        context,
        message:
            'Gagal cek opname. Jalankan ulang arsip_harian.sql, lalu coba lagi.',
      );
    }
  }

  Future<void> _pilihHari() async {
    final pilih = await showDatePicker(
      context: context,
      initialDate: _hari,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pilih == null) return;
    setState(() => _hari = DateTime(pilih.year, pilih.month, pilih.day));
    await _muatData(layarPenuh: true);
  }

  Future<void> _unggahMutasi() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return;
    final f = pick.files.single;
    final nama = f.name;
    if (nama.toLowerCase().endsWith('.xlsx') ||
        nama.toLowerCase().endsWith('.xls')) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message:
            'Ekspor mutasi ke CSV dulu. Workbook harian SETORAN tidak diunggah.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    final bytes = f.bytes;
    if (bytes == null) {
      if (!mounted) return;
      showAppSnackBar(context, message: 'Berkas tidak bisa dibaca.');
      return;
    }
    String teks;
    try {
      teks = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, message: 'Berkas harus teks CSV.');
      return;
    }
    final hasil = MutasiCsv.parse(teks);
    if (hasil.error != null) {
      if (!mounted) return;
      showAppSnackBar(context, message: hasil.error!);
      return;
    }
    setState(() => _proses = true);
    if (!await _adaNet()) {
      if (mounted) setState(() => _proses = false);
      return;
    }
    try {
      final n = await _sb.rpc(
        'admin_mutasi_unggah',
        params: {
          'p_tanggal': _iso,
          'p_nama_berkas': nama,
          'p_baris': hasil.baris.map((b) => b.toRpc()).toList(),
        },
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Mutasi: ${n ?? 0} baris kredit disimpan.',
        warna: AppSnackBarTone.hijau,
      );
      await _muatMutasiSaja();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, message: 'Gagal mengunggah mutasi.');
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _hapusMutasi() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: const Text('Hapus mutasi'),
        content: Text('Buang semua mutasi $_judulHari?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      await _sb.rpc('admin_mutasi_hapus', params: {'p_tanggal': _iso});
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Mutasi tanggal ini dihapus.',
        warna: AppSnackBarTone.hijau,
      );
      _pasangMutasi([]);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, message: 'Gagal menghapus mutasi.');
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _setRuteMutasi(int id, String? rute) async {
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      await _sb.rpc(
        'admin_mutasi_set_rute',
        params: {'p_id': id, 'p_rute': rute ?? ''},
      );
      await _muatMutasiSaja();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, message: 'Gagal mengubah rute mutasi.');
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _simpanTunai(String rute, int tunai, List<int> pecahan) async {
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      final ok = await _sb.rpc(
        'admin_setoran_simpan_tunai',
        params: {
          'p_tanggal': _iso,
          'p_rute': rute,
          'p_tunai': tunai,
          'p_pecahan': pecahan,
        },
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: ok == true
            ? 'Tunai $rute disimpan.'
            : 'Tunai gagal disimpan.',
        warna: ok == true ? AppSnackBarTone.hijau : AppSnackBarTone.kuning,
      );
      if (ok == true) {
        _timpaBarisTruk(rute, {
          'tunai_admin': tunai,
          'pecahan_tunai': pecahan,
        });
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, message: 'Gagal menyimpan tunai admin.');
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _dialogTunai(Map<String, dynamic> row) async {
    final rute = row['rute_pengirim']?.toString() ?? '';
    final pecahan = _pecahanTunai;
    final qtyLama = _qtyPecahan(row);
    final pecahanCtrl = List.generate(
      pecahan.length,
      (i) => TextEditingController(
        text: qtyLama[i] == 0 ? '' : formatUang(qtyLama[i]),
      ),
    );
    var totalPecahan = 0;
    for (var i = 0; i < pecahan.length; i++) {
      totalPecahan += pecahan[i].nilai * qtyLama[i];
    }
    final pecahanKosong =
        _angka(row['tunai_admin']) > 0 && qtyLama.every((n) => n == 0);

    if (!mounted) {
      for (final c in pecahanCtrl) {
        c.dispose();
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            void hitungPecahan() {
              var n = 0;
              pecahan.asMap().forEach((i, p) {
                n += p.nilai * angkaTeks(pecahanCtrl[i].text);
              });
              totalPecahan = n;
              setLocal(() {});
            }

            const gaya = TextStyle(fontSize: 12, height: 1.2);
            const lebarKolom = {
              0: FixedColumnWidth(64),
              1: FixedColumnWidth(18),
              2: FixedColumnWidth(52),
              3: FixedColumnWidth(58),
              4: FixedColumnWidth(18),
              5: FixedColumnWidth(80),
            };
            const garis = BorderSide(color: AppTheme.seed, width: 1);
            final sudut = BorderRadius.circular(8);
            final dekorQty = InputDecoration(
              isDense: true,
              hintText: '0',
              hintStyle: gaya.copyWith(color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: sudut,
                borderSide: garis,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: sudut,
                borderSide: garis,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: sudut,
                borderSide: garis,
              ),
            );

            Widget teks(String s, {TextAlign align = TextAlign.left}) {
              return Text(s, style: gaya, textAlign: align);
            }

            return AppDialog(
              title: Text('Tunai $rute'),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                      Table(
                        columnWidths: lebarKolom,
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: List.generate(pecahan.length, (i) {
                          final p = pecahan[i];
                          final hasil =
                              p.nilai * angkaTeks(pecahanCtrl[i].text);
                          return TableRow(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: TextField(
                                  controller: pecahanCtrl[i],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: gaya,
                                  inputFormatters: const [
                                    FormatRibuan(kosong: ''),
                                  ],
                                  onChanged: (_) => hitungPecahan(),
                                  decoration: dekorQty,
                                ),
                              ),
                              teks('×', align: TextAlign.center),
                              teks(p.jenis),
                              teks(p.label, align: TextAlign.right),
                              teks('=', align: TextAlign.center),
                              _uangSel(hasil),
                            ],
                          );
                        }),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, thickness: 0.6),
                      ),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tunai admin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 18,
                            child: teks('=', align: TextAlign.center),
                          ),
                          SizedBox(
                            width: 80,
                            child: _uangSel(totalPecahan, tebal: true),
                          ),
                        ],
                      ),
                      if (pecahanKosong)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Total tersimpan Rp ${formatUang(_angka(row['tunai_admin']))}. '
                            'Rincian pecahan belum ada; isi lalu simpan.',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.2,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(72, 36),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _simpanTunai(
                      rute,
                      totalPecahan,
                      List.generate(
                        pecahan.length,
                        (i) => angkaTeks(pecahanCtrl[i].text),
                      ),
                    );
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
    for (final c in pecahanCtrl) {
      c.dispose();
    }
  }

  Future<void> _dialogNota(Map<String, dynamic> row, {required bool pending}) async {
    if (!await _adaNet()) return;
    final rute = row['rute_pengirim']?.toString() ?? '';
    List<Map<String, dynamic>> nota = [];
    try {
      final raw = await _sb.rpc(
        'admin_setoran_nota',
        params: {'p_tanggal': _iso, 'p_rute': rute},
      );
      if (raw is List) {
        nota = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, message: 'Gagal memuat nota $rute.');
      return;
    }
    if (pending) {
      nota = nota.where((n) => n['pending'] == true).toList();
    } else {
      nota = nota
          .where(
            (n) =>
                n['status']?.toString() == 'batal' || _angka(n['batal']) > 0,
          )
          .toList();
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AppDialog(
          title: Text(pending ? 'Nota pending $rute' : 'Nota batal $rute'),
          content: nota.isEmpty
              ? Text(
                  pending
                      ? 'Tidak ada nota pending untuk tanggal ini.'
                      : 'Tidak ada nota batal untuk tanggal ini.',
                )
              : DataTable(
                  border: _garisKolom,
                  columnSpacing: 12,
                  horizontalMargin: 8,
                  headingRowHeight: 36,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 44,
                  columns: pending
                      ? const [
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            label: Text('Pelanggan'),
                          ),
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            label: Text('Nota'),
                          ),
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            numeric: true,
                            label: Text('Packed'),
                          ),
                        ]
                      : const [
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            label: Text('Pelanggan'),
                          ),
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            label: Text('Nota'),
                          ),
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            label: Text('Status'),
                          ),
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            numeric: true,
                            label: Text('Packed'),
                          ),
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            numeric: true,
                            label: Text('Actual'),
                          ),
                          DataColumn(
                            headingRowAlignment: MainAxisAlignment.center,
                            numeric: true,
                            label: Text('Batal'),
                          ),
                        ],
                  rows: nota.map((n) {
                    final selPending = n['pending'] == true;
                    final selNota = DataCell(
                      Tooltip(
                        message: 'Rincian barang',
                        child: Text(
                          '${n['id_nota'] ?? ''}',
                          style: const TextStyle(
                            color: AppTheme.seed,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      onTap: () => pending
                          ? _dialogRincianPending(n)
                          : _dialogRincianBatal(n),
                    );
                    return DataRow(
                      cells: pending
                          ? [
                              DataCell(
                                Text('${n['nama_pelanggan'] ?? '-'}'),
                              ),
                              selNota,
                              DataCell(Text(formatUang(n['packed']))),
                            ]
                          : [
                              DataCell(
                                Text('${n['nama_pelanggan'] ?? '-'}'),
                              ),
                              selNota,
                              DataCell(
                                Text(
                                  selPending
                                      ? 'pending'
                                      : '${n['status'] ?? ''}',
                                ),
                              ),
                              DataCell(Text(formatUang(n['packed']))),
                              DataCell(Text(formatUang(n['actual']))),
                              DataCell(Text(formatUang(n['batal']))),
                            ],
                    );
                  }).toList(),
                ),
          actions: [
            TextButton.icon(
              onPressed: nota.isEmpty
                  ? null
                  : () => pending
                      ? _dialogSemuaItemPending(rute)
                      : _dialogSemuaItemBatal(rute),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text(
                pending ? 'Semua item pending' : 'Semua item batal',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _dialogRetur(Map<String, dynamic> row) async {
    if (!await _adaNet()) return;
    final rute = row['rute_pengirim']?.toString() ?? '';
    var nominal = _angka(row['retur']);
    var pesan = (row['catatan_retur']?.toString() ?? '').trim();
    try {
      final raw = await _sb.rpc(
        'admin_retur_lihat',
        params: {'p_tanggal': _iso},
      );
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          if (m['rute_pengirim']?.toString() != rute) continue;
          nominal = _angka(m['jumlah_usul']);
          pesan = (m['catatan_usul']?.toString() ?? '').trim();
          break;
        }
      }
    } catch (_) {}

    final baris = <_BarisCocokRetur>[];
    try {
      final raw = await _sb.rpc(
        'admin_retur_item_lihat',
        params: {'p_tanggal': _iso, 'p_rute': rute},
      );
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          baris.add(
            _BarisCocokRetur(
              kode: m['kode_barang']?.toString() ?? '',
              nama: m['nama_barang']?.toString() ?? '',
              qty: _angka(m['qty']),
            ),
          );
        }
      }
    } catch (_) {}

    if (!mounted) {
      for (final b in baris) {
        b.dispose();
      }
      return;
    }

    final cariCtrl = TextEditingController();
    var saran = <({String kode, String nama})>[];
    Timer? tunda;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            int totalQty() => baris.fold<int>(0, (a, b) => a + b.qty);

            void tambahBarang(String kode, String nama) {
              final kodeN = kode.trim();
              if (kodeN.isEmpty) return;
              for (final b in baris) {
                if (b.kode == kodeN) {
                  cariCtrl.clear();
                  saran = [];
                  setLocal(() {});
                  return;
                }
              }
              baris.add(
                _BarisCocokRetur(kode: kodeN, nama: nama.trim(), qty: 0),
              );
              cariCtrl.clear();
              saran = [];
              setLocal(() {});
            }

            void cariBarang(String q) {
              tunda?.cancel();
              final teks = q.trim();
              if (teks.length < 2) {
                setLocal(() => saran = []);
                return;
              }
              tunda = Timer(const Duration(milliseconds: 280), () async {
                try {
                  final raw = await _sb.rpc(
                    'admin_barang_cari',
                    params: {'p_cari': teks},
                  );
                  final next = <({String kode, String nama})>[];
                  if (raw is List) {
                    for (final e in raw) {
                      if (e is! Map) continue;
                      final m = Map<String, dynamic>.from(e);
                      next.add((
                        kode: m['kode_barang']?.toString() ?? '',
                        nama: m['nama_barang']?.toString() ?? '',
                      ));
                    }
                  }
                  if (!ctx.mounted) return;
                  setLocal(() => saran = next);
                } catch (_) {
                  if (!ctx.mounted) return;
                  setLocal(() => saran = []);
                }
              });
            }

            Future<void> simpan() async {
              if (!await _adaNet()) return;
              try {
                final ok = await _sb.rpc(
                  'admin_retur_item_simpan',
                  params: {
                    'p_tanggal': _iso,
                    'p_rute': rute,
                    'p_baris': baris
                        .where((b) => b.kode.isNotEmpty && b.qty > 0)
                        .map(
                          (b) => {
                            'kode_barang': b.kode,
                            'nama_barang': b.nama,
                            'qty': b.qty,
                          },
                        )
                        .toList(),
                  },
                );
                if (!mounted) return;
                if (ok == true) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  showAppSnackBar(
                    this.context,
                    message: 'Barang retur $rute disimpan.',
                    warna: AppSnackBarTone.hijau,
                  );
                } else {
                  showAppSnackBar(
                    this.context,
                    message: 'Gagal simpan. Arsip hari mungkin sudah dikunci.',
                    warna: AppSnackBarTone.kuning,
                  );
                }
              } catch (_) {
                if (!mounted) return;
                showAppSnackBar(
                  this.context,
                  message:
                      'Gagal simpan. Jalankan ulang arsip_harian.sql di Supabase.',
                );
              }
            }

            return AppDialog(
              title: Text('Retur $rute'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _barisNilai('Qty cocok', totalQty()),
                    _barisNilai('Nominal', nominal),
                    const SizedBox(height: 8),
                    const Text(
                      'Pesan pengirim',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pesan.isEmpty ? 'Tidak ada pesan retur.' : pesan,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: pesan.isEmpty ? Colors.grey.shade600 : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cocokkan barang',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: cariCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Cari nama atau kode barang',
                        hintStyle: TextStyle(fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 18),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      onChanged: cariBarang,
                    ),
                    if (saran.isNotEmpty)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final s in saran)
                            ListTile(
                              dense: true,
                              title: Text(s.nama),
                              subtitle: Text(s.kode),
                              onTap: () => tambahBarang(s.kode, s.nama),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    if (baris.isEmpty)
                      Text(
                        'Pilih barang dari hasil cari, lalu isi qty.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      ...baris.asMap().entries.map((e) {
                        final i = e.key;
                        final b = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  b.nama.isEmpty ? b.kode : b.nama,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 64,
                                child: TextField(
                                  controller: b.qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                  inputFormatters: const [FormatRibuan()],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Qty',
                                    hintStyle: TextStyle(fontSize: 11),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                  ),
                                  onChanged: (_) => setLocal(() {}),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                iconSize: 18,
                                onPressed: () {
                                  b.dispose();
                                  baris.removeAt(i);
                                  setLocal(() {});
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
                FilledButton(
                  onPressed: simpan,
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
    tunda?.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    cariCtrl.dispose();
    for (final b in baris) {
      b.dispose();
    }
  }

  String _labelBarang(Map<String, dynamic> it) {
    final nama = (it['nama_barang']?.toString() ?? '').trim();
    final kode = it['kode_barang']?.toString() ?? '';
    if (nama.isNotEmpty) return nama;
    if (kode.isNotEmpty) return kode;
    return 'Barang';
  }

  Future<void> _dialogTabelBarang({
    required String judul,
    required List<Widget> atas,
    required List<Map<String, dynamic>> items,
    required String kolomNilai,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AppDialog(
          title: Text(judul),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...atas,
              if (atas.isNotEmpty) const SizedBox(height: 8),
              DataTable(
                border: _garisKolom,
                columnSpacing: 12,
                horizontalMargin: 8,
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 44,
                columns: [
                  const DataColumn(
                    headingRowAlignment: MainAxisAlignment.center,
                    label: Text('Barang'),
                  ),
                  const DataColumn(
                    headingRowAlignment: MainAxisAlignment.center,
                    numeric: true,
                    label: Text('Qty'),
                  ),
                  DataColumn(
                    headingRowAlignment: MainAxisAlignment.center,
                    numeric: true,
                    label: Text(kolomNilai),
                  ),
                ],
                rows: items
                    .map(
                      (it) => DataRow(
                        cells: [
                          DataCell(Text(_labelBarang(it))),
                          DataCell(Text('${_angka(it['qty'])}')),
                          DataCell(Text(formatUang(it['packed']))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _dialogSemuaItemPending(String rute) async {
    if (!await _adaNet()) return;
    List<Map<String, dynamic>> items = [];
    try {
      final raw = await _sb.rpc(
        'admin_setoran_nota_item_pending',
        params: {'p_tanggal': _iso, 'p_rute': rute},
      );
      if (raw is List) {
        items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message:
            'Gagal memuat item pending. Jalankan ulang admin_setoran.sql di Supabase, lalu coba lagi.',
      );
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Tidak ada item pending untuk tanggal ini.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    final totalQty = items.fold<int>(0, (a, it) => a + _angka(it['qty']));
    final totalPacked = items.fold<int>(
      0,
      (a, it) => a + _angka(it['packed']),
    );
    await _dialogTabelBarang(
      judul: 'Semua item pending $rute',
      atas: [
        Text('Qty $totalQty · Packed Rp ${formatUang(totalPacked)}'),
      ],
      items: items,
      kolomNilai: 'Packed',
    );
  }

  Future<void> _dialogSemuaItemBatal(String rute) async {
    if (!await _adaNet()) return;
    List<Map<String, dynamic>> items = [];
    try {
      final raw = await _sb.rpc(
        'admin_setoran_nota_item_batal_hari',
        params: {'p_tanggal': _iso, 'p_rute': rute},
      );
      if (raw is List) {
        items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message:
            'Gagal memuat item batal. Jalankan ulang admin_setoran.sql di Supabase, lalu coba lagi.',
      );
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Tidak ada item batal untuk tanggal ini.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    final totalQty = items.fold<int>(0, (a, it) => a + _angka(it['qty']));
    final totalNilai = items.fold<int>(
      0,
      (a, it) => a + _angka(it['packed']),
    );
    await _dialogTabelBarang(
      judul: 'Semua item batal $rute',
      atas: [
        Text('Qty $totalQty · Batal Rp ${formatUang(totalNilai)}'),
      ],
      items: items,
      kolomNilai: 'Batal',
    );
  }

  Future<void> _dialogRincianPending(Map<String, dynamic> nota) async {
    final id = nota['id_nota']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _adaNet()) return;
    List<Map<String, dynamic>> items = [];
    try {
      final raw = await _sb.rpc(
        'admin_setoran_nota_item',
        params: {'p_id_nota': id},
      );
      if (raw is List) {
        items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message:
            'Gagal memuat rincian. Jalankan ulang admin_setoran.sql di Supabase, lalu coba lagi.',
      );
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Rincian barang pending belum bisa ditampilkan.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    await _dialogTabelBarang(
      judul: 'Rincian $id',
      atas: [
        Text(
          '${nota['nama_pelanggan'] ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text('Packed Rp ${formatUang(nota['packed'])}'),
      ],
      items: items,
      kolomNilai: 'Packed',
    );
  }

  Future<void> _dialogRincianBatal(Map<String, dynamic> nota) async {
    final id = nota['id_nota']?.toString() ?? '';
    if (id.isEmpty) return;
    if (!await _adaNet()) return;
    List<Map<String, dynamic>> items = [];
    try {
      final raw = await _sb.rpc(
        'admin_setoran_nota_item_batal',
        params: {'p_id_nota': id},
      );
      if (raw is List) {
        items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message:
            'Gagal memuat rincian. Jalankan ulang admin_setoran.sql di Supabase, lalu coba lagi.',
      );
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Rincian barang batal belum bisa ditampilkan.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    await _dialogTabelBarang(
      judul: 'Rincian $id',
      atas: [
        Text(
          '${nota['nama_pelanggan'] ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text('Batal Rp ${formatUang(nota['batal'])}'),
      ],
      items: items,
      kolomNilai: 'Batal',
    );
  }

  bool get _hariAbsen =>
      _hari.weekday >= DateTime.monday && _hari.weekday <= DateTime.saturday;

  List<Map<String, dynamic>> _timpaHadir(
    List<Map<String, dynamic>> daftar,
    String kunci,
    bool hadir,
  ) {
    return [
      for (final row in daftar)
        if (row['nama_kunci']?.toString() == kunci)
          {...row, 'hadir': hadir}
        else
          row,
    ];
  }

  Future<void> _ubahHadir(String peran, String kunci, bool hadir) async {
    if (kunci.isEmpty) return;
    if (!await _adaNet()) return;
    setState(() {
      if (peran == 'pengirim') {
        _pengirim = _timpaHadir(_pengirim, kunci, hadir);
      } else {
        _gudang = _timpaHadir(_gudang, kunci, hadir);
      }
    });
    try {
      final ok = await _sb.rpc(
        'gaji_set_absensi',
        params: {
          'p_tanggal': _iso,
          'p_nama_kunci': kunci,
          'p_hadir': hadir,
        },
      );
      if (ok != true && mounted) {
        setState(() {
          if (peran == 'pengirim') {
            _pengirim = _timpaHadir(_pengirim, kunci, !hadir);
          } else {
            _gudang = _timpaHadir(_gudang, kunci, !hadir);
          }
        });
        showAppSnackBar(
          context,
          message: 'Absensi gagal disimpan.',
          warna: AppSnackBarTone.kuning,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (peran == 'pengirim') {
          _pengirim = _timpaHadir(_pengirim, kunci, !hadir);
        } else {
          _gudang = _timpaHadir(_gudang, kunci, !hadir);
        }
      });
      showAppSnackBar(context, message: 'Gagal menyimpan absensi.');
    }
  }

  List<String> _bendera(Map<String, dynamic> row) {
    final out = <String>[];
    if (_angka(row['jumlah_dikirim']) > 0) {
      out.add('Masih ${_angka(row['jumlah_dikirim'])} nota dikirim');
    }
    if (row['bop_lebih'] == true) out.add('BOP > 170.000');
    if (row['sesa_tidak_nol'] == true) out.add('Setoran pengirim tidak seimbang');
    if (row['tunai_beda'] == true) out.add('Tunai admin ≠ pengirim');
    if (row['transfer_beda'] == true) out.add('Mutasi ≠ transfer');
    if (row['snapshot_beda'] == true) out.add('Actual/kiriman beda kunci');
    if (row['sudah_setor'] == true && _angka(row['sesa_cek']) != 0) {
      out.add('Cek ≠ 0 — laporan salah');
    }
    return out;
  }

  Color _warnaSesa(int n) {
    if (n == 0) return Colors.green.shade700;
    return Colors.red;
  }

  Widget _uangSel(dynamic n, {Color? warna, bool tebal = false}) {
    final gaya = TextStyle(
      fontSize: _teksIsi,
      height: 1.15,
      color: warna,
      fontWeight: tebal ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      children: [
        Text('Rp', style: gaya),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            formatUang(_angka(n)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: gaya,
          ),
        ),
      ],
    );
  }

  Widget _kotakKolom(
    double lebar,
    Widget child, {
    AlignmentGeometry alignment = Alignment.centerLeft,
  }) {
    return SizedBox(
      width: lebar,
      child: Align(alignment: alignment, child: child),
    );
  }

  Widget _judulKolom(double lebar, String teks) {
    return SizedBox(
      width: lebar,
      child: Text(
        teks,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: _teksIsi, fontWeight: FontWeight.w600),
      ),
    );
  }

  DataColumn _kolomJudul(double lebar, String teks) {
    return DataColumn(
      headingRowAlignment: MainAxisAlignment.center,
      label: _judulKolom(lebar, teks),
    );
  }

  List<DataColumn> get _judulSetoran => [
    _kolomJudul(_lebarRute, 'Rute'),
    _kolomJudul(_lebarNilai, 'Nota'),
    _kolomJudul(_lebarNilai, 'Setor'),
    _kolomJudul(_lebarNilai, 'Hitung'),
  ];

  Widget _barisNilai(
    String label,
    dynamic n, {
    Color? warna,
    bool tebal = false,
    String? teks,
    VoidCallback? onLabel,
  }) {
    final gayaLabel = TextStyle(
      fontSize: _teksIsi,
      height: 1.15,
      color: Colors.grey.shade700,
    );
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: onLabel == null
              ? Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gayaLabel,
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _proses ? null : onLabel,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppTheme.seed,
                      textStyle: const TextStyle(
                        fontSize: _teksIsi,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(label),
                  ),
                ),
        ),
        Expanded(
          child: teks != null
              ? Text(
                  teks,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: _teksIsi,
                    height: 1.15,
                    color: warna,
                    fontWeight: tebal ? FontWeight.bold : FontWeight.normal,
                  ),
                )
              : _uangSel(n, warna: warna, tebal: tebal),
        ),
      ],
    );
  }

  Widget _kolomNota(
    Map<String, dynamic> row, {
    VoidCallback? onPending,
    VoidCallback? onBatal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _barisNilai('Kiriman', row['kiriman']),
        _barisNilai(
          'Batal',
          row['batal'],
          warna: Colors.red,
          onLabel: onBatal,
        ),
        _barisNilai(
          'Pending',
          row['pending'],
          warna: Colors.orange.shade800,
          onLabel: onPending,
        ),
        _barisNilai('Actual', row['actual'], tebal: true),
      ],
    );
  }

  Widget _kolomSetor(Map<String, dynamic> row, {VoidCallback? onTunaiAdmin}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _barisNilai('Transfer', row['transfer']),
        _barisNilai('Mutasi', row['transfer_mutasi']),
        _barisNilai('Tunai', row['tunai']),
        _barisNilai(
          'Tunai admin',
          row['tunai_admin'],
          onLabel: onTunaiAdmin,
        ),
      ],
    );
  }

  Widget _kolomHitung(
    Map<String, dynamic> row,
    int kasbon, {
    VoidCallback? onRetur,
  }) {
    final sudah = row['sudah_setor'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _barisNilai(
          'BOP',
          row['bop'],
          warna: row['bop_lebih'] == true ? Colors.red : null,
        ),
        _barisNilai('Kasbon', kasbon, warna: Colors.red),
        _barisNilai('Retur', row['retur'], onLabel: onRetur),
        sudah
            ? _barisNilai(
                'Cek',
                row['sesa_cek'],
                warna: _warnaSesa(_angka(row['sesa_cek'])),
                tebal: true,
              )
            : _barisNilai('Cek', 0, teks: '—'),
      ],
    );
  }

  Map<String, dynamic> _jumlahEmpatTim() {
    var kiriman = 0;
    var batal = 0;
    var pending = 0;
    var actual = 0;
    var transfer = 0;
    var mutasi = 0;
    var tunai = 0;
    var tunaiAdmin = 0;
    var bop = 0;
    var retur = 0;
    var kasbon = 0;
    var sesa = 0;
    var cek = 0;
    var adaSetor = false;
    var bopLebih = false;
    for (final row in _truk) {
      kiriman += _angka(row['kiriman']);
      batal += _angka(row['batal']);
      pending += _angka(row['pending']);
      actual += _angka(row['actual']);
      transfer += _angka(row['transfer']);
      mutasi += _angka(row['transfer_mutasi']);
      tunai += _angka(row['tunai']);
      tunaiAdmin += _angka(row['tunai_admin']);
      bop += _angka(row['bop']);
      retur += _angka(row['retur']);
      kasbon += _angka(row['kasbon_supir']) + _angka(row['kasbon_kenek']);
      sesa += _angka(row['sesa']);
      if (row['sudah_setor'] == true) {
        cek += _angka(row['sesa_cek']);
      }
      if (row['sudah_setor'] == true) adaSetor = true;
      if (row['bop_lebih'] == true) bopLebih = true;
    }
    return {
      'kiriman': kiriman,
      'batal': batal,
      'pending': pending,
      'actual': actual,
      'transfer': transfer,
      'transfer_mutasi': mutasi,
      'tunai': tunai,
      'tunai_admin': tunaiAdmin,
      'bop': bop,
      'retur': retur,
      'kasbon': kasbon,
      'sesa': sesa,
      'sesa_cek': cek,
      'sudah_setor': adaSetor,
      'bop_lebih': bopLebih,
    };
  }

  DataRow _barisJumlahSetoran() {
    final jumlah = _jumlahEmpatTim();
    final kasbon = _angka(jumlah['kasbon']);
    return DataRow(
      cells: [
        DataCell(
          _kotakKolom(
            _lebarRute,
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Jumlah',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: _teksIsi,
                    height: 1.15,
                  ),
                ),
                Text(
                  '4 tim  SBGP01–04',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: _teksIsi, height: 1.15),
                ),
                ],
              ),
            ),
        ),
        DataCell(_kotakKolom(_lebarNilai, _kolomNota(jumlah))),
        DataCell(_kotakKolom(_lebarNilai, _kolomSetor(jumlah))),
        DataCell(_kotakKolom(_lebarNilai, _kolomHitung(jumlah, kasbon))),
      ],
    );
  }

  List<DataRow> _barisTrukSetoran() {
    return [
      ..._truk.map((row) {
        final rute = row['rute_pengirim']?.toString() ?? '';
        final bendera = _bendera(row);
        final kasbon =
            _angka(row['kasbon_supir']) + _angka(row['kasbon_kenek']);
        return DataRow(
          cells: [
            DataCell(
              _kotakKolom(
                _lebarRute,
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        rute,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: _teksIsi,
                          height: 1.15,
                        ),
                      ),
                      Text(
                        row['sudah_setor'] == true
                            ? 'Sudah setor'
                            : 'Belum setor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _teksIsi,
                          height: 1.15,
                          color: row['sudah_setor'] == true
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                      if (bendera.isNotEmpty)
                        Text(
                          bendera.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: _teksIsi,
                            height: 1.15,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
              ),
            ),
            DataCell(
              _kotakKolom(
                _lebarNilai,
                _kolomNota(
                  row,
                  onPending: () => _dialogNota(row, pending: true),
                  onBatal: () => _dialogNota(row, pending: false),
                ),
              ),
            ),
            DataCell(
              _kotakKolom(
                _lebarNilai,
                _kolomSetor(
                  row,
                  onTunaiAdmin: () => _dialogTunai(row),
                ),
              ),
            ),
            DataCell(
              _kotakKolom(
                _lebarNilai,
                _kolomHitung(
                  row,
                  kasbon,
                  onRetur: () => _dialogRetur(row),
                ),
              ),
            ),
          ],
        );
      }),
      _barisJumlahSetoran(),
    ];
  }

  Widget _tabelMutasi({double tinggiBaris = 36}) {
    const gaya = TextStyle(fontSize: _teksIsi, height: 1.15);
    return DataTable(
      headingRowHeight: 32,
      dataRowMinHeight: tinggiBaris,
      dataRowMaxHeight: tinggiBaris,
      columnSpacing: 12,
      horizontalMargin: 8,
      border: _garisKolom,
      columns: const [
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          label: Text(
            'Tanggal',
            style: TextStyle(fontSize: _teksIsi, fontWeight: FontWeight.w600),
          ),
        ),
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          label: Text(
            'Jumlah',
            style: TextStyle(fontSize: _teksIsi, fontWeight: FontWeight.w600),
          ),
        ),
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          label: Text(
            'Berita',
            style: TextStyle(fontSize: _teksIsi, fontWeight: FontWeight.w600),
          ),
        ),
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          label: Text(
            'Rekening',
            style: TextStyle(fontSize: _teksIsi, fontWeight: FontWeight.w600),
          ),
        ),
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          label: Text(
            'Rute',
            style: TextStyle(fontSize: _teksIsi, fontWeight: FontWeight.w600),
          ),
        ),
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          label: Text(
            'Status',
            style: TextStyle(fontSize: _teksIsi, fontWeight: FontWeight.w600),
          ),
        ),
        DataColumn(
          headingRowAlignment: MainAxisAlignment.center,
          label: Text(
            'Berkas',
            style: TextStyle(fontSize: _teksIsi, fontWeight: FontWeight.w600),
          ),
        ),
      ],
      rows: _mutasi.map((m) {
        final id = _angka(m['id']);
        final rute = m['rute_pengirim']?.toString();
        final status = m['status_cocok']?.toString() ?? '';
        return DataRow(
          cells: [
            DataCell(Text('${m['tanggal_mutasi'] ?? '-'}', style: gaya)),
            DataCell(_uangSel(m['jumlah'], tebal: true)),
            DataCell(
              SizedBox(
                width: 260,
                child: Text(
                  '${m['berita'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: gaya,
                ),
              ),
            ),
            DataCell(Text('${m['rekening_alias'] ?? '-'}', style: gaya)),
            DataCell(
              DropdownButton<String>(
                value: _rute.contains(rute) ? rute : '',
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: '', child: Text('-')),
                  ..._rute.map(
                    (r) => DropdownMenuItem(value: r, child: Text(r)),
                  ),
                ],
                onChanged: _proses
                    ? null
                    : (v) => _setRuteMutasi(
                        id,
                        (v == null || v.isEmpty) ? null : v,
                      ),
              ),
            ),
            DataCell(
              Text(
                status,
                style: TextStyle(
                  fontSize: _teksIsi,
                  fontWeight: FontWeight.bold,
                  color: switch (status) {
                    'cocok' => Colors.green.shade700,
                    'manual' => const Color(0xFF1B75CB),
                    _ => Colors.red,
                  },
                ),
              ),
            ),
            DataCell(Text('${m['nama_berkas'] ?? ''}', style: gaya)),
          ],
        );
      }).toList(),
    );
  }

  Widget _kartuTabel(Widget tabel) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: tabel,
      ),
    );
  }

  Widget _kartuAbsensi({
    required String judul,
    required String peran,
    required List<Map<String, dynamic>> orang,
  }) {
    if (orang.isEmpty) return const SizedBox.shrink();
    final kunciGaji = _truk.any((r) => r['gaji_kunci'] == true);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              judul,
              style: const TextStyle(
                fontSize: _teksIsi,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
            const SizedBox(width: 12),
            ...orang.map((row) {
              final kunci = row['nama_kunci']?.toString() ?? '';
              final nama = row['nama']?.toString() ?? kunci;
              final hadir = row['hadir'] == true;
              final boleh =
                  _hariAbsen && !kunciGaji && !_proses && kunci.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Checkbox(
                          value: hadir,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: boleh
                              ? (v) => _ubahHadir(peran, kunci, v ?? false)
                              : null,
                        ),
                      ),
                    ),
                    Text(
                      nama,
                      style: const TextStyle(
                        fontSize: _teksIsi,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _dialogItemMasukSupplier({
    required String nama,
    required List<Map<String, dynamic>> items,
  }) {
    final total = items.fold<int>(0, (a, m) => a + _angka(m['nilai']));
    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text(nama),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (m['nama_barang']?.toString() ?? '')
                                      .trim()
                                      .isEmpty
                                  ? (m['kode_barang']?.toString() ?? '')
                                  : m['nama_barang'].toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              m['kode_barang']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatUang(m['qty']),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: Text(
                          formatUang(m['nilai']),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _barisNilai('Total', total, tebal: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _kartuBarangMasukHari() {
    if (_masuk.isEmpty) return const SizedBox.shrink();
    final urutan = <int>[];
    final namaSup = <int, String>{};
    final grup = <int, List<Map<String, dynamic>>>{};
    for (final m in _masuk) {
      final id = _idDariRpc(m['id_supplier']);
      if (!grup.containsKey(id)) {
        urutan.add(id);
        grup[id] = [];
      }
      grup[id]!.add(m);
      final n = (m['nama_supplier']?.toString() ?? '').trim();
      if (n.isNotEmpty) namaSup[id] = n;
    }
    final total = _masuk.fold<int>(0, (a, m) => a + _angka(m['nilai']));
    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Barang masuk',
                style: TextStyle(
                  fontSize: _teksIsi,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final id in urutan) ...[
                InkWell(
                  onTap: () => _dialogItemMasukSupplier(
                    nama: namaSup[id] ?? 'Supplier',
                    items: grup[id]!,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            namaSup[id] ?? 'Supplier',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.seed,
                            ),
                          ),
                        ),
                        Text(
                          formatUang(
                            grup[id]!.fold<int>(
                              0,
                              (a, m) => a + _angka(m['nilai']),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(
                        fontSize: _teksIsi,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    formatUang(total),
                    style: const TextStyle(
                      fontSize: _teksIsi,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              tooltip: 'Pilih tanggal',
              onPressed: _pilihHari,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            Expanded(
              child: Text(
                'Setoran  $_judulHari',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            onPressed: () => _muatData(layarPenuh: true),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: widget.auth.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Align(
                    alignment: Alignment.topLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_truk.isEmpty)
                            Text(
                              'Belum ada data. Pastikan admin_setoran.sql sudah dijalankan.',
                              style: TextStyle(color: Colors.grey.shade600),
                            )
                          else
                            _kartuTabel(
                              DataTable(
                                headingRowHeight: 32,
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 68,
                                columnSpacing: 16,
                                horizontalMargin: 10,
                                border: _garisKolom,
                                columns: _judulSetoran,
                                rows: _barisTrukSetoran(),
                              ),
                            ),
                          if (_pengirim.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _kartuAbsensi(
                              judul: 'Pengirim',
                              peran: 'pengirim',
                              orang: _pengirim,
                            ),
                          ],
                          if (_gudang.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _kartuAbsensi(
                              judul: 'Gudang',
                              peran: 'gudang',
                              orang: _gudang,
                            ),
                          ],
                          if (_mutasi.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _kartuTabel(_tabelMutasi()),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                onPressed: _proses ? null : _unggahMutasi,
                                icon: const Icon(
                                  Icons.upload_file_outlined,
                                  size: 18,
                                ),
                                label: const Text('Unggah mutasi CSV'),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _proses || _mutasi.isEmpty
                                    ? null
                                    : _hapusMutasi,
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Hapus mutasi tanggal ini'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _proses ? null : _cekOpname,
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Cek opname'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _proses ? null : _dialogBarangMasuk,
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Barang masuk'),
                              ),
                            ],
                          ),
                        ],
                          ),
                          if (_masuk.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            _kartuBarangMasukHari(),
                          ],
                        ],
                      ),
                    ),
                  ),
            ),
    );
  }
}

class _BarisCocokRetur {
  _BarisCocokRetur({
    required this.kode,
    required this.nama,
    int qty = 0,
  }) : qtyCtrl = TextEditingController(
         text: qty == 0 ? '' : formatUang(qty),
       );

  final String kode;
  final String nama;
  final TextEditingController qtyCtrl;

  int get qty => angkaTeks(qtyCtrl.text);

  void dispose() => qtyCtrl.dispose();
}

class _BarisMasuk {
  _BarisMasuk({
    required this.kode,
    required this.nama,
    this.qtySudah = 0,
    this.nilaiSudah = 0,
    int hargaAwal = 0,
    int qtyTambah = 0,
  }) : qtyCtrl = TextEditingController(
         text: qtyTambah == 0 ? '' : formatUang(qtyTambah),
       ),
       hargaCtrl = TextEditingController(
         text: hargaAwal == 0 ? '' : formatUang(hargaAwal),
       );

  final String kode;
  final String nama;
  final int qtySudah;
  final int nilaiSudah;
  final TextEditingController qtyCtrl;
  final TextEditingController hargaCtrl;

  int get qty => angkaTeks(qtyCtrl.text);
  int get harga => angkaTeks(hargaCtrl.text);
  int get nilai => qty > 0 && harga > 0 ? qty * harga : 0;

  void dispose() {
    qtyCtrl.dispose();
    hargaCtrl.dispose();
  }
}
