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
  final VoidCallback bukaMenu;
  const SetoranScreen({super.key, required this.auth, required this.bukaMenu});

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
  static const _lebarRute = 108.0;
  static const _lebarNilai = 248.0;
  static const _lebarLabelNilai = 118.0;
  static const _tinggiBarisNilai = 26.0;
  static const _tinggiJudulSetoran = 32.0;
  static const _tinggiBarisSetoranMaks = 200.0;
  static const _padKartuTabelAtas = 4.0;
  static const _padKartuTabelBawah = 8.0;
  static const _celahKartu = 6.0;
  static const _celahSampingKartu = 12.0;
  static const _tinggiBarisSupplier = 28.0;
  static const _barisSupplierTampil = 5;
  static const _tinggiTotalMasuk = 22.0;
  static const _tinggiBarisAbsensi = 28.0;
  static const _tinggiTombolAksi = 32.0;
  static const _padHalamanAtas = 6.0;
  static const _padHalamanBawah = 6.0;
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
  bool _opnameAda = false;
  String _opnameStatus = '';
  int _opnameSelisihSku = 0;
  int _opnameNilaiSelisih = 0;
  List<Map<String, dynamic>> _opnameBeda = [];
  bool _kotor = false;
  bool _mutasiGantiIsi = false;
  String _namaBerkasMutasi = '';
  int _idMutasiLokal = 0;
  final Map<int, String> _ruteMutasiAwal = {};
  final Map<String, bool> _hadirAwal = {};
  final Map<String, int> _drafTunai = {};
  final Map<String, List<int>> _drafPecahan = {};
  final List<({int idSupplier, List<Map<String, dynamic>> baris})> _drafMasuk =
      [];
  final Map<String, List<Map<String, dynamic>>> _drafRetur = {};
  final Map<String, bool> _drafPendingCek = {};
  final Map<String, String> _drafPendingRute = {};
  final Map<String, ({List<String> rute, bool cek})> _drafBatalCek = {};

  String get _iso => DateFormat('yyyy-MM-dd').format(_hari);

  String _teksHari(DateTime d) => DateFormat('EEEE d/MM/yyyy', 'id').format(d);

  String get _judulHari => _teksHari(_hari);

  String get _judulAppBar => 'Setoran ${_teksHari(_hari)}';

  double _tinggiKartuSetoran(int nBaris, double tinggiBaris) =>
      _padKartuTabelAtas +
      _tinggiJudulSetoran +
      nBaris * tinggiBaris +
      _padKartuTabelBawah;

  double get _tinggiKartuMasukPenuh =>
      8 +
      _tinggiTombolAksi +
      8 +
      _barisSupplierTampil * _tinggiBarisSupplier +
      6 +
      _tinggiTotalMasuk +
      10;

  ButtonStyle get _gayaTombolBiru => FilledButton.styleFrom(
    backgroundColor: AppTheme.seed,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFF8FB4D9),
    disabledForegroundColor: Colors.white,
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    minimumSize: const Size(0, _tinggiTombolAksi),
    padding: const EdgeInsets.symmetric(horizontal: 10),
  );

  Widget _tombolBiru({
    required String label,
    required VoidCallback? onPressed,
    IconData? ikon,
    double? ukuranFont,
  }) {
    final teks = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: ukuranFont == null
          ? null
          : TextStyle(fontSize: ukuranFont, fontWeight: FontWeight.bold),
    );
    return SizedBox(
      width: double.infinity,
      height: _tinggiTombolAksi,
      child: ikon == null
          ? FilledButton(
              onPressed: onPressed,
              style: _gayaTombolBiru,
              child: teks,
            )
          : FilledButton.icon(
              onPressed: onPressed,
              style: _gayaTombolBiru,
              icon: Icon(ikon, size: 18),
              label: teks,
            ),
    );
  }

  Widget _tombolSetengahKiri({
    required String label,
    required VoidCallback? onPressed,
    IconData? ikon,
    double? ukuranFont,
  }) {
    return Row(
      children: [
        Expanded(
          child: _tombolBiru(
            label: label,
            onPressed: onPressed,
            ikon: ikon,
            ukuranFont: ukuranFont,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }

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
    final i = _truk.indexWhere((r) => r['rute_pengirim']?.toString() == rute);
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
    final kasbon = _angka(row['kasbon_supir']) + _angka(row['kasbon_kenek']);
    final tunaiAdmin = _angka(row['tunai_admin']);
    final mutasi = _angka(row['transfer_mutasi']);
    row['actual'] =
        _angka(row['kiriman']) - _angka(row['batal']) - _angka(row['pending']);
    row['tunai_beda'] =
        row['sudah_setor'] == true &&
        tunaiAdmin > 0 &&
        tunaiAdmin != _angka(row['tunai']);
    row['transfer_beda'] =
        row['sudah_setor'] == true &&
        mutasi > 0 &&
        mutasi != _angka(row['transfer']);
    row['sesa_cek'] =
        _angka(row['actual']) -
        mutasi -
        tunaiAdmin -
        _angka(row['bop']) -
        _angka(row['retur']) -
        kasbon;
  }

  List<Map<String, dynamic>> _saringMutasiKredit(
    List<Map<String, dynamic>> mutasi,
  ) {
    return mutasi.where((m) {
      if (_angka(m['jumlah']) <= 0) return false;
      return !MutasiCsv.beritaDebet(m['berita']?.toString() ?? '');
    }).toList();
  }

  List<Map<String, dynamic>> _timpaTransferMutasi(
    List<Map<String, dynamic>> truk,
    List<Map<String, dynamic>> mutasi,
  ) {
    final jumlah = <String, int>{};
    for (final m in mutasi) {
      final st = m['status_cocok']?.toString() ?? '';
      if (st != 'cocok' && st != 'manual') continue;
      final rute = m['rute_pengirim']?.toString() ?? '';
      if (rute.isEmpty) continue;
      jumlah[rute] = (jumlah[rute] ?? 0) + _angka(m['jumlah']);
    }
    return truk.map((lama) {
      final row = Map<String, dynamic>.from(lama);
      final rute = row['rute_pengirim']?.toString() ?? '';
      row['transfer_mutasi'] = jumlah[rute] ?? 0;
      _selesaiHitung(row);
      return row;
    }).toList();
  }

  void _resetDraf() {
    _kotor = false;
    _mutasiGantiIsi = false;
    _namaBerkasMutasi = '';
    _idMutasiLokal = 0;
    _ruteMutasiAwal.clear();
    _hadirAwal.clear();
    _drafTunai.clear();
    _drafPecahan.clear();
    _drafMasuk.clear();
    _drafRetur.clear();
    _drafPendingCek.clear();
    _drafPendingRute.clear();
    _drafBatalCek.clear();
  }

  void _catatSnapshotAwal() {
    _ruteMutasiAwal
      ..clear()
      ..addAll({
        for (final m in _mutasi)
          _angka(m['id']): m['rute_pengirim']?.toString() ?? '',
      });
    _hadirAwal
      ..clear()
      ..addAll({
        for (final row in [..._pengirim, ..._gudang])
          if ((row['nama_kunci']?.toString() ?? '').isNotEmpty)
            row['nama_kunci'].toString(): row['hadir'] == true,
      });
  }

  void _tandaiKotor() {
    if (_kotor) return;
    setState(() => _kotor = true);
  }

  Future<bool> _izinBuangDraf() async {
    if (!_kotor) return true;
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: const Text('Buang perubahan?'),
        content: const Text(
          'Ada data setoran yang belum disimpan ke cloud. Lanjut dan buang?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    return ya == true;
  }

  String? _ruteDariBerita(String berita) {
    final m = RegExp(
      r'SBGP0([1-4])/(\d{2}-\d{2}-\d{4})',
      caseSensitive: false,
    ).firstMatch(berita);
    if (m == null) return null;
    try {
      final tgl = DateFormat('dd-MM-yyyy').parseStrict(m.group(2)!);
      if (DateFormat('yyyy-MM-dd').format(tgl) != _iso) return null;
    } catch (_) {
      return null;
    }
    return 'SBGP0${m.group(1)}';
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

  Future<void> _muatData({
    bool layarPenuh = false,
    bool buangDraf = false,
  }) async {
    if (!buangDraf && !await _izinBuangDraf()) return;
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
        gudang = isi.where((m) => m['peran']?.toString() == 'gudang').toList();
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
      var opnameAda = false;
      var opnameStatus = '';
      var opnameSku = 0;
      var opnameNilai = 0;
      var opnameBeda = <Map<String, dynamic>>[];
      try {
        final ringkas = await _ringkasOpname();
        opnameAda = ringkas.ada;
        opnameStatus = ringkas.status;
        opnameSku = ringkas.sku;
        opnameNilai = ringkas.nilai;
        opnameBeda = ringkas.beda;
      } catch (_) {}
      if (!mounted) return;
      final mutasiKredit = (mutasi is List)
          ? _saringMutasiKredit(
              mutasi.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            )
          : <Map<String, dynamic>>[];
      final trukList = (truk is List)
          ? truk.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _mutasi = mutasiKredit;
        _truk = _timpaTransferMutasi(trukList, mutasiKredit);
        _pengirim = pengirim;
        _gudang = gudang;
        _masuk = masuk;
        _opnameAda = opnameAda;
        _opnameStatus = opnameStatus;
        _opnameSelisihSku = opnameSku;
        _opnameNilaiSelisih = opnameNilai;
        _opnameBeda = opnameBeda;
        _muat = false;
        _resetDraf();
        _catatSnapshotAwal();
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
          _opnameAda = false;
          _opnameStatus = '';
          _opnameSelisihSku = 0;
          _opnameNilaiSelisih = 0;
          _opnameBeda = [];
          _muat = false;
        });
      }
      showAppSnackBar(
        context,
        message: 'Gagal memuat setoran. Jalankan admin_setoran.sql di Supabase, lalu coba lagi.',
      );
    }
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
        message: 'Gagal memuat barang masuk. Jalankan ulang arsip_harian.sql di Supabase.',
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
                  final hargaPakai = it.harga > ada.harga
                      ? it.harga
                      : ada.harga;
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

            Future<List<({String kode, String nama, int harga})>?>
            muatKatalog() async {
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
                  message: 'Gagal memuat katalog. Jalankan ulang arsip_harian.sql di Supabase.',
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
              final namaByKode = {for (final b in katalog) b.kode: b.nama};
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
              final salah = BarangMasukCsv.cekSkuBaru(hasil.baris, {
                for (final b in katalog) b.kode,
              });
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

            void simpan() {
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
              final namaSup = daftarSupplier
                  .where((s) => s.id == idSupplier)
                  .map((s) => s.nama)
                  .firstWhere((_) => true, orElse: () => 'Supplier');
              _drafMasuk.add((idSupplier: idSupplier, baris: kirim));
              setState(() {
                _kotor = true;
                _masuk = [
                  ..._masuk,
                  for (final b in kirim)
                    {
                      'id_supplier': idSupplier,
                      'nama_supplier': namaSup,
                      'kode_barang': b['kode_barang'],
                      'nama_barang': b['nama_barang'],
                      'qty': b['qty'],
                      'harga_beli': b['harga_beli'],
                      'nilai': _angka(b['qty']) * _angka(b['harga_beli']),
                    },
                ];
              });
              if (ctx.mounted) Navigator.pop(ctx);
            }

            const gaya = TextStyle(fontSize: 12, height: 1.2);
            const gayaTebal = TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.bold,
            );
            const garis = BorderSide(color: AppTheme.seed, width: 1);
            final sudut = BorderRadius.circular(8);
            InputDecoration dekor({
              String? hint,
              String? label,
              Widget? prefix,
            }) {
              return InputDecoration(
                isDense: true,
                hintText: hint,
                labelText: label,
                hintStyle: gaya.copyWith(color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                prefixIcon: prefix,
                prefixIconConstraints: prefix == null
                    ? null
                    : const BoxConstraints(minWidth: 36, minHeight: 36),
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
            }

            Widget tajuk(String judul, bool buka, VoidCallback onTap) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(judul, style: gayaTebal)),
                      Icon(
                        buka ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: AppTheme.seed,
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget tautan(IconData ikon, String label, VoidCallback onTap) {
              return TextButton.icon(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(ikon, size: 18),
                label: Text(label, style: gayaTebal.copyWith(color: AppTheme.seed)),
              );
            }

            Widget tombolTambah(VoidCallback onTap) {
              return FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Text('Tambah'),
              );
            }

            const lebarQty = 76.0;
            const lebarHarga = 100.0;
            const lebarHapus = 32.0;

            return AppDialog(
              title: const Text('Barang masuk'),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih supplier dulu. Harga beli disimpan per supplier. Qty × harga, lalu ditambah ke stok.',
                      style: gaya.copyWith(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      key: ValueKey(idSupplier),
                      initialValue: idSupplier > 0 ? idSupplier : null,
                      isDense: true,
                      style: gaya.copyWith(color: Colors.black),
                      decoration: dekor(label: 'Supplier'),
                      items: [
                        for (final s in daftarSupplier)
                          DropdownMenuItem(value: s.id, child: Text(s.nama)),
                      ],
                      onChanged: (v) {
                        if (v != null) pilihSupplier(v);
                      },
                    ),
                    tajuk(
                      'Supplier baru',
                      tampilSupplierBaru,
                      () => setLocal(
                        () => tampilSupplierBaru = !tampilSupplierBaru,
                      ),
                    ),
                    if (tampilSupplierBaru)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: namaSupplierCtrl,
                              style: gaya,
                              decoration: dekor(hint: 'Nama supplier baru'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          tombolTambah(tambahSupplier),
                        ],
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cariCtrl,
                      style: gaya,
                      decoration: dekor(
                        hint: 'Cari barang yang sudah ada',
                        prefix: const Icon(Icons.search, size: 18),
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
                              contentPadding: EdgeInsets.zero,
                              title: Text(s.nama, style: gayaTebal),
                              subtitle: Text(s.kode, style: gaya),
                              onTap: () =>
                                  tambahBarang(s.kode, s.nama, harga: s.harga),
                            ),
                        ],
                      ),
                    Row(
                      children: [
                        tautan(
                          Icons.download_outlined,
                          'Template',
                          unduhTemplate,
                        ),
                        tautan(
                          Icons.upload_file_outlined,
                          'Unggah barang masuk',
                          unggahBerkas,
                        ),
                      ],
                    ),
                    tajuk(
                      'Item baru',
                      tampilSkuBaru,
                      () => setLocal(() => tampilSkuBaru = !tampilSkuBaru),
                    ),
                    if (tampilSkuBaru) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: kodeBaruCtrl,
                              style: gaya,
                              decoration: dekor(hint: 'Kode'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: namaBaruCtrl,
                              style: gaya,
                              decoration: dekor(hint: 'Nama'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SizedBox(
                            width: lebarQty,
                            child: TextField(
                              controller: qtyBaruCtrl,
                              keyboardType: TextInputType.number,
                              style: gaya,
                              textAlign: TextAlign.center,
                              inputFormatters: const [FormatRibuan()],
                              decoration: dekor(hint: 'Qty'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: hargaBaruCtrl,
                              keyboardType: TextInputType.number,
                              style: gaya,
                              textAlign: TextAlign.right,
                              inputFormatters: const [FormatRibuan()],
                              decoration: dekor(hint: 'Harga beli'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          tombolTambah(tambahBaru),
                        ],
                      ),
                      Row(
                        children: [
                          tautan(
                            Icons.download_outlined,
                            'Template SKU baru',
                            unduhTemplateSku,
                          ),
                          tautan(
                            Icons.upload_file_outlined,
                            'Unggah SKU baru',
                            unggahSkuBaru,
                          ),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, thickness: 0.6),
                    ),
                    _barisNilai('Total input', totalInput()),
                    _barisNilai('Total supplier ini', totalHariIni()),
                    const SizedBox(height: 8),
                    if (baris.isEmpty)
                      Text(
                        'Belum ada barang masuk tanggal ini.',
                        style: gaya.copyWith(color: Colors.grey.shade600),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Barang', style: gayaTebal)),
                            SizedBox(
                              width: lebarQty,
                              child: const Text(
                                '+Qty',
                                textAlign: TextAlign.center,
                                style: gayaTebal,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: lebarHarga,
                              child: const Text(
                                'Harga beli',
                                textAlign: TextAlign.right,
                                style: gayaTebal,
                              ),
                            ),
                            const SizedBox(width: lebarHapus),
                          ],
                        ),
                      ),
                      ...baris.asMap().entries.map((e) {
                        final i = e.key;
                        final b = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.nama.isEmpty ? b.kode : b.nama,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: gayaTebal,
                                    ),
                                    Text(
                                      [
                                        b.kode,
                                        if (b.qtySudah > 0)
                                          'hari ini ${formatUang(b.qtySudah)}',
                                        if (b.nilai > 0)
                                          'Rp ${formatUang(b.nilai)}',
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: gaya.copyWith(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: lebarQty,
                                child: TextField(
                                  controller: b.qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  style: gaya,
                                  textAlign: TextAlign.center,
                                  inputFormatters: const [FormatRibuan()],
                                  decoration: dekor(hint: '0'),
                                  onChanged: (_) => setLocal(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: lebarHarga,
                                child: TextField(
                                  controller: b.hargaCtrl,
                                  keyboardType: TextInputType.number,
                                  style: gaya,
                                  textAlign: TextAlign.right,
                                  inputFormatters: const [FormatRibuan()],
                                  decoration: dekor(hint: '0'),
                                  onChanged: (_) => setLocal(() {}),
                                ),
                              ),
                              SizedBox(
                                width: lebarHapus,
                                child: IconButton(
                                  tooltip: 'Hapus',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: lebarHapus,
                                    minHeight: 32,
                                  ),
                                  iconSize: 18,
                                  onPressed: () {
                                    b.dispose();
                                    baris.removeAt(i);
                                    setLocal(() {});
                                  },
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.seed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
                FilledButton(onPressed: simpan, child: const Text('Pakai')),
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

  Future<
    ({
      bool ada,
      String status,
      int sku,
      int nilai,
      List<Map<String, dynamic>> beda,
    })
  >
  _ringkasOpname() async {
    final header = await _sb
        .from('stok_opname')
        .select('status')
        .eq('tanggal', _iso)
        .limit(1);
    if (header.isEmpty) {
      return (
        ada: false,
        status: '',
        sku: 0,
        nilai: 0,
        beda: <Map<String, dynamic>>[],
      );
    }
    final status = header.first['status']?.toString() ?? '';
    final raw = await _sb.rpc(
      'admin_opname_lihat',
      params: {'p_tanggal': _iso},
    );
    if (raw is! List || raw.isEmpty) {
      return (
        ada: true,
        status: status,
        sku: 0,
        nilai: 0,
        beda: <Map<String, dynamic>>[],
      );
    }
    final semua = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final beda = semua.where((r) => _angka(r['selisih_qty']) != 0).toList();
    final nilai = beda.fold<int>(0, (a, r) => a + _angka(r['nilai_selisih']));
    return (
      ada: true,
      status: status,
      sku: beda.length,
      nilai: nilai,
      beda: beda,
    );
  }

  Future<void> _cekOpname() async {
    if (_proses) return;
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      final ringkas = await _ringkasOpname();
      if (!mounted) return;
      setState(() {
        _proses = false;
        _opnameAda = ringkas.ada;
        _opnameStatus = ringkas.status;
        _opnameSelisihSku = ringkas.sku;
        _opnameNilaiSelisih = ringkas.nilai;
        _opnameBeda = ringkas.beda;
      });
      if (!ringkas.ada) {
        showAppSnackBar(
          context,
          message: 'Belum ada input opname dari aplikasi gudang.',
          warna: AppSnackBarTone.kuning,
        );
        return;
      }
      if (ringkas.beda.isEmpty) {
        showAppSnackBar(
          context,
          message: 'Opname cocok. Tidak ada selisih.',
          warna: AppSnackBarTone.hijau,
        );
        return;
      }
      await _dialogSelisihOpname();
    } catch (_) {
      if (!mounted) return;
      setState(() => _proses = false);
      showAppSnackBar(
        context,
        message: 'Gagal cek opname. Jalankan ulang arsip_harian.sql, lalu coba lagi.',
      );
    }
  }

  Future<void> _dialogSelisihOpname() async {
    if (_opnameBeda.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text('Selisih opname (${_opnameBeda.length})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in _opnameBeda)
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
  }

  Future<void> _pilihHari() async {
    if (!await _izinBuangDraf()) return;
    if (!mounted) return;
    final pilih = await showDatePicker(
      context: context,
      initialDate: _hari,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pilih == null) return;
    if (!mounted) return;
    setState(() => _hari = DateTime(pilih.year, pilih.month, pilih.day));
    await _muatData(layarPenuh: true, buangDraf: true);
  }

  String _selCsv(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(RegExp(r'[;"\n\r]'))) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  void _unduhHalaman() {
    final judul = [
      'Rute',
      'Kiriman',
      'Batal',
      'Pending',
      'Actual',
      'Transfer',
      'Mutasi',
      'Tunai',
      'Tunai admin',
      'BOP',
      'Kasbon',
      'Retur',
      'Cek',
    ].join(';');
    String barisDari(Map<String, dynamic> row, String nama) {
      final kasbon = row.containsKey('kasbon_supir')
          ? _angka(row['kasbon_supir']) + _angka(row['kasbon_kenek'])
          : _angka(row['kasbon']);
      return [
        nama,
        _angka(row['kiriman']),
        _angka(row['batal']),
        _angka(row['pending']),
        _angka(row['actual']),
        _angka(row['transfer']),
        _angka(row['transfer_mutasi']),
        _angka(row['tunai']),
        _angka(row['tunai_admin']),
        _angka(row['bop']),
        kasbon,
        _angka(row['retur']),
        row['sudah_setor'] == true ? _angka(row['sesa_cek']) : '',
      ].map(_selCsv).join(';');
    }

    final isi = <String>[judul];
    for (final row in _truk) {
      isi.add(barisDari(row, row['rute_pengirim']?.toString() ?? ''));
    }
    isi.add(barisDari(_jumlahEmpatTim(), 'Jumlah'));
    unduhCsv(nama: 'setoran_$_iso.csv', isi: isi.join('\n'));
  }

  Future<void> _simpanHalaman() async {
    if (!_kotor) {
      showAppSnackBar(
        context,
        message: 'Tidak ada perubahan untuk disimpan.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      for (final rute in _drafTunai.keys) {
        final ok = await _sb.rpc(
          'admin_setoran_simpan_tunai',
          params: {
            'p_tanggal': _iso,
            'p_rute': rute,
            'p_tunai': _drafTunai[rute],
            'p_pecahan': _drafPecahan[rute] ?? const <int>[],
          },
        );
        if (ok != true) throw Exception('tunai');
      }
      if (_mutasiGantiIsi) {
        await _sb.rpc('admin_mutasi_hapus', params: {'p_tanggal': _iso});
        if (_mutasi.isNotEmpty) {
          final urut = [..._mutasi]
            ..sort((a, b) {
              final c = _angka(b['jumlah']).compareTo(_angka(a['jumlah']));
              if (c != 0) return c;
              return _angka(a['id']).compareTo(_angka(b['id']));
            });
          await _sb.rpc(
            'admin_mutasi_unggah',
            params: {
              'p_tanggal': _iso,
              'p_nama_berkas': _namaBerkasMutasi,
              'p_baris': [
                for (final m in urut)
                  {
                    'tanggal_mutasi': m['tanggal_mutasi']?.toString(),
                    'jumlah': _angka(m['jumlah']),
                    'berita': m['berita']?.toString() ?? '',
                    'rekening': m['rekening_alias']?.toString() ?? '',
                  },
              ],
            },
          );
          final raw = await _sb.rpc(
            'admin_mutasi_lihat',
            params: {'p_tanggal': _iso},
          );
          final cloud = raw is List
              ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : <Map<String, dynamic>>[];
          for (var i = 0; i < urut.length && i < cloud.length; i++) {
            final rute = urut[i]['rute_pengirim']?.toString() ?? '';
            await _sb.rpc(
              'admin_mutasi_set_rute',
              params: {'p_id': _angka(cloud[i]['id']), 'p_rute': rute},
            );
          }
        }
      } else {
        for (final m in _mutasi) {
          final id = _angka(m['id']);
          if (id <= 0) continue;
          final rute = m['rute_pengirim']?.toString() ?? '';
          if (rute == (_ruteMutasiAwal[id] ?? '')) continue;
          await _sb.rpc(
            'admin_mutasi_set_rute',
            params: {'p_id': id, 'p_rute': rute},
          );
        }
      }
      for (final d in _drafMasuk) {
        final ok = await _sb.rpc(
          'admin_barang_masuk_simpan',
          params: {
            'p_tanggal': _iso,
            'p_id_supplier': d.idSupplier,
            'p_baris': d.baris,
            'p_keterangan': '',
          },
        );
        if (ok != true) throw Exception('masuk');
      }
      for (final e in _drafRetur.entries) {
        final ok = await _sb.rpc(
          'admin_retur_item_simpan',
          params: {'p_tanggal': _iso, 'p_rute': e.key, 'p_baris': e.value},
        );
        if (ok != true) throw Exception('retur');
      }
      for (final e in _drafPendingCek.entries) {
        final rute = _drafPendingRute[e.key] ?? '';
        if (rute.isEmpty) continue;
        final ok = await _sb.rpc(
          'admin_setoran_pending_cek_set',
          params: {
            'p_tanggal': _iso,
            'p_id_nota': e.key,
            'p_rute': rute,
            'p_cek': e.value,
          },
        );
        if (ok != true) throw Exception('pending');
      }
      for (final e in _drafBatalCek.entries) {
        final ok = await _sb.rpc(
          'admin_setoran_batal_cek_set',
          params: {
            'p_tanggal': _iso,
            'p_rute': e.value.rute,
            'p_kunci': e.key,
            'p_cek': e.value.cek,
          },
        );
        if (ok != true) throw Exception('batal');
      }
      for (final row in [..._pengirim, ..._gudang]) {
        final kunci = row['nama_kunci']?.toString() ?? '';
        if (kunci.isEmpty) continue;
        final hadir = row['hadir'] == true;
        if (hadir == (_hadirAwal[kunci] ?? false)) continue;
        final ok = await _sb.rpc(
          'gaji_set_absensi',
          params: {'p_tanggal': _iso, 'p_nama_kunci': kunci, 'p_hadir': hadir},
        );
        if (ok != true) throw Exception('absen');
      }
      if (!mounted) return;
      _resetDraf();
      await _muatData(buangDraf: true);
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Setoran disimpan ke cloud.',
        warna: AppSnackBarTone.hijau,
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, message: 'Gagal menyimpan setoran ke cloud.');
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
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
        message: 'Ekspor mutasi ke CSV dulu. Workbook harian SETORAN tidak diunggah.',
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
    _idMutasiLokal -= hasil.baris.length;
    var id = _idMutasiLokal;
    final baru = <Map<String, dynamic>>[
      for (final b in hasil.baris)
        {
          'id': id++,
          'tanggal_mutasi': b.tanggalMutasi,
          'jumlah': b.jumlah,
          'berita': b.berita,
          'rekening_alias': b.rekening,
          'rute_pengirim': _ruteDariBerita(b.berita) ?? '',
          'status_cocok': '',
        },
    ];
    setState(() {
      _kotor = true;
      _mutasiGantiIsi = true;
      _namaBerkasMutasi = nama;
      _pasangMutasiLokal([..._mutasi, ...baru]);
    });
  }

  void _pasangMutasiLokal(List<Map<String, dynamic>> mutasi) {
    mutasi = _saringMutasiKredit(mutasi);
    _mutasi = mutasi;
    _truk = _timpaTransferMutasi(_truk, mutasi);
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
    setState(() {
      _kotor = true;
      _mutasiGantiIsi = true;
      _pasangMutasiLokal([]);
    });
  }

  Future<void> _setRuteMutasi(int id, String? rute) async {
    setState(() {
      _kotor = true;
      _mutasi = [
        for (final m in _mutasi)
          if (_angka(m['id']) == id)
            {
              ...m,
              'rute_pengirim': rute ?? '',
              if ((rute ?? '').isNotEmpty) 'status_cocok': 'manual',
            }
          else
            m,
      ];
      _truk = _timpaTransferMutasi(_truk, _mutasi);
    });
  }

  Future<void> _simpanTunai(String rute, int tunai, List<int> pecahan) async {
    _drafTunai[rute] = tunai;
    _drafPecahan[rute] = pecahan;
    _timpaBarisTruk(rute, {'tunai_admin': tunai, 'pecahan_tunai': pecahan});
    _tandaiKotor();
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
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: List.generate(pecahan.length, (i) {
                      final p = pecahan[i];
                      final hasil = p.nilai * angkaTeks(pecahanCtrl[i].text);
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: TextField(
                              controller: pecahanCtrl[i],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: gaya,
                              inputFormatters: const [FormatRibuan(kosong: '')],
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
                  child: const Text('Pakai'),
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

  Future<void> _dialogTunaiJumlah() async {
    final qty = List<int>.filled(_pecahanTunai.length, 0);
    for (final row in _truk) {
      final pecahan = _qtyPecahan(row);
      for (var i = 0; i < qty.length && i < pecahan.length; i++) {
        qty[i] += pecahan[i];
      }
    }
    var total = 0;
    for (var i = 0; i < _pecahanTunai.length; i++) {
      total += _pecahanTunai[i].nilai * qty[i];
    }
    if (!mounted) return;
    const gaya = TextStyle(fontSize: 12, height: 1.2);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AppDialog(
          title: const Text('Tunai admin semua rute'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Table(
                columnWidths: const {
                  0: FixedColumnWidth(52),
                  1: FixedColumnWidth(18),
                  2: FixedColumnWidth(52),
                  3: FixedColumnWidth(58),
                  4: FixedColumnWidth(18),
                  5: FixedColumnWidth(80),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (var i = 0; i < _pecahanTunai.length; i++)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            formatUang(qty[i]),
                            textAlign: TextAlign.center,
                            style: gaya,
                          ),
                        ),
                        Text('×', style: gaya, textAlign: TextAlign.center),
                        Text(_pecahanTunai[i].jenis, style: gaya),
                        Text(
                          _pecahanTunai[i].label,
                          style: gaya,
                          textAlign: TextAlign.right,
                        ),
                        Text('=', style: gaya, textAlign: TextAlign.center),
                        _uangSel(_pecahanTunai[i].nilai * qty[i]),
                      ],
                    ),
                ],
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
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 18,
                    child: Text('=', style: gaya, textAlign: TextAlign.center),
                  ),
                  SizedBox(width: 80, child: _uangSel(total, tebal: true)),
                ],
              ),
              const SizedBox(height: 8),
              for (final row in _truk)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _barisNilai(
                    row['rute_pengirim']?.toString() ?? '',
                    row['tunai_admin'],
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
        );
      },
    );
  }

  Future<void> _dialogNota({required bool pending, String? rute}) async {
    if (!await _adaNet()) return;
    final daftarRute = (rute == null || rute.isEmpty)
        ? List<String>.from(_rute)
        : [rute];
    final semua = daftarRute.length > 1;
    List<Map<String, dynamic>> nota = [];
    try {
      for (final r in daftarRute) {
        final raw = await _sb.rpc(
          'admin_setoran_nota',
          params: {'p_tanggal': _iso, 'p_rute': r},
        );
        if (raw is! List) continue;
        for (final e in raw) {
          final m = Map<String, dynamic>.from(e as Map);
          m['rute_pengirim'] = r;
          nota.add(m);
        }
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: semua
            ? 'Gagal memuat nota semua rute.'
            : 'Gagal memuat nota ${daftarRute.first}.',
      );
      return;
    }
    if (pending) {
      nota = nota.where((n) => n['pending'] == true).toList();
    } else {
      nota = nota
          .where(
            (n) => n['status']?.toString() == 'batal' || _angka(n['batal']) > 0,
          )
          .toList();
    }
    if (!mounted) return;
    if (pending && nota.isNotEmpty) {
      try {
        final rawCek = await _sb.rpc(
          'admin_setoran_pending_cek_lihat',
          params: {'p_tanggal': _iso},
        );
        final cek = <String>{};
        if (rawCek is List) {
          for (final e in rawCek) {
            if (e is! Map) continue;
            final id = (e['id_nota']?.toString() ?? '').trim();
            if (id.isNotEmpty) cek.add(id);
          }
        }
        for (final n in nota) {
          final id = (n['id_nota']?.toString() ?? '').trim();
          n['dicek'] = id.isNotEmpty && cek.contains(id);
          if (id.isNotEmpty && _drafPendingCek.containsKey(id)) {
            n['dicek'] = _drafPendingCek[id];
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        Widget tabelNota(void Function(void Function())? setLocal) {
          return DataTable(
            border: _garisKolom,
            columnSpacing: 12,
            horizontalMargin: 8,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 44,
            columns: [
              if (pending)
                const DataColumn(
                  headingRowAlignment: MainAxisAlignment.center,
                  label: SizedBox(width: 28),
                ),
              if (semua)
                const DataColumn(
                  headingRowAlignment: MainAxisAlignment.center,
                  label: Text('Rute'),
                ),
              const DataColumn(
                headingRowAlignment: MainAxisAlignment.center,
                label: Text('Pelanggan'),
              ),
              const DataColumn(
                headingRowAlignment: MainAxisAlignment.center,
                label: Text('Nota'),
              ),
              if (!pending)
                const DataColumn(
                  headingRowAlignment: MainAxisAlignment.center,
                  label: Text('Status'),
                ),
              const DataColumn(
                headingRowAlignment: MainAxisAlignment.center,
                numeric: true,
                label: Text('Packed'),
              ),
              if (!pending)
                const DataColumn(
                  headingRowAlignment: MainAxisAlignment.center,
                  numeric: true,
                  label: Text('Actual'),
                ),
              if (!pending)
                const DataColumn(
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
                onTap: () =>
                    pending ? _dialogRincianPending(n) : _dialogRincianBatal(n),
              );
              return DataRow(
                cells: [
                  if (pending)
                    DataCell(
                      Checkbox(
                        value: n['dicek'] == true,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: _proses || setLocal == null
                            ? null
                            : (v) {
                                final id = (n['id_nota']?.toString() ?? '')
                                    .trim();
                                final ruteNota =
                                    n['rute_pengirim']?.toString() ?? '';
                                if (id.isEmpty || ruteNota.isEmpty) return;
                                final cek = v ?? false;
                                n['dicek'] = cek;
                                _drafPendingCek[id] = cek;
                                _drafPendingRute[id] = ruteNota;
                                _kotor = true;
                                setLocal(() {});
                                _timpaPendingDicekDariNota(nota, daftarRute);
                              },
                      ),
                    ),
                  if (semua)
                    DataCell(Text(n['rute_pengirim']?.toString() ?? '')),
                  DataCell(Text('${n['nama_pelanggan'] ?? '-'}')),
                  selNota,
                  if (!pending)
                    DataCell(
                      Text(selPending ? 'pending' : '${n['status'] ?? ''}'),
                    ),
                  DataCell(Text(formatUang(n['packed']))),
                  if (!pending) DataCell(Text(formatUang(n['actual']))),
                  if (!pending) DataCell(Text(formatUang(n['batal']))),
                ],
              );
            }).toList(),
          );
        }

        Widget isiDialog(void Function(void Function())? setLocal) {
          return AppDialog(
            title: Text(
              pending
                  ? (semua
                        ? 'Nota pending semua rute'
                        : 'Nota pending ${daftarRute.first}')
                  : (semua
                        ? 'Nota batal semua rute'
                        : 'Nota batal ${daftarRute.first}'),
            ),
            content: nota.isEmpty
                ? Text(
                    pending
                        ? 'Tidak ada nota pending untuk tanggal ini.'
                        : 'Tidak ada nota batal untuk tanggal ini.',
                  )
                : tabelNota(setLocal),
            actions: [
              TextButton.icon(
                onPressed: nota.isEmpty
                    ? null
                    : () => pending
                          ? _dialogSemuaItemPending(
                              semua ? null : daftarRute.first,
                            )
                          : _dialogSemuaItemBatal(
                              semua ? null : daftarRute.first,
                            ),
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
        }

        if (!pending) return isiDialog(null);
        return StatefulBuilder(
          builder: (context, setLocal) => isiDialog(setLocal),
        );
      },
    );
  }

  String _labelKasbon(Map<String, dynamic> row, String peran) {
    final peranTeks = peran == 'supir' ? 'Supir' : 'Kenek';
    final nama = peran == 'supir'
        ? (row['nama_supir']?.toString() ?? '').trim()
        : (row['nama_kenek']?.toString() ?? '').trim();
    if (nama.isEmpty) return peranTeks;
    return '$peranTeks $nama';
  }

  Widget _isiDialogKasbon(List<Map<String, dynamic>> truk) {
    const gaya = TextStyle(fontSize: 12, height: 1.2);
    const gayaTebal = TextStyle(
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.bold,
    );
    var total = 0;
    final baris = <Widget>[];
    for (final row in truk) {
      final rute = row['rute_pengirim']?.toString() ?? '';
      final supir = _angka(row['kasbon_supir']);
      final kenek = _angka(row['kasbon_kenek']);
      total += supir + kenek;
      if (truk.length > 1) {
        baris.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 4),
            child: Text(rute, style: gayaTebal),
          ),
        );
      }
      baris.add(_barisNilai(_labelKasbon(row, 'supir'), supir));
      baris.add(_barisNilai(_labelKasbon(row, 'kenek'), kenek));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...baris,
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, thickness: 0.6),
        ),
        Row(
          children: [
            const Expanded(child: Text('Kasbon', style: gayaTebal)),
            SizedBox(
              width: 18,
              child: Text('=', style: gaya, textAlign: TextAlign.center),
            ),
            SizedBox(width: 80, child: _uangSel(total, tebal: true)),
          ],
        ),
      ],
    );
  }

  Future<void> _dialogKasbon(Map<String, dynamic> row) async {
    final rute = row['rute_pengirim']?.toString() ?? '';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AppDialog(
          title: Text('Kasbon $rute'),
          content: _isiDialogKasbon([row]),
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

  Future<void> _dialogKasbonJumlah() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AppDialog(
          title: const Text('Kasbon semua rute'),
          content: _isiDialogKasbon(_truk),
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

    final drafRetur = _drafRetur[rute];
    if (drafRetur != null) {
      for (final b in baris) {
        b.dispose();
      }
      baris
        ..clear()
        ..addAll([
          for (final m in drafRetur)
            _BarisCocokRetur(
              kode: m['kode_barang']?.toString() ?? '',
              nama: m['nama_barang']?.toString() ?? '',
              qty: _angka(m['qty']),
            ),
        ]);
    }

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
              final kirim = baris
                  .where((b) => b.kode.isNotEmpty && b.qty > 0)
                  .map(
                    (b) => {
                      'kode_barang': b.kode,
                      'nama_barang': b.nama,
                      'qty': b.qty,
                    },
                  )
                  .toList();
              _drafRetur[rute] = kirim;
              _timpaBarisTruk(rute, {
                'retur_dicek':
                    _angka(row['retur']) != 0 && baris.any((b) => b.qty > 0),
              });
              _tandaiKotor();
              if (ctx.mounted) Navigator.pop(ctx);
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
                FilledButton(onPressed: simpan, child: const Text('Pakai')),
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

  Future<void> _dialogReturJumlah() async {
    if (!await _adaNet()) return;
    var nominal = 0;
    final pesan = <String>[];
    try {
      final raw = await _sb.rpc(
        'admin_retur_lihat',
        params: {'p_tanggal': _iso},
      );
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final rute = m['rute_pengirim']?.toString() ?? '';
          if (!_rute.contains(rute)) continue;
          nominal += _angka(m['jumlah_usul']);
          final isi = (m['catatan_usul']?.toString() ?? '').trim();
          if (isi.isNotEmpty) pesan.add('$rute: $isi');
        }
      }
    } catch (_) {}
    List<Map<String, dynamic>> items = [];
    try {
      items = await _gabungItemHari(
        rpc: 'admin_retur_item_lihat',
        daftarRute: List<String>.from(_rute),
      );
    } catch (_) {}
    if (!mounted) return;
    final totalQty = items.fold<int>(0, (a, it) => a + _angka(it['qty']));
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AppDialog(
          title: const Text('Retur semua rute'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _barisNilai('Qty cocok', totalQty),
                _barisNilai('Nominal', nominal),
                const SizedBox(height: 8),
                const Text(
                  'Pesan pengirim',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  pesan.isEmpty ? 'Tidak ada pesan retur.' : pesan.join('\n'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: pesan.isEmpty ? Colors.grey.shade600 : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Text(
                    'Belum ada barang retur untuk tanggal ini.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  )
                else
                  DataTable(
                    border: _garisKolom,
                    columnSpacing: 12,
                    horizontalMargin: 8,
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 44,
                    columns: const [
                      DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text('Barang'),
                      ),
                      DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        numeric: true,
                        label: Text('Qty'),
                      ),
                    ],
                    rows: items
                        .map(
                          (it) => DataRow(
                            cells: [
                              DataCell(Text(_labelBarang(it))),
                              DataCell(Text('${_angka(it['qty'])}')),
                            ],
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
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

  String _labelBarang(Map<String, dynamic> it) {
    final nama = (it['nama_barang']?.toString() ?? '').trim();
    final kode = it['kode_barang']?.toString() ?? '';
    if (nama.isNotEmpty) return nama;
    if (kode.isNotEmpty) return kode;
    return 'Barang';
  }

  String _kunciBarang(Map<String, dynamic> it) {
    final tersimpan = (it['kunci_barang']?.toString() ?? '').trim();
    if (tersimpan.isNotEmpty) return tersimpan;
    final kode = (it['kode_barang']?.toString() ?? '').trim();
    if (kode.isNotEmpty) return kode;
    final nama = (it['nama_barang']?.toString() ?? '').trim();
    if (nama.isNotEmpty) return nama;
    return 'Barang';
  }

  void _timpaBatalDicekDariItem(
    List<Map<String, dynamic>> items,
    List<String> daftarRute,
  ) {
    setState(() {
      _truk = [
        for (final row in _truk)
          () {
            final rute = row['rute_pengirim']?.toString() ?? '';
            if (!daftarRute.contains(rute)) return row;
            final punya = items
                .where(
                  (it) =>
                      List<String>.from((it['rute_list'] as List?) ?? const [])
                          .contains(rute),
                )
                .toList();
            return {
              ...row,
              'batal_dicek':
                  punya.isNotEmpty && punya.every((it) => it['dicek'] == true),
            };
          }(),
      ];
    });
  }

  void _timpaPendingDicekDariNota(
    List<Map<String, dynamic>> nota,
    List<String> daftarRute,
  ) {
    setState(() {
      _truk = [
        for (final row in _truk)
          () {
            final rute = row['rute_pengirim']?.toString() ?? '';
            if (!daftarRute.contains(rute)) return row;
            final punya = nota
                .where((n) => n['rute_pengirim']?.toString() == rute)
                .toList();
            return {
              ...row,
              'pending_dicek':
                  punya.isNotEmpty && punya.every((n) => n['dicek'] == true),
            };
          }(),
      ];
    });
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

  Future<List<Map<String, dynamic>>> _gabungItemHari({
    required String rpc,
    required List<String> daftarRute,
  }) async {
    final gabung = <String, Map<String, dynamic>>{};
    for (final r in daftarRute) {
      final raw = await _sb.rpc(rpc, params: {'p_tanggal': _iso, 'p_rute': r});
      if (raw is! List) continue;
      for (final e in raw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final kunci = _kunciBarang(m);
        m['kunci_barang'] = kunci;
        final lama = gabung[kunci];
        if (lama == null) {
          m['rute_list'] = [r];
          gabung[kunci] = m;
        } else {
          lama['qty'] = _angka(lama['qty']) + _angka(m['qty']);
          lama['packed'] = _angka(lama['packed']) + _angka(m['packed']);
          final ruteList = List<String>.from(
            (lama['rute_list'] as List?) ?? const [],
          );
          if (!ruteList.contains(r)) ruteList.add(r);
          lama['rute_list'] = ruteList;
        }
      }
    }
    final items = gabung.values.toList()
      ..sort(
        (a, b) =>
            _labelBarang(a)
                .toLowerCase()
                .compareTo(_labelBarang(b).toLowerCase()),
      );
    return items;
  }

  Future<void> _dialogSemuaItemPending(String? rute) async {
    if (!await _adaNet()) return;
    final daftarRute = (rute == null || rute.isEmpty)
        ? List<String>.from(_rute)
        : [rute];
    List<Map<String, dynamic>> items = [];
    try {
      items = await _gabungItemHari(
        rpc: 'admin_setoran_nota_item_pending',
        daftarRute: daftarRute,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Gagal memuat item pending. Jalankan ulang admin_setoran.sql di Supabase, lalu coba lagi.',
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
    final totalPacked = items.fold<int>(0, (a, it) => a + _angka(it['packed']));
    await _dialogTabelBarang(
      judul: daftarRute.length > 1
          ? 'Semua item pending'
          : 'Semua item pending ${daftarRute.first}',
      atas: [Text('Qty $totalQty · Packed Rp ${formatUang(totalPacked)}')],
      items: items,
      kolomNilai: 'Packed',
    );
  }

  Future<void> _dialogSemuaItemBatal(String? rute) async {
    if (!await _adaNet()) return;
    final daftarRute = (rute == null || rute.isEmpty)
        ? List<String>.from(_rute)
        : [rute];
    List<Map<String, dynamic>> items = [];
    try {
      items = await _gabungItemHari(
        rpc: 'admin_setoran_nota_item_batal_hari',
        daftarRute: daftarRute,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Gagal memuat item batal. Jalankan ulang admin_setoran.sql di Supabase, lalu coba lagi.',
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
    try {
      final rawCek = await _sb.rpc(
        'admin_setoran_batal_cek_lihat',
        params: {'p_tanggal': _iso},
      );
      final cek = <String>{};
      if (rawCek is List) {
        for (final e in rawCek) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final r = m['rute_pengirim']?.toString() ?? '';
          final k = (m['kunci_barang']?.toString() ?? '').trim();
          if (r.isNotEmpty && k.isNotEmpty) cek.add('$r|$k');
        }
      }
      for (final it in items) {
        final kunci = _kunciBarang(it);
        final ruteList = List<String>.from(
          (it['rute_list'] as List?) ?? daftarRute,
        );
        it['dicek'] =
            ruteList.isNotEmpty &&
            ruteList.every((r) => cek.contains('$r|$kunci'));
        if (_drafBatalCek.containsKey(kunci)) {
          it['dicek'] = _drafBatalCek[kunci]!.cek;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    final totalQty = items.fold<int>(0, (a, it) => a + _angka(it['qty']));
    final totalNilai = items.fold<int>(0, (a, it) => a + _angka(it['packed']));
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            void ubahCek(Map<String, dynamic> it, bool cek) {
              final kunci = _kunciBarang(it);
              final ruteList = List<String>.from(
                (it['rute_list'] as List?) ?? daftarRute,
              );
              if (kunci.isEmpty || ruteList.isEmpty) return;
              it['dicek'] = cek;
              _drafBatalCek[kunci] = (rute: ruteList, cek: cek);
              _kotor = true;
              setLocal(() {});
              _timpaBatalDicekDariItem(items, daftarRute);
            }

            return AppDialog(
              title: Text(
                daftarRute.length > 1
                    ? 'Semua item batal'
                    : 'Semua item batal ${daftarRute.first}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Qty $totalQty · Batal Rp ${formatUang(totalNilai)}'),
                  const SizedBox(height: 8),
                  DataTable(
                    border: _garisKolom,
                    columnSpacing: 12,
                    horizontalMargin: 8,
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 44,
                    columns: const [
                      DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        label: SizedBox(width: 28),
                      ),
                      DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        label: Text('Barang'),
                      ),
                      DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        numeric: true,
                        label: Text('Qty'),
                      ),
                      DataColumn(
                        headingRowAlignment: MainAxisAlignment.center,
                        numeric: true,
                        label: Text('Batal'),
                      ),
                    ],
                    rows: items
                        .map(
                          (it) => DataRow(
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: it['dicek'] == true,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: _proses
                                      ? null
                                      : (v) => ubahCek(it, v ?? false),
                                ),
                              ),
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
      },
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
        message: 'Gagal memuat rincian. Jalankan ulang admin_setoran.sql di Supabase, lalu coba lagi.',
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
        message: 'Gagal memuat rincian. Jalankan ulang admin_setoran.sql di Supabase, lalu coba lagi.',
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
    setState(() {
      _kotor = true;
      if (peran == 'pengirim') {
        _pengirim = _timpaHadir(_pengirim, kunci, hadir);
      } else {
        _gudang = _timpaHadir(_gudang, kunci, hadir);
      }
    });
  }

  List<String> _bendera(Map<String, dynamic> row) {
    final out = <String>[];
    if (_angka(row['jumlah_dikirim']) > 0) {
      out.add('Masih ${_angka(row['jumlah_dikirim'])} nota dikirim');
    }
    if (row['bop_lebih'] == true) {
      out.add('BOP > 170.000');
    }
    if (row['sesa_tidak_nol'] == true) {
      out.add('Setoran pengirim tidak seimbang');
    }
    if (row['tunai_beda'] == true) {
      out.add('Tunai admin ≠ pengirim');
    }
    if (row['transfer_beda'] == true) {
      out.add('Mutasi ≠ transfer');
    }
    return out;
  }

  Widget _uangSel(dynamic n, {Color? warna, bool tebal = true}) {
    final gaya = TextStyle(
      fontSize: _teksIsi,
      height: 1.15,
      color: warna ?? Colors.black,
      fontWeight: tebal ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      children: [
        SizedBox(width: 22, child: Text('Rp', style: gaya)),
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
    Alignment alignment = Alignment.centerLeft,
  }) {
    return SizedBox(
      width: lebar,
      child: OverflowBox(
        alignment: alignment,
        maxWidth: lebar,
        maxHeight: double.infinity,
        child: child,
      ),
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

  Widget _chipTombol({
    required String label,
    required VoidCallback onTap,
    bool adaIsi = false,
    bool ceklis = false,
    double? tinggi,
    bool lebarPenuh = true,
    bool rataTengah = false,
    double? ukuranFont,
  }) {
    final Color chipWarna;
    if (ceklis && adaIsi) {
      chipWarna = Colors.green.shade700;
    } else if (adaIsi) {
      chipWarna = Colors.orange.shade800;
    } else {
      chipWarna = AppTheme.seed;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _proses ? null : onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: lebarPenuh ? double.infinity : null,
          height: tinggi ?? _tinggiBarisNilai,
          constraints: lebarPenuh
              ? null
              : const BoxConstraints(maxWidth: _lebarLabelNilai),
          padding: EdgeInsets.symmetric(horizontal: lebarPenuh ? 8 : 6),
          alignment: rataTengah ? Alignment.center : Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: chipWarna, width: 1.2),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: rataTengah ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: chipWarna,
              fontWeight: FontWeight.bold,
              fontSize: ukuranFont ?? 11,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _barisNilai(
    String label,
    dynamic n, {
    String? teks,
    VoidCallback? onLabel,
    bool ceklis = false,
  }) {
    final angka = _angka(n);
    final aksi = onLabel;
    final labelTeks = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        height: 1.15,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
    final Widget labelKiri;
    if (aksi != null && angka != 0) {
      labelKiri = _chipTombol(
        label: label,
        onTap: aksi,
        adaIsi: true,
        ceklis: ceklis,
      );
    } else {
      labelKiri = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: aksi == null || _proses ? null : aksi,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: labelTeks,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: _tinggiBarisNilai,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _lebarLabelNilai,
            child: labelKiri,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: teks != null
                ? Text(
                    teks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: _teksIsi,
                      height: 1.15,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : _uangSel(n),
          ),
        ],
      ),
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
          onLabel: onBatal,
          ceklis: row['batal_dicek'] == true && _angka(row['batal']) > 0,
        ),
        _barisNilai(
          'Pending',
          row['pending'],
          onLabel: onPending,
          ceklis: row['pending_dicek'] == true && _angka(row['pending']) > 0,
        ),
        _barisNilai('Actual', row['actual']),
      ],
    );
  }

  Widget _kolomSetor(
    Map<String, dynamic> row, {
    VoidCallback? onTunaiAdmin,
    bool ceklisTunai = false,
  }) {
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
          ceklis: ceklisTunai,
        ),
      ],
    );
  }

  Widget _kolomHitung(
    Map<String, dynamic> row,
    int kasbon, {
    VoidCallback? onKasbon,
    VoidCallback? onRetur,
    bool ceklisRetur = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _barisNilai('BOP', row['bop']),
        _barisNilai('Kasbon', kasbon, onLabel: onKasbon),
        _barisNilai(
          'Retur',
          row['retur'],
          onLabel: onRetur,
          ceklis: ceklisRetur,
        ),
        _barisNilai('Cek', row['sesa_cek']),
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
      cek += _angka(row['sesa_cek']);
      if (row['sudah_setor'] == true) adaSetor = true;
      if (row['bop_lebih'] == true) bopLebih = true;
    }
    final adaBatal = batal > 0;
    final batalDicek =
        adaBatal &&
        _truk.every(
          (row) => _angka(row['batal']) <= 0 || row['batal_dicek'] == true,
        );
    final adaPending = pending > 0;
    final pendingDicek =
        adaPending &&
        _truk.every(
          (row) => _angka(row['pending']) <= 0 || row['pending_dicek'] == true,
        );
    final tunaiDicek =
        _truk.isNotEmpty &&
        tunai > 0 &&
        _truk.every(
          (row) => _angka(row['tunai']) == _angka(row['tunai_admin']),
        );
    final adaRetur = retur != 0;
    final returDicek =
        adaRetur &&
        _truk.every(
          (row) => _angka(row['retur']) == 0 || row['retur_dicek'] == true,
        );
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
      'batal_dicek': batalDicek,
      'pending_dicek': pendingDicek,
      'tunai_dicek': tunaiDicek,
      'retur_dicek': returDicek,
    };
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      rute,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _teksIsi,
                        height: 1.15,
                      ),
                    ),
                    if (bendera.isNotEmpty)
                      Text(
                        bendera.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: _teksIsi,
                          height: 1.15,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                alignment: Alignment.center,
              ),
            ),
            DataCell(
              _kotakKolom(
                _lebarNilai,
                _kolomNota(
                  row,
                  onPending: () => _dialogNota(pending: true, rute: rute),
                  onBatal: () => _dialogNota(pending: false, rute: rute),
                ),
              ),
            ),
            DataCell(
              _kotakKolom(
                _lebarNilai,
                _kolomSetor(
                  row,
                  onTunaiAdmin: () => _dialogTunai(row),
                  ceklisTunai:
                      _angka(row['tunai']) > 0 &&
                      _angka(row['tunai']) == _angka(row['tunai_admin']),
                ),
              ),
            ),
            DataCell(
              _kotakKolom(
                _lebarNilai,
                _kolomHitung(
                  row,
                  kasbon,
                  onKasbon: () => _dialogKasbon(row),
                  onRetur: () => _dialogRetur(row),
                  ceklisRetur:
                      row['retur_dicek'] == true && _angka(row['retur']) != 0,
                ),
              ),
            ),
          ],
        );
      }),
    ];
  }

  Widget _kartuJumlahSetoran({required double tinggiBaris}) {
    final jumlah = _jumlahEmpatTim();
    final kasbon = _angka(jumlah['kasbon']);
    return SizedBox(
      height: _tinggiKartuSetoran(1, tinggiBaris),
      child: _kartuTabel(
        DataTable(
          headingRowHeight: _tinggiJudulSetoran,
          dataRowMinHeight: tinggiBaris,
          dataRowMaxHeight: tinggiBaris,
          dividerThickness: 0,
          columnSpacing: 16,
          horizontalMargin: 10,
          border: _garisKolom,
          columns: _judulSetoran,
          rows: [
            DataRow(
              cells: [
                DataCell(
                  _kotakKolom(
                    _lebarRute,
                    const Text(
                      'Jumlah',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _teksIsi,
                        height: 1.15,
                      ),
                    ),
                    alignment: Alignment.center,
                  ),
                ),
                DataCell(
                  _kotakKolom(
                    _lebarNilai,
                    _kolomNota(
                      jumlah,
                      onPending: () => _dialogNota(pending: true),
                      onBatal: () => _dialogNota(pending: false),
                    ),
                  ),
                ),
                DataCell(
                  _kotakKolom(
                    _lebarNilai,
                    _kolomSetor(
                      jumlah,
                      onTunaiAdmin: _dialogTunaiJumlah,
                      ceklisTunai: jumlah['tunai_dicek'] == true,
                    ),
                  ),
                ),
                DataCell(
                  _kotakKolom(
                    _lebarNilai,
                    _kolomHitung(
                      jumlah,
                      kasbon,
                      onKasbon: _dialogKasbonJumlah,
                      onRetur: _dialogReturJumlah,
                      ceklisRetur: jumlah['retur_dicek'] == true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _selMutasi(Widget child, {Alignment align = Alignment.centerLeft}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Align(alignment: align, child: child),
    );
  }

  Widget _tabelMutasi() {
    const gaya = TextStyle(
      fontSize: _teksIsi,
      height: 1.15,
      fontWeight: FontWeight.bold,
    );
    const gayaJudul = TextStyle(
      fontSize: _teksIsi,
      fontWeight: FontWeight.bold,
    );
    Widget judul(String teks) =>
        _selMutasi(Text(teks, style: gayaJudul), align: Alignment.center);
    final baris = <TableRow>[
      TableRow(
        children: [
          judul('Tanggal'),
          judul('Jumlah'),
          judul('Rekening'),
          judul('Rute'),
          judul('Status'),
        ],
      ),
    ];
    for (final m in _mutasi) {
      final id = _angka(m['id']);
      final rute = m['rute_pengirim']?.toString();
      final status = m['status_cocok']?.toString() ?? '';
      baris.add(
        TableRow(
          children: [
            _selMutasi(Text('${m['tanggal_mutasi'] ?? '-'}', style: gaya)),
            _selMutasi(_uangSel(m['jumlah'], tebal: true)),
            _selMutasi(
              Text(
                '${m['rekening_alias'] ?? '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: gaya,
              ),
            ),
            _selMutasi(
              DropdownButton<String>(
                value: _rute.contains(rute) ? rute : '',
                isDense: true,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                alignment: Alignment.center,
                style: gaya,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text(
                      '-',
                      style: TextStyle(
                        fontSize: _teksIsi,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._rute.map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r,
                        style: const TextStyle(
                          fontSize: _teksIsi,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: _proses
                    ? null
                    : (v) => _setRuteMutasi(
                        id,
                        (v == null || v.isEmpty) ? null : v,
                      ),
              ),
              align: Alignment.center,
            ),
            _selMutasi(
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          ],
        ),
      );
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.15),
        1: FlexColumnWidth(1.35),
        2: FlexColumnWidth(1.1),
        3: FlexColumnWidth(1.15),
        4: FlexColumnWidth(1.25),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        verticalInside: BorderSide(color: Color(0xFF8FB4D9), width: 1),
      ),
      children: baris,
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

  Widget _kotakHadir({
    required String peran,
    required Map<String, dynamic> row,
  }) {
    final kunciGaji = _truk.any((r) => r['gaji_kunci'] == true);
    final kunci = row['nama_kunci']?.toString() ?? '';
    final nama = row['nama']?.toString() ?? kunci;
    final hadir = row['hadir'] == true;
    final boleh = _hariAbsen && !kunciGaji && !_proses && kunci.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Checkbox(
                value: hadir,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: boleh
                    ? (v) => _ubahHadir(peran, kunci, v ?? false)
                    : null,
              ),
            ),
          ),
          Text(nama, style: const TextStyle(fontSize: _teksIsi, height: 1)),
        ],
      ),
    );
  }

  Widget _grupAbsensi({
    required String judul,
    required String peran,
    required List<Map<String, dynamic>> orang,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          judul,
          style: const TextStyle(
            fontSize: _teksIsi,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        const SizedBox(width: 10),
        for (final row in orang) _kotakHadir(peran: peran, row: row),
      ],
    );
  }

  Widget _kartuAbsensiHari() {
    if (_pengirim.isEmpty && _gudang.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (_pengirim.isNotEmpty)
                _grupAbsensi(
                  judul: 'Pengirim',
                  peran: 'pengirim',
                  orang: _pengirim,
                ),
              if (_pengirim.isNotEmpty && _gudang.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 18,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              if (_gudang.isNotEmpty)
                _grupAbsensi(judul: 'Gudang', peran: 'gudang', orang: _gudang),
            ],
          ),
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
              _barisNilai('Total', total),
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

  Widget _kartuMutasiHari() {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _tabelMutasi(),
                      if (_mutasi.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                          child: Text(
                            'Belum ada mutasi.',
                            style: TextStyle(
                              fontSize: _teksIsi,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _tombolBiru(
                      label: 'Unggah mutasi CSV',
                      onPressed: _proses ? null : _unggahMutasi,
                      ikon: Icons.upload_file_outlined,
                      ukuranFont: _teksIsi,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _tombolBiru(
                      label: 'Hapus mutasi tanggal ini',
                      onPressed: _proses || _mutasi.isEmpty
                          ? null
                          : _hapusMutasi,
                      ukuranFont: _teksIsi,
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

  Widget _kartuOpnameHari() {
    final String judulStatus;
    final String detail;
    final Color warna;
    if (!_opnameAda) {
      judulStatus = 'Belum ada input';
      detail = 'Gudang belum mengirim opname untuk tanggal ini.';
      warna = Colors.grey.shade700;
    } else if (_opnameStatus == 'kunci') {
      if (_opnameSelisihSku == 0) {
        judulStatus = 'Dikunci · cocok';
        detail = 'Tidak ada selisih stok.';
        warna = Colors.green.shade700;
      } else {
        judulStatus = 'Dikunci · selisih';
        detail =
            '$_opnameSelisihSku SKU  ·  Rp ${formatUang(_opnameNilaiSelisih)}';
        warna = Colors.orange.shade800;
      }
    } else if (_opnameSelisihSku == 0) {
      judulStatus = 'Draft · cocok';
      detail = 'Tidak ada selisih stok.';
      warna = Colors.green.shade700;
    } else {
      judulStatus = 'Draft · selisih';
      detail =
          '$_opnameSelisihSku SKU  ·  Rp ${formatUang(_opnameNilaiSelisih)}';
      warna = Colors.orange.shade800;
    }
    return Card(
      margin: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tombolSetengahKiri(
                label: 'Cek opname',
                onPressed: _proses ? null : _cekOpname,
                ukuranFont: _teksIsi,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: InkWell(
                  onTap: _opnameBeda.isEmpty ? null : _dialogSelisihOpname,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        judulStatus,
                        style: TextStyle(
                          fontSize: _teksIsi,
                          fontWeight: FontWeight.bold,
                          color: warna,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: _teksIsi,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barisSupplierMasuk({
    required String nama,
    required int nilai,
    required double tinggi,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      height: tinggi,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _chipTombol(
                label: nama,
                onTap: onTap ?? () {},
                tinggi: (tinggi - 4).clamp(18.0, _tinggiBarisNilai),
                lebarPenuh: false,
                rataTengah: true,
                ukuranFont: _teksIsi,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatUang(nilai),
            style: const TextStyle(
              fontSize: _teksIsi,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartuBarangMasukHari({required double tinggiBarisSupplier}) {
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
      clipBehavior: Clip.antiAlias,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tombolSetengahKiri(
                label: 'Barang masuk',
                onPressed: _proses ? null : _dialogBarangMasuk,
                ukuranFont: _teksIsi,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: _barisSupplierTampil * tinggiBarisSupplier,
                child: urutan.isEmpty
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Belum ada data.',
                          style: TextStyle(
                            fontSize: _teksIsi,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: urutan.length > _barisSupplierTampil
                            ? const AlwaysScrollableScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        itemCount: urutan.length,
                        itemBuilder: (context, i) {
                          final id = urutan[i];
                          return _barisSupplierMasuk(
                            nama: namaSup[id] ?? 'Supplier',
                            nilai: grup[id]!.fold<int>(
                              0,
                              (a, m) => a + _angka(m['nilai']),
                            ),
                            tinggi: tinggiBarisSupplier,
                            onTap: () => _dialogItemMasukSupplier(
                              nama: namaSup[id] ?? 'Supplier',
                              items: grup[id]!,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: _tinggiTotalMasuk,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(
                          fontSize: _teksIsi,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      formatUang(total),
                      style: const TextStyle(
                        fontSize: _teksIsi,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kolomKananAtas({
    required double tinggiKartuMasuk,
    required double tinggiBarisSupplier,
  }) {
    return LayoutBuilder(
      builder: (context, batas) {
        const tetapTombol = _celahKartu;
        var hMasuk = tinggiKartuMasuk;
        final sisa = batas.maxHeight - tetapTombol;
        if (sisa.isFinite && sisa < hMasuk + 96) {
          hMasuk = (sisa - 96).clamp(96, hMasuk);
        }
        final hSupplier =
            ((hMasuk - 8 - _tinggiTombolAksi - 8 - 6 - _tinggiTotalMasuk - 10) /
                    _barisSupplierTampil)
                .clamp(18.0, tinggiBarisSupplier);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _kartuMutasiHari()),
            const SizedBox(height: _celahKartu),
            SizedBox(
              height: hMasuk,
              width: double.infinity,
              child: _kartuBarangMasukHari(tinggiBarisSupplier: hSupplier),
            ),
          ],
        );
      },
    );
  }

  Widget _kartuRuteSetoran({required double tinggiBaris}) {
    return SizedBox(
      height: _tinggiKartuSetoran(_rute.length, tinggiBaris),
      child: _kartuTabel(
        _truk.isEmpty
            ? Center(
                child: Text(
                  'Belum ada data. Pastikan admin_setoran.sql sudah dijalankan.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            : DataTable(
                headingRowHeight: _tinggiJudulSetoran,
                dataRowMinHeight: tinggiBaris,
                dataRowMaxHeight: tinggiBaris,
                dividerThickness: 0,
                columnSpacing: 16,
                horizontalMargin: 10,
                border: _garisKolom,
                columns: _judulSetoran,
                rows: _barisTrukSetoran(),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Menu',
          onPressed: widget.bukaMenu,
          icon: const Icon(Icons.menu),
        ),
        title: Row(
          children: [
            IconButton(
              tooltip: 'Pilih tanggal',
              onPressed: _pilihHari,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            Expanded(
              child: Text(_judulAppBar, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            tooltip: 'Simpan',
            onPressed: _muat || _proses ? null : _simpanHalaman,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Unduh',
            onPressed: _muat || _proses ? null : _unduhHalaman,
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Segarkan',
            onPressed: () => _muatData(layarPenuh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final adaAbsen = _pengirim.isNotEmpty || _gudang.isNotEmpty;
                final tinggiKartuAbsen = adaAbsen
                    ? 12 + _tinggiBarisAbsensi
                    : 0.0;
                final tinggiAbsen = adaAbsen
                    ? _celahKartu + tinggiKartuAbsen
                    : 0.0;
                final tinggiTersedia =
                    constraints.maxHeight - _padHalamanAtas - _padHalamanBawah;
                final tinggiBlok = (tinggiTersedia - tinggiAbsen).clamp(
                  240.0,
                  4000.0,
                );
                final cadanganKartu =
                    2 *
                    (_padKartuTabelAtas +
                        _padKartuTabelBawah +
                        _tinggiJudulSetoran);
                var tinggiBaris =
                    (tinggiBlok - _celahKartu - cadanganKartu) / 5;
                tinggiBaris = tinggiBaris.floorToDouble();
                if (tinggiBaris > _tinggiBarisSetoranMaks) {
                  tinggiBaris = _tinggiBarisSetoranMaks;
                }
                if (tinggiBaris < 104) tinggiBaris = 104;
                final tinggiRute = _tinggiKartuSetoran(
                  _rute.length,
                  tinggiBaris,
                );
                final tinggiJumlah = _tinggiKartuSetoran(1, tinggiBaris);
                var tinggiMasuk = _tinggiKartuMasukPenuh;
                const tetapKananTanpaMasuk =
                    _tinggiTombolAksi * 3 + _celahKartu * 4 + 80;
                final maksMasuk = tinggiRute - tetapKananTanpaMasuk;
                if (maksMasuk > 120 && tinggiMasuk > maksMasuk) {
                  tinggiMasuk = maksMasuk;
                }
                final tinggiBarisSupplier =
                    ((tinggiMasuk - 74) / _barisSupplierTampil).clamp(
                      18.0,
                      _tinggiBarisSupplier,
                    );
                final isi = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kartuRuteSetoran(tinggiBaris: tinggiBaris),
                        const SizedBox(width: _celahSampingKartu),
                        Expanded(
                          child: SizedBox(
                            height: tinggiRute,
                            width: double.infinity,
                            child: _kolomKananAtas(
                              tinggiKartuMasuk: tinggiMasuk,
                              tinggiBarisSupplier: tinggiBarisSupplier,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _celahKartu),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kartuJumlahSetoran(tinggiBaris: tinggiBaris),
                        const SizedBox(width: _celahSampingKartu),
                        Expanded(
                          child: SizedBox(
                            height: tinggiJumlah,
                            width: double.infinity,
                            child: _kartuOpnameHari(),
                          ),
                        ),
                      ],
                    ),
                    if (adaAbsen) ...[
                      const SizedBox(height: _celahKartu),
                      SizedBox(
                        height: tinggiKartuAbsen,
                        width: double.infinity,
                        child: _kartuAbsensiHari(),
                      ),
                    ],
                  ],
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    _padHalamanAtas,
                    16,
                    _padHalamanBawah,
                  ),
                  child: SizedBox(width: double.infinity, child: isi),
                );
              },
            ),
    );
  }
}

class _BarisCocokRetur {
  _BarisCocokRetur({required this.kode, required this.nama, int qty = 0})
    : qtyCtrl = TextEditingController(text: qty == 0 ? '' : formatUang(qty));

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
