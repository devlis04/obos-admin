import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/format_uang.dart';
import '../../core/gulir.dart';
import '../../core/network_probe.dart';
import '../../core/ui_feedback.dart';
import '../auth/login_screen.dart';

class GajiScreen extends StatefulWidget {
  final AuthController auth;
  const GajiScreen({super.key, required this.auth});

  @override
  State<GajiScreen> createState() => _GajiScreenState();
}

class _GajiScreenState extends State<GajiScreen> {
  final _sb = Supabase.instance.client;
  final _gulir = ScrollController();
  final _ongkirCtrl = TextEditingController(text: '0');
  DateTime _acuan = DateTime.now();
  bool _muat = true;
  bool _proses = false;
  String _status = '-';
  String? _error;
  List<Map<String, dynamic>> _slip = [];

  DateTime get _senin {
    final h = DateTime(_acuan.year, _acuan.month, _acuan.day);
    return h.subtract(Duration(days: h.weekday - 1));
  }

  DateTime get _sabtu => _senin.add(const Duration(days: 5));

  String get _isoSenin => DateFormat('yyyy-MM-dd').format(_senin);

  Map<String, dynamic> _peta(dynamic row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) return Map<String, dynamic>.from(row);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _daftar(dynamic v) {
    if (v is! List) return const [];
    return v.map(_peta).toList();
  }

  String _rpAtauStrip(dynamic n, {required bool ada}) {
    if (!ada) return '—';
    return 'Rp ${formatUang(angkaTeks(n?.toString() ?? '0'))}';
  }

  String _labelPeran(Map<String, dynamic> s) {
    final peran = s['peran']?.toString() ?? '';
    final rute = s['rute']?.toString() ?? '';
    final kursi = s['peran_kirim']?.toString() ?? '';
    if (rute.isEmpty) return peran;
    if (kursi.isEmpty) return '$peran · $rute';
    return '$peran · $rute $kursi';
  }

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  @override
  void dispose() {
    _gulir.dispose();
    _ongkirCtrl.dispose();
    super.dispose();
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
    if (layarPenuh && mounted) {
      setState(() {
        _muat = true;
        _error = null;
      });
    }
    if (!await NetworkProbe.hasConnection()) {
      if (!mounted) return;
      if (layarPenuh) {
        setState(() {
          _muat = false;
          _error = 'Tidak ada internet.';
        });
      }
      showAppSnackBar(
        context,
        message: 'Tidak ada internet. Data gaji tidak diunduh.',
        warna: AppSnackBarTone.kuning,
      );
      return;
    }
    try {
      final mentah = await _sb.rpc(
        'gaji_lihat_minggu',
        params: {'p_tanggal': _isoSenin},
      );
      final data = _peta(mentah);
      if (data['ok'] != true) {
        throw StateError(data['pesan']?.toString() ?? 'RPC ditolak');
      }
      if (!mounted) return;
      _ongkirCtrl.text = formatUang(
        angkaTeks((data['ongkir_belanja'] ?? 0).toString()),
      );
      setState(() {
        _status = data['status']?.toString() ?? 'draft';
        _slip = _daftar(data['slip']);
        _muat = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      if (layarPenuh) {
        setState(() {
          _muat = false;
          _error =
              'Gagal memuat gaji. Jalankan ulang supabase/gaji.sql di Supabase, lalu segarkan.';
          _slip = [];
        });
      } else {
        showAppSnackBar(
          context,
          message: 'Gagal memuat gaji.',
        );
      }
    }
  }

  Future<void> _pilihMinggu() async {
    final pilih = await showDatePicker(
      context: context,
      initialDate: _acuan,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (pilih == null) return;
    setState(() => _acuan = pilih);
    await _muatData(layarPenuh: true);
  }

  Future<void> _simpanOngkir() async {
    if (!await _adaNet()) return;
    setState(() => _proses = true);
    try {
      final ok = await _sb.rpc(
        'gaji_set_ongkir_belanja',
        params: {
          'p_tanggal': _isoSenin,
          'p_ongkir': angkaTeks(_ongkirCtrl.text),
        },
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: ok == true
            ? 'Ongkir belanja disimpan.'
            : 'Ongkir gagal disimpan. Periode mungkin sudah dikunci.',
        warna: ok == true ? AppSnackBarTone.hijau : AppSnackBarTone.kuning,
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, message: 'Gagal menyimpan ongkir belanja.');
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
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
        showAppSnackBar(context, message: 'Gagal menjalankan $rpc.');
      }
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final judul =
        '${DateFormat('d/MM/yyyy').format(_senin)} – ${DateFormat('d/MM/yyyy').format(_sabtu)}';
    return Scaffold(
      appBar: AppBar(
        title: Text('Gaji  $judul'),
        actions: [
          IconButton(
            tooltip: 'Pilih minggu',
            onPressed: _pilihMinggu,
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
                  'Halo, ${widget.auth.nama}  ·  periode $_status',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFB71C1C)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Gaji karyawan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  _slip.any((s) => s['ada_slip'] == true)
                      ? 'Angka dibayar dari generate slip minggu ini.'
                      : 'Nama sudah tampil. Tekan Generate slip setelah ongkir diisi.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (_slip.isEmpty)
                  Text(
                    'Master karyawan kosong. Jalankan gaji.sql.',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: GulirMendatar(
                        induk: _gulir,
                        child: DataTable(
                      headingRowHeight: 36,
                      columns: const [
                        DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text('Nama'),
                        ),
                        DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text('Peran'),
                        ),
                        DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text('Hak'),
                        ),
                        DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text('Kasbon'),
                        ),
                        DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text('Dibayar'),
                        ),
                        DataColumn(
                          headingRowAlignment: MainAxisAlignment.center,
                          label: Text('Hari'),
                        ),
                      ],
                      rows: _slip.map((s) {
                        final ada = s['ada_slip'] == true;
                        return DataRow(
                          cells: [
                            DataCell(Text('${s['nama'] ?? ''}')),
                            DataCell(Text(_labelPeran(s))),
                            DataCell(
                              Text(_rpAtauStrip(s['total_insentif'], ada: ada)),
                            ),
                            DataCell(
                              Text(
                                'Rp ${formatUang(angkaTeks((s['kasbon'] ?? 0).toString()))}',
                              ),
                            ),
                            DataCell(Text(_rpAtauStrip(s['dibayar'], ada: ada))),
                            DataCell(
                              Text(ada ? '${s['hari_kerja'] ?? 0}' : '—'),
                            ),
                          ],
                        );
                      }).toList(),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                TextField(
                  controller: _ongkirCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_FormatRibuan()],
                  enabled: _status != 'kunci' && !_proses,
                  decoration: const InputDecoration(
                    labelText: 'Ongkir belanja (manual)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _status == 'kunci' || _proses
                        ? null
                        : _simpanOngkir,
                    child: const Text('Simpan ongkir belanja'),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _proses
                          ? null
                          : () => _jalankan(
                              'gaji_sinkron_kasbon_setoran',
                              'Kasbon setoran disalin.',
                            ),
                      child: const Text('Sinkron kasbon setoran'),
                    ),
                    FilledButton(
                      onPressed: _proses || _status == 'kunci'
                          ? null
                          : () => _jalankan(
                              'gaji_generate_slip',
                              'Slip gaji dihitung dan dikunci.',
                            ),
                      child: const Text('Generate slip'),
                    ),
                    OutlinedButton(
                      onPressed: _proses || _status != 'kunci'
                          ? null
                          : () => _jalankan(
                              'gaji_buka_kunci_periode',
                              'Periode dibuka lagi.',
                            ),
                      child: const Text('Buka kunci'),
                    ),
                  ],
                ),
              ],
              ),
            ),
    );
  }
}

class _FormatRibuan extends TextInputFormatter {
  const _FormatRibuan();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    final teks = formatUang(int.parse(digits));
    return TextEditingValue(
      text: teks,
      selection: TextSelection.collapsed(offset: teks.length),
    );
  }
}
