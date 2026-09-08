import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud_page.dart';
import '../../core/format_uang.dart';
import '../../core/gulir.dart';
import '../../core/network_probe.dart';
import '../../core/ui_feedback.dart';
import '../../core/unduh_berkas.dart';

class GajiScreen extends StatefulWidget {
  final DateTime acuan;

  const GajiScreen({
    super.key,
    required this.acuan,
  });

  @override
  State<GajiScreen> createState() => _GajiScreenState();
}

class _SalesGaji {
  _SalesGaji({
    required this.namaKunci,
    required this.nama,
    required this.rute,
    required this.targetOmset,
    required this.targetPersenLaba,
  });

  final String namaKunci;
  final String nama;
  final String rute;
  final int targetOmset;
  final double targetPersenLaba;

  int get targetLaba {
    if (targetOmset <= 0 || targetPersenLaba <= 0) return 0;
    return (targetOmset * targetPersenLaba / (100 + targetPersenLaba)).round();
  }
}

class _TokoVisit {
  final String rute;
  const _TokoVisit({required this.rute});
}

class _BarisSales {
  _BarisSales({required this.sales});

  final _SalesGaji sales;
  int omsetOrder = 0;
  int omsetPacked = 0;
  int omsetActual = 0;
  int labaOrder = 0;
  int labaPacked = 0;
  int labaActual = 0;
  final Set<String> ecOrder = {};
  final Set<String> ecPacked = {};
  final Set<String> ecActual = {};
  int visit = 0;
  int targetToko = 1;
  int labaBersih = 0;
  int targetLabaBersih = 0;

  int get targetEc {
    final n = (targetToko * 0.8).round();
    return n < 1 ? 1 : n;
  }

  double get scanPct => visit / targetToko * 100;
  double get ecOrderPct => ecOrder.length / targetEc * 100;
  double get ecPackedPct => ecPacked.length / targetEc * 100;
  double get ecActualPct => ecActual.length / targetEc * 100;

  double get omsetOrderPct =>
      sales.targetOmset <= 0 ? 0 : omsetOrder / sales.targetOmset * 100;
  double get omsetPackedPct =>
      sales.targetOmset <= 0 ? 0 : omsetPacked / sales.targetOmset * 100;
  double get omsetActualPct =>
      sales.targetOmset <= 0 ? 0 : omsetActual / sales.targetOmset * 100;

  double _profit(int omset, int laba) {
    if (omset <= 0 || laba >= omset) return 0;
    return laba / (omset - laba) * 100;
  }

  double get profitOrder => _profit(omsetOrder, labaOrder);
  double get profitPacked => _profit(omsetPacked, labaPacked);
  double get profitActual => _profit(omsetActual, labaActual);

  double _profitCapaian(double profit) {
    if (sales.targetPersenLaba <= 0) return 0;
    return profit / sales.targetPersenLaba * 100;
  }

  double get profitOrderCapaian => _profitCapaian(profitOrder);
  double get profitPackedCapaian => _profitCapaian(profitPacked);
  double get profitActualCapaian => _profitCapaian(profitActual);

  double _rata4(double ec, double omset, double profit) =>
      (scanPct + ec + omset + profit) / 4;

  double get poinOrder =>
      _rata4(ecOrderPct, omsetOrderPct, profitOrderCapaian);
  double get poinPacked =>
      _rata4(ecPackedPct, omsetPackedPct, profitPackedCapaian);
  double get poinActual =>
      _rata4(ecActualPct, omsetActualPct, profitActualCapaian);
}

class _GajiScreenState extends State<GajiScreen> {
  static const _gaya = TextStyle(fontSize: 11, height: 1.2);
  static const _gayaJudul = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  final _sb = Supabase.instance.client;
  final _gulir = ScrollController();
  final _simSelisihCtrl = TextEditingController(text: '0');
  final _simOngkirCtrl = TextEditingController(text: '0');
  final _simBopCtrl = TextEditingController(text: '0');

  bool _muat = true;
  bool _proses = false;
  String _status = 'draft';
  String? _error;
  List<_SalesGaji> _sales = [];

  late DateTime _senin;

  List<_TokoVisit> _toko = [];
  List<Map<String, dynamic>> _notaMinggu = [];
  List<Map<String, dynamic>> _kunjunganMinggu = [];
  int _ongkirMinggu = 0;
  int _selisihMinggu = 0;
  Map<String, int> _bopRute = {};
  Map<String, int> _returRute = {};

  DateTime get _sabtu => _senin.add(const Duration(days: 5));

  String get _isoSenin => DateFormat('yyyy-MM-dd').format(_senin);

  String get _judulMinggu =>
      '${DateFormat('d/MM/yyyy').format(_senin)} – ${DateFormat('d/MM/yyyy').format(_sabtu)}';

  String get _kunciSimulasi => 'gaji_simulasi_$_isoSenin';

  bool _isiSimulasi = false;

  Future<void> _muatSimulasiLaluData() async {
    await _muatSimulasi();
    await _muatData();
  }

  Future<void> _muatSimulasi() async {
    final p = await SharedPreferences.getInstance();
    final mentah = p.getString(_kunciSimulasi);
    _isiSimulasi = true;
    if (mentah == null || mentah.isEmpty) {
      _simSelisihCtrl.text = '0';
      _simOngkirCtrl.text = '0';
      _simBopCtrl.text = '0';
    } else {
      final bagian = mentah.split(';');
      _simSelisihCtrl.text = formatUang(
        angkaTeks(bagian.isNotEmpty ? bagian[0] : '0'),
      );
      _simOngkirCtrl.text = formatUang(
        angkaTeks(bagian.length > 1 ? bagian[1] : '0'),
      );
      _simBopCtrl.text = formatUang(
        angkaTeks(bagian.length > 2 ? bagian[2] : '0'),
      );
    }
    _isiSimulasi = false;
  }

  void _onSimulasiBerubah() {
    if (_isiSimulasi) return;
    SharedPreferences.getInstance().then((p) {
      p.setString(
        _kunciSimulasi,
        '${angkaTeks(_simSelisihCtrl.text)};'
        '${angkaTeks(_simOngkirCtrl.text)};'
        '${angkaTeks(_simBopCtrl.text)}',
      );
    });
    if (mounted) setState(() {});
  }

  int get _simSelisih => angkaTeks(_simSelisihCtrl.text);
  int get _simOngkir => angkaTeks(_simOngkirCtrl.text);
  int get _simBop => angkaTeks(_simBopCtrl.text);

  @override
  void initState() {
    super.initState();
    final h = DateTime(widget.acuan.year, widget.acuan.month, widget.acuan.day);
    _senin = h.subtract(Duration(days: h.weekday - 1));
    _simSelisihCtrl.addListener(_onSimulasiBerubah);
    _simOngkirCtrl.addListener(_onSimulasiBerubah);
    _simBopCtrl.addListener(_onSimulasiBerubah);
    _muatSimulasiLaluData();
  }

  @override
  void dispose() {
    _simSelisihCtrl.removeListener(_onSimulasiBerubah);
    _simOngkirCtrl.removeListener(_onSimulasiBerubah);
    _simBopCtrl.removeListener(_onSimulasiBerubah);
    _simSelisihCtrl.dispose();
    _simOngkirCtrl.dispose();
    _simBopCtrl.dispose();
    _gulir.dispose();
    super.dispose();
  }

  Map<String, dynamic> _peta(dynamic row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) return Map<String, dynamic>.from(row);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _daftar(dynamic v) {
    if (v is! List) return const [];
    return v.map(_peta).toList();
  }

  int _angka(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _desimal(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v?.toString() ?? '').replaceAll(',', '.')) ?? 0;
  }

  String? _rutePengirimDariSales(String ruteSales) {
    final m = RegExp(r'^SBGS(\d+)$').firstMatch(ruteSales.toUpperCase());
    if (m == null) return null;
    final n = int.tryParse(m.group(1) ?? '') ?? 0;
    if (n < 1) return null;
    final lebar = m.group(1)!.length < 2 ? 2 : m.group(1)!.length;
    return 'SBGP${((n + 1) ~/ 2).toString().padLeft(lebar, '0')}';
  }

  void _hitungLabaBersih(List<_BarisSales> list) {
    final labaAll = list.fold<int>(0, (a, b) => a + b.labaActual);
    final eNilai = <_BarisSales, int>{};
    for (final b in list) {
      final bagianSelisih =
          labaAll == 0 ? 0 : (_selisihMinggu * b.labaActual / labaAll).round();
      final bagianOngkir =
          labaAll == 0 ? 0 : (_ongkirMinggu * b.labaActual / labaAll).round();
      eNilai[b] = b.labaActual - bagianSelisih - bagianOngkir;
    }
    final byPas = <String, List<_BarisSales>>{};
    for (final b in list) {
      final p = _rutePengirimDariSales(b.sales.rute);
      if (p == null) {
        b.labaBersih = eNilai[b] ?? b.labaActual;
        continue;
      }
      byPas.putIfAbsent(p, () => []).add(b);
    }
    for (final e in byPas.entries) {
      final pasangan = e.value;
      final bopPas = _bopRute[e.key] ?? 0;
      final returPas = _returRute[e.key] ?? 0;
      var eAll = 0;
      for (final b in pasangan) {
        eAll += eNilai[b] ?? 0;
      }
      for (final b in pasangan) {
        final ev = eNilai[b] ?? 0;
        final bagianBop = eAll == 0
            ? (bopPas / pasangan.length).round()
            : (bopPas * ev / eAll).round();
        final bagianRetur = eAll == 0
            ? (returPas / pasangan.length).round()
            : (returPas * ev / eAll).round();
        b.labaBersih = ev - bagianBop - bagianRetur;
      }
    }
    _hitungTargetLabaBersih(list);
  }

  void _hitungTargetLabaBersih(List<_BarisSales> list) {
    final tot = list.fold<int>(0, (a, b) => a + b.sales.targetLaba);
    for (final b in list) {
      final target = b.sales.targetLaba;
      final bagianSelisih =
          tot == 0 ? 0 : (_simSelisih * target / tot).round();
      final bagianOngkir = tot == 0 ? 0 : (_simOngkir * target / tot).round();
      final bagianBop = tot == 0 ? 0 : (_simBop * target / tot).round();
      b.targetLabaBersih = target - bagianSelisih - bagianOngkir - bagianBop;
    }
  }

  List<_BarisSales> get _baris {
    final list = <_BarisSales>[];
    final byRute = <String, _BarisSales>{};
    for (final s in _sales) {
      final b = _BarisSales(sales: s);
      var toko = 0;
      for (final t in _toko) {
        if (t.rute.trim().toUpperCase() == s.rute) toko++;
      }
      b.targetToko = toko < 1 ? 1 : toko;
      list.add(b);
      if (s.rute.isNotEmpty) byRute[s.rute] = b;
    }
    for (final row in _notaMinggu) {
      final rute = (row['rute']?.toString() ?? '').trim().toUpperCase();
      final b = byRute[rute];
      if (b == null) continue;
      if ((row['status']?.toString() ?? '') == 'batal') continue;
      b.omsetOrder += _angka(row['total_pembayaran']);
      b.labaOrder += _angka(row['laba_kotor']);
      b.omsetPacked += _angka(row['total_pembayaran_terkirim']);
      b.labaPacked += _angka(row['laba_kotor_terkirim']);
      b.omsetActual += _angka(row['total_pembayaran_actual']);
      b.labaActual += _angka(row['laba_kotor_actual']);
      final kode = row['kode_pelanggan']?.toString() ?? '';
      if (kode.isEmpty) continue;
      b.ecOrder.add(kode);
      if (_angka(row['total_pembayaran_terkirim']) != 0) b.ecPacked.add(kode);
      if (row['status']?.toString() == 'terkirim') b.ecActual.add(kode);
    }
    final unik = <String, Set<String>>{};
    for (final row in _kunjunganMinggu) {
      final rute = (row['rute']?.toString() ?? '').trim().toUpperCase();
      if (!byRute.containsKey(rute)) continue;
      final kode = row['kode_pelanggan']?.toString() ?? '';
      if (kode.isEmpty) continue;
      unik.putIfAbsent(rute, () => {}).add(kode);
    }
    for (final e in unik.entries) {
      byRute[e.key]!.visit = e.value.length;
    }
    _hitungLabaBersih(list);
    return list;
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

  Future<void> _muatData() async {
    if (!await NetworkProbe.hasConnection()) {
      if (!mounted) return;
      setState(() {
        _muat = false;
        _error = 'Tidak ada internet.';
      });
      return;
    }
    setState(() {
      _muat = true;
      _error = null;
    });
    try {
      final mentah = await _sb.rpc(
        'gaji_lihat_minggu',
        params: {'p_tanggal': _isoSenin},
      );
      final data = _peta(mentah);
      if (data['ok'] != true) {
        throw StateError(data['pesan']?.toString() ?? 'RPC ditolak');
      }

      final sales = <_SalesGaji>[];
      try {
        final kary = _peta(await _sb.rpc('gaji_karyawan_lihat'));
        for (final row in _daftar(kary['data'])) {
          if ((row['peran']?.toString() ?? '') != 'sales') continue;
          if (row['aktif'] == false) continue;
          sales.add(
            _SalesGaji(
              namaKunci: row['nama_kunci']?.toString() ?? '',
              nama: row['nama']?.toString() ?? '',
              rute: (row['rute_sales']?.toString() ?? '').trim().toUpperCase(),
              targetOmset: _angka(row['target_omset']),
              targetPersenLaba: _desimal(row['target_profit_pct']),
            ),
          );
        }
      } catch (_) {}

      final isoSabtu = DateFormat('yyyy-MM-dd').format(_sabtu);
      final hariIso = [
        for (var i = 0; i < 6; i++)
          DateFormat('yyyy-MM-dd').format(_senin.add(Duration(days: i))),
      ];
      final daftarTunggu = <Future<dynamic>>[
        CloudPage.unduhHalaman(
          ukuran: CloudPage.ukuranRentang,
          batas: CloudPage.batasTokoRute,
          ambil: (from, to) => _sb
              .from('rsl')
              .select('kode_pelanggan, rute, visit')
              .range(from, to),
        ),
        CloudPage.unduhHalaman(
          ambil: (from, to) => _sb
              .from('orders')
              .select(
                'rute, status, kode_pelanggan, total_pembayaran, laba_kotor, '
                'total_pembayaran_terkirim, laba_kotor_terkirim, '
                'total_pembayaran_actual, laba_kotor_actual',
              )
              .gte('tanggal_order', '$_isoSenin 00:00:00')
              .lte('tanggal_order', '$isoSabtu 23:59:59')
              .range(from, to),
        ),
        CloudPage.unduhHalaman(
          batas: CloudPage.batasKunjungan,
          ambil: (from, to) => _sb
              .from('kunjungan')
              .select('kode_pelanggan, rute')
              .gte('tanggal_kunjungan', _isoSenin)
              .lte('tanggal_kunjungan', isoSabtu)
              .range(from, to),
        ),
        for (final d in hariIso)
          _sb.rpc('admin_setoran_hari', params: {'p_tanggal': d}),
      ];
      final hasil = await Future.wait(daftarTunggu);

      final toko = <_TokoVisit>[];
      for (final row in _daftar(hasil[0])) {
        if ((row['kode_pelanggan']?.toString() ?? '').isEmpty) continue;
        toko.add(_TokoVisit(rute: row['rute']?.toString() ?? ''));
      }

      var selisih = 0;
      try {
        final row = await _sb
            .from('biaya_mingguan')
            .select('selisih_barang')
            .eq('tanggal_mulai', _isoSenin)
            .maybeSingle();
        if (row != null) selisih = _angka(row['selisih_barang']);
      } catch (_) {}

      final bopRute = <String, int>{};
      final returRute = <String, int>{};
      for (var i = 3; i < hasil.length; i++) {
        for (final row in _daftar(hasil[i])) {
          final rute =
              (row['rute_pengirim']?.toString() ?? '').trim().toUpperCase();
          if (rute.isEmpty) continue;
          bopRute[rute] = (bopRute[rute] ?? 0) + _angka(row['bop']);
          returRute[rute] =
              (returRute[rute] ?? 0) + _angka(row['retur']);
        }
      }

      if (!mounted) return;
      setState(() {
        _status = data['status']?.toString() ?? 'draft';
        _sales = sales;
        _toko = toko;
        _notaMinggu = _daftar(hasil[1]);
        _kunjunganMinggu = _daftar(hasil[2]);
        _ongkirMinggu = _angka(data['ongkir_belanja']);
        _selisihMinggu = selisih;
        _bopRute = bopRute;
        _returRute = returRute;
        _muat = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _muat = false;
        _error =
            'Gagal memuat gaji salesman. Jalankan ulang supabase/gaji.sql, lalu segarkan.';
      });
    }
  }

  Future<void> _pilihMinggu() async {
    final pilih = await showDatePicker(
      context: context,
      initialDate: _senin,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 14)),
      helpText: 'Pilih tanggal di minggu gaji',
    );
    if (pilih == null) return;
    final hari = DateTime(pilih.year, pilih.month, pilih.day);
    setState(() {
      _senin = hari.subtract(Duration(days: hari.weekday - 1));
    });
    await _muatSimulasiLaluData();
  }

  String _selCsv(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(RegExp(r'[;"\n\r]'))) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _pctTeks(double n) =>
      '${n.toStringAsFixed(2).replaceAll('.', ',')}%';

  String _persenTeks(double n) => n.toStringAsFixed(2).replaceAll('.', ',');

  void _unduh() {
    final isi = <String>[
      'Nama;Rute;Target laba bersih;Laba bersih;Omset Target;Omset Order;Omset Packed;Omset Actual;'
          'Scan %;EC Order %;EC Packed %;EC Actual %;'
          'Profit Target %;Profit Order %;Profit Packed %;Profit Actual %',
    ];
    for (final b in _baris) {
      isi.add(
        [
          b.sales.nama,
          b.sales.rute,
          b.targetLabaBersih,
          b.labaBersih,
          b.sales.targetOmset,
          b.omsetOrder,
          b.omsetPacked,
          b.omsetActual,
          _pctTeks(b.scanPct),
          _pctTeks(b.ecOrderPct),
          _pctTeks(b.ecPackedPct),
          _pctTeks(b.ecActualPct),
          _persenTeks(b.sales.targetPersenLaba),
          _persenTeks(b.profitOrder),
          _persenTeks(b.profitPacked),
          _persenTeks(b.profitActual),
        ].map(_selCsv).join(';'),
      );
    }
    unduhCsv(nama: 'gaji_sales_$_isoSenin.csv', isi: isi.join('\n'));
  }

  Future<void> _jalankan(String rpc, String sukses) async {
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      final ok = await _sb.rpc(rpc, params: {'p_tanggal': _isoSenin});
      if (!mounted) return;
      if (ok == true || (ok is int && ok >= 0 && rpc.contains('kasbon'))) {
        showAppSnackBar(
          context,
          message: sukses,
          warna: AppSnackBarTone.hijau,
        );
        await _muatData();
      } else {
        showAppSnackBar(
          context,
          message: 'Perintah ditolak. Periode mungkin sudah dikunci.',
          warna: AppSnackBarTone.kuning,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, message: 'Gagal menjalankan perintah.');
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Color? _warnaPct(double n, {double ambang = 80}) {
    if (n < ambang) return const Color(0xFFC62828);
    return null;
  }

  Color? _warnaSelisih(num n) {
    if (n < 0) return const Color(0xFFC62828);
    return null;
  }

  Widget _sel(
    String teks, {
    Color? warna,
    bool tebal = false,
    bool kanan = true,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFB0BEC5), width: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        teks,
        textAlign: kanan ? TextAlign.right : TextAlign.left,
        style: _gaya.copyWith(
          color: warna,
          fontWeight: tebal ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _kepalaGabung(String teks) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFB0BEC5), width: 0.6),
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          teks,
          textAlign: TextAlign.center,
          style: _gayaJudul,
        ),
      ),
    );
  }

  Widget _kepalaBertingkat({String grup = '', required String sub}) {
    return TableCell(
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFB0BEC5), width: 0.6),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              width: double.infinity,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: Text(
                grup,
                textAlign: TextAlign.center,
                style: _gayaJudul,
              ),
            ),
            const Divider(
              height: 1,
              thickness: 0.6,
              color: Color(0xFFB0BEC5),
            ),
            Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.center,
              child: Text(
                sub,
                textAlign: TextAlign.center,
                style: _gayaJudul,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _isianSimulasi({
    required String label,
    required TextEditingController ctrl,
  }) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: const [FormatRibuan()],
        decoration: InputDecoration(
          labelText: label,
          prefixText: 'Rp ',
          isDense: true,
        ),
      ),
    );
  }

  Widget _kartuSimulasi() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulasi target laba bersih',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Dibagi ke salesman menurut porsi target laba. '
              'Target laba bersih = target laba − selisih − ongkir − BOP.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _isianSimulasi(
                  label: 'Selisih barang',
                  ctrl: _simSelisihCtrl,
                ),
                _isianSimulasi(
                  label: 'Ongkir barang',
                  ctrl: _simOngkirCtrl,
                ),
                _isianSimulasi(
                  label: 'BOP',
                  ctrl: _simBopCtrl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabel() {
    final data = _baris;
    const garis = BorderSide(color: Color(0xFFB0BEC5), width: 0.6);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.2,
        ),
      ),
      child: GulirMendatar(
        induk: _gulir,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            top: garis,
            left: garis,
            right: garis,
            bottom: garis,
            verticalInside: garis,
          ),
          children: [
            TableRow(
              children: [
                _kepalaGabung('Nama'),
                _kepalaGabung('Target laba bersih'),
                _kepalaGabung('Laba bersih'),
                _kepalaBertingkat(grup: 'OMSET', sub: 'Target'),
                _kepalaBertingkat(sub: 'Order'),
                _kepalaBertingkat(sub: 'Packed'),
                _kepalaBertingkat(sub: 'Actual'),
                _kepalaBertingkat(sub: '% Actual'),
                _kepalaBertingkat(sub: 'Selisih'),
                _kepalaBertingkat(grup: 'SCAN', sub: '%'),
                _kepalaBertingkat(grup: 'EC', sub: 'Order %'),
                _kepalaBertingkat(sub: 'Packed %'),
                _kepalaBertingkat(sub: 'Actual %'),
                _kepalaBertingkat(grup: '% PROFIT', sub: 'Target'),
                _kepalaBertingkat(sub: 'Order'),
                _kepalaBertingkat(sub: 'Packed'),
                _kepalaBertingkat(sub: 'Actual'),
                _kepalaBertingkat(sub: '% Actual'),
                _kepalaBertingkat(grup: '4 POIN', sub: 'Order'),
                _kepalaBertingkat(sub: 'Packed'),
                _kepalaBertingkat(sub: 'Actual'),
              ],
            ),
            for (final b in data)
              TableRow(
                children: [
                  _sel(b.sales.nama, kanan: false, tebal: true),
                  _sel(
                    formatUang(b.targetLabaBersih),
                    warna: _warnaSelisih(b.targetLabaBersih),
                    tebal: true,
                  ),
                  _sel(
                    formatUang(b.labaBersih),
                    warna: _warnaSelisih(b.labaBersih),
                    tebal: true,
                  ),
                  _sel(formatUang(b.sales.targetOmset)),
                  _sel(formatUang(b.omsetOrder)),
                  _sel(formatUang(b.omsetPacked)),
                  _sel(formatUang(b.omsetActual)),
                  _sel(
                    _pctTeks(b.omsetActualPct),
                    warna: _warnaPct(b.omsetActualPct),
                  ),
                  _sel(
                    formatUang(b.omsetActual - b.sales.targetOmset),
                    warna: _warnaSelisih(b.omsetActual - b.sales.targetOmset),
                  ),
                  _sel(_pctTeks(b.scanPct), warna: _warnaPct(b.scanPct, ambang: 90)),
                  _sel(_pctTeks(b.ecOrderPct), warna: _warnaPct(b.ecOrderPct)),
                  _sel(_pctTeks(b.ecPackedPct), warna: _warnaPct(b.ecPackedPct)),
                  _sel(_pctTeks(b.ecActualPct), warna: _warnaPct(b.ecActualPct)),
                  _sel(_persenTeks(b.sales.targetPersenLaba)),
                  _sel(_persenTeks(b.profitOrder)),
                  _sel(_persenTeks(b.profitPacked)),
                  _sel(_persenTeks(b.profitActual)),
                  _sel(
                    _pctTeks(b.profitActualCapaian),
                    warna: _warnaPct(b.profitActualCapaian),
                  ),
                  _sel(_pctTeks(b.poinOrder), warna: _warnaPct(b.poinOrder)),
                  _sel(_pctTeks(b.poinPacked), warna: _warnaPct(b.poinPacked)),
                  _sel(_pctTeks(b.poinActual), warna: _warnaPct(b.poinActual)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final terkunci = _status == 'kunci';
    return Scaffold(
      appBar: AppBar(
        title: Text('Gaji salesman  ·  $_judulMinggu  ·  $_status'),
        actions: [
          IconButton(
            tooltip: 'Pilih minggu',
            onPressed: _muat || _proses ? null : _pilihMinggu,
            icon: const Icon(Icons.date_range_outlined),
          ),
          IconButton(
            tooltip: 'Segarkan',
            onPressed: _muat || _proses ? null : _muatData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Unduh',
            onPressed: _muat || _proses || _sales.isEmpty ? null : _unduh,
            icon: const Icon(Icons.download_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Perintah gaji',
            enabled: !_muat && !_proses,
            onSelected: (v) {
              switch (v) {
                case 'kasbon':
                  _jalankan(
                    'gaji_sinkron_kasbon_setoran',
                    'Kasbon setoran disalin.',
                  );
                case 'generate':
                  _jalankan(
                    'gaji_generate_slip',
                    'Slip gaji dihitung dan dikunci.',
                  );
                case 'buka':
                  _jalankan(
                    'gaji_buka_kunci_periode',
                    'Periode dibuka lagi.',
                  );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'kasbon',
                child: Text('Sinkron kasbon'),
              ),
              PopupMenuItem(
                value: 'generate',
                enabled: !terkunci,
                child: const Text('Generate slip'),
              ),
              PopupMenuItem(
                value: 'buka',
                enabled: terkunci,
                child: const Text('Buka kunci'),
              ),
            ],
          ),
        ],
      ),
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : GulirHalaman(
              controller: _gulir,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFB71C1C)),
                      ),
                    ),
                  _kartuSimulasi(),
                  const SizedBox(height: 12),
                  if (_sales.isEmpty)
                    Text(
                      'Belum ada salesman di data karyawan.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    _tabel(),
                ],
              ),
            ),
    );
  }
}
