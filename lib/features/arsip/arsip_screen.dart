import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_dialog.dart';
import '../../core/format_uang.dart';
import '../../core/gulir.dart';
import '../../core/network_probe.dart';
import '../../core/ui_feedback.dart';
import '../auth/login_screen.dart';

class ArsipScreen extends StatefulWidget {
  final AuthController auth;
  const ArsipScreen({super.key, required this.auth});

  @override
  State<ArsipScreen> createState() => _ArsipScreenState();
}

class _ArsipScreenState extends State<ArsipScreen> {
  final _sb = Supabase.instance.client;
  final _gulir = ScrollController();
  DateTime _hari = DateTime.now();
  bool _muat = true;
  bool _proses = false;
  bool _arsipKunci = false;
  bool _opnameKunci = false;
  List<Map<String, dynamic>> _retur = [];
  List<_BarisTambahan> _tambahan = [];

  String get _iso => DateFormat('yyyy-MM-dd').format(_hari);

  @override
  void initState() {
    super.initState();
    _hari = DateTime(_hari.year, _hari.month, _hari.day);
    _muatData();
  }

  @override
  void dispose() {
    _gulir.dispose();
    for (final t in _tambahan) {
      t.dispose();
    }
    super.dispose();
  }

  int _angka(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
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
    if (!await _adaNet()) {
      if (!mounted) return;
      if (layarPenuh) setState(() => _muat = false);
      return;
    }
    try {
      final arsip = await _sb.rpc('admin_arsip_lihat', params: {'p_tanggal': _iso});
      final retur = await _sb.rpc('admin_retur_lihat', params: {'p_tanggal': _iso});
      final tambahan = await _sb.rpc(
        'admin_tambahan_lihat',
        params: {'p_tanggal': _iso},
      );
      final opname = await _sb.rpc('admin_opname_lihat', params: {'p_tanggal': _iso});
      if (!mounted) return;
      final arsipRow = _daftar(arsip);
      final statusArsip = arsipRow.isEmpty
          ? 'draft'
          : (arsipRow.first['status']?.toString() ?? 'draft');
      for (final t in _tambahan) {
        t.dispose();
      }
      final opnameList = _daftar(opname);
      setState(() {
        _arsipKunci = statusArsip == 'kunci';
        _opnameKunci =
            opnameList.isNotEmpty &&
            opnameList.first['status_opname']?.toString() == 'kunci';
        _retur = _daftar(retur);
        _tambahan = _daftar(tambahan)
            .map(
              (r) => _BarisTambahan(
                kode: r['kode_barang']?.toString() ?? '',
                nama: r['nama_barang']?.toString() ?? '',
                qty: _angka(r['qty']),
              ),
            )
            .toList();
        _muat = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (layarPenuh) setState(() => _muat = false);
      showAppSnackBar(context, message: 'Gagal memuat arsip hari.');
    }
  }

  Future<void> _pilihHari() async {
    final pilih = await showDatePicker(
      context: context,
      initialDate: _hari,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pilih == null) return;
    setState(() => _hari = DateTime(pilih.year, pilih.month, pilih.day));
    await _muatData(layarPenuh: true);
  }

  Future<void> _kunciRetur(Map<String, dynamic> row) async {
    if (_arsipKunci || _proses) return;
    if (!await _adaNet()) return;
    if (!mounted) return;
    final rute = row['rute_pengirim']?.toString() ?? '';
    final qtyCtrl = TextEditingController(
      text: formatUang(_angka(row['qty_kunci'])),
    );
    final nilaiCtrl = TextEditingController(
      text: formatUang(_angka(row['nilai_kunci'])),
    );
    final catCtrl = TextEditingController(
      text: row['catatan_kunci']?.toString() ?? '',
    );
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text('Kunci retur $rute'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Usulan pengirim Rp ${formatUang(_angka(row['jumlah_usul']))}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: const [FormatRibuan()],
                decoration: const InputDecoration(labelText: 'Qty kunci'),
              ),
              TextField(
                controller: nilaiCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: const [FormatRibuan()],
                decoration: const InputDecoration(labelText: 'Nilai kunci'),
              ),
              TextField(
                controller: catCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Catatan'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kunci'),
          ),
        ],
      ),
    );
    final qty = angkaTeks(qtyCtrl.text);
    final nilai = angkaTeks(nilaiCtrl.text);
    final catatan = catCtrl.text.trim();
    qtyCtrl.dispose();
    nilaiCtrl.dispose();
    catCtrl.dispose();
    if (ya != true) return;
    setState(() => _proses = true);
    try {
      final ok = await _sb.rpc(
        'admin_retur_kunci',
        params: {
          'p_tanggal': _iso,
          'p_rute': rute,
          'p_qty': qty,
          'p_nilai': nilai,
          'p_catatan': catatan,
        },
      );
      if (!mounted) return;
      setState(() => _proses = false);
      if (ok == true) {
        showAppSnackBar(
          context,
          message: 'Retur $rute dikunci.',
          warna: AppSnackBarTone.hijau,
        );
        await _muatData();
      } else {
        showAppSnackBar(context, message: 'Gagal kunci retur.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _proses = false);
      showAppSnackBar(context, message: 'Gagal kunci retur.');
    }
  }

  Future<void> _simpanTambahan() async {
    if (_arsipKunci || _proses) return;
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      final ok = await _sb.rpc(
        'admin_tambahan_simpan',
        params: {
          'p_tanggal': _iso,
          'p_baris': _tambahan
              .where((t) => t.kode.trim().isNotEmpty && t.qty > 0)
              .map((t) => {'kode_barang': t.kode.trim(), 'qty': t.qty})
              .toList(),
        },
      );
      if (!mounted) return;
      setState(() => _proses = false);
      if (ok == true) {
        showAppSnackBar(
          context,
          message: 'TAMBAHAN disimpan.',
          warna: AppSnackBarTone.hijau,
        );
        await _muatData();
      } else {
        showAppSnackBar(context, message: 'Gagal simpan TAMBAHAN.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _proses = false);
      showAppSnackBar(context, message: 'Gagal simpan TAMBAHAN.');
    }
  }

  Future<void> _kunciArsip() async {
    if (_arsipKunci || _proses) return;
    if (!_opnameKunci) {
      showAppSnackBar(
        context,
        message: 'Kunci opname dulu, baru kunci arsip hari.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    if (!await _adaNet()) return;
    if (!mounted) return;
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: const Text('Kunci arsip hari'),
        content: Text(
          'Foto laporan $_iso dikunci. Tidak bisa diubah lagi. Lanjut?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kunci'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    setState(() => _proses = true);
    try {
      final ok = await _sb.rpc('admin_arsip_kunci', params: {'p_tanggal': _iso});
      if (!mounted) return;
      setState(() => _proses = false);
      if (ok == true) {
        showAppSnackBar(
          context,
          message: 'Arsip hari dikunci.',
          warna: AppSnackBarTone.hijau,
        );
        await _muatData();
      } else {
        showAppSnackBar(
          context,
          message: 'Gagal kunci arsip. Kunci opname dulu.',
          warna: AppSnackBarTone.kuning,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _proses = false);
      showAppSnackBar(context, message: 'Gagal kunci arsip.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final judul = DateFormat('EEEE d/MM/yyyy', 'id').format(_hari);
    return Scaffold(
      appBar: AppBar(
        title: Text('Arsip  $judul'),
        actions: [
          IconButton(
            tooltip: 'Pilih tanggal',
            onPressed: _pilihHari,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
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
          : GulirHalaman(
              controller: _gulir,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _arsipKunci
                        ? 'Arsip hari ini sudah dikunci (foto).'
                        : 'Usulan retur dikunci admin. TAMBAHAN pagi. Stok opname di Setoran. Lalu kunci arsip.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Retur (usulan pengirim)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ..._retur.map(_kartuRetur),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'TAMBAHAN (muat pagi)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (!_arsipKunci)
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _tambahan.add(_BarisTambahan()));
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Baris'),
                        ),
                    ],
                  ),
                  if (_tambahan.isEmpty)
                    Text(
                      'Belum ada TAMBAHAN.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ..._tambahan.asMap().entries.map((e) {
                      final i = e.key;
                      final t = e.value;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: t.kodeCtrl,
                                  enabled: !_arsipKunci,
                                  decoration: const InputDecoration(
                                    labelText: 'Kode barang',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: t.qtyCtrl,
                                  enabled: !_arsipKunci,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: const [FormatRibuan()],
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (!_arsipKunci)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      t.dispose();
                                      _tambahan.removeAt(i);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  if (!_arsipKunci)
                    FilledButton(
                      onPressed: _proses ? null : _simpanTambahan,
                      child: const Text('Simpan TAMBAHAN'),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Stok opname',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _opnameKunci
                        ? 'Opname tanggal ini sudah dikunci.'
                        : 'Isi fisik di aplikasi gudang. Cek selisih di Setoran, lalu kunci arsip di sini.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (_arsipKunci || _proses) ? null : _kunciArsip,
                      child: Text(
                        _arsipKunci ? 'Arsip sudah dikunci' : 'Kunci arsip hari',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _kartuRetur(Map<String, dynamic> row) {
    final rute = row['rute_pengirim']?.toString() ?? '';
    final kunci = row['sudah_kunci'] == true;
    return Card(
      child: ListTile(
        title: Text(
          rute,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${row['sudah_setor'] == true ? 'Sudah setor' : 'Belum setor'} · '
          'usulan Rp ${formatUang(_angka(row['jumlah_usul']))}'
          '${kunci ? ' · dikunci Rp ${formatUang(_angka(row['nilai_kunci']))}' : ''}',
        ),
        trailing: _arsipKunci
            ? const Icon(Icons.lock_outlined)
            : TextButton(
                onPressed: _proses ? null : () => _kunciRetur(row),
                child: Text(kunci ? 'Ubah' : 'Kunci'),
              ),
      ),
    );
  }
}

class _BarisTambahan {
  _BarisTambahan({String kode = '', this.nama = '', int qty = 0})
    : kodeCtrl = TextEditingController(text: kode),
      qtyCtrl = TextEditingController(text: qty == 0 ? '' : '$qty');

  final TextEditingController kodeCtrl;
  final TextEditingController qtyCtrl;
  final String nama;

  String get kode => kodeCtrl.text;
  int get qty => angkaTeks(qtyCtrl.text);

  void dispose() {
    kodeCtrl.dispose();
    qtyCtrl.dispose();
  }
}

