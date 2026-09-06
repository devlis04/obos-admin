import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_dialog.dart';
import '../../core/format_uang.dart';
import '../../core/network_probe.dart';
import '../../core/ui_feedback.dart';
import '../../core/unduh_berkas.dart';

/// Dialog gaji minggu (Senin–Sabtu) dari tanggal acuan halaman Setoran.
Future<bool> bukaDialogGaji(BuildContext context, {required DateTime acuan}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _DialogGajiMinggu(acuan: acuan),
  ).then((v) => v == true);
}

class _DialogGajiMinggu extends StatefulWidget {
  const _DialogGajiMinggu({required this.acuan});

  final DateTime acuan;

  @override
  State<_DialogGajiMinggu> createState() => _DialogGajiMingguState();
}

class _DialogGajiMingguState extends State<_DialogGajiMinggu> {
  static const _gaya = TextStyle(fontSize: 12, height: 1.2);
  static const _gayaJudul = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  final _sb = Supabase.instance.client;
  final _gulir = ScrollController();
  bool _muat = true;
  bool _proses = false;
  bool _berubah = false;
  String _status = 'draft';
  String? _error;
  int _ongkir = 0;
  List<Map<String, dynamic>> _slip = [];

  DateTime get _senin {
    final h = DateTime(widget.acuan.year, widget.acuan.month, widget.acuan.day);
    return h.subtract(Duration(days: h.weekday - 1));
  }

  DateTime get _sabtu => _senin.add(const Duration(days: 5));

  String get _isoSenin => DateFormat('yyyy-MM-dd').format(_senin);

  String get _judulMinggu =>
      '${DateFormat('d/MM/yyyy').format(_senin)} – ${DateFormat('d/MM/yyyy').format(_sabtu)}';

  Map<String, dynamic> _peta(dynamic row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) return Map<String, dynamic>.from(row);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _daftar(dynamic v) {
    if (v is! List) return const [];
    return v.map(_peta).toList();
  }

  String _rp(dynamic n, {required bool ada}) {
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

  Future<void> _muatData() async {
    if (!await NetworkProbe.hasConnection()) {
      if (!mounted) return;
      setState(() {
        _muat = false;
        _error = 'Tidak ada internet.';
        _slip = [];
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
      if (!mounted) return;
      setState(() {
        _status = data['status']?.toString() ?? 'draft';
        _ongkir = angkaTeks((data['ongkir_belanja'] ?? 0).toString());
        _slip = _daftar(data['slip']);
        _muat = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _muat = false;
        _error =
            'Gagal memuat gaji. Jalankan ulang supabase/gaji.sql di Supabase, lalu segarkan.';
        _slip = [];
      });
    }
  }

  String _selCsv(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(RegExp(r'[;"\n\r]'))) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  void _unduh() {
    final isi = <String>['Nama;Peran;Hak;Kasbon;Dibayar;Hari'];
    for (final s in _slip) {
      final ada = s['ada_slip'] == true;
      isi.add(
        [
          s['nama'] ?? '',
          _labelPeran(s),
          ada ? s['total_insentif'] ?? 0 : '',
          s['kasbon'] ?? 0,
          ada ? s['dibayar'] ?? 0 : '',
          ada ? s['hari_kerja'] ?? 0 : '',
        ].map(_selCsv).join(';'),
      );
    }
    unduhCsv(nama: 'gaji_$_isoSenin.csv', isi: isi.join('\n'));
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
        _berubah = true;
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

  @override
  Widget build(BuildContext context) {
    final terkunci = _status == 'kunci';
    final adaSlip = _slip.any((s) => s['ada_slip'] == true);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _berubah);
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        constraints: AppDialog.batas(context),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Gaji  $_judulMinggu',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              _status,
              style: TextStyle(
                fontSize: 12,
                color: terkunci ? const Color(0xFF2E7D32) : Colors.grey.shade700,
              ),
            ),
            IconButton(
              tooltip: 'Segarkan',
              onPressed: _proses ? null : _muatData,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Unduh',
              onPressed: _muat || _proses || _slip.isEmpty ? null : _unduh,
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        content: SizedBox(
          width: 720,
          height: (MediaQuery.sizeOf(context).height - 220).clamp(280.0, 560.0),
          child: _muat
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB71C1C),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          adaSlip
                              ? 'Angka dari generate slip minggu ini.'
                              : 'Belum ada slip. Ongkir belanja diisi di barang masuk, lalu Generate.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    Text(
                      'Ongkir belanja minggu: Rp ${formatUang(_ongkir)}',
                      style: _gaya,
                    ),
                    const SizedBox(height: 10),
                    if (_slip.isEmpty)
                      Text(
                        'Master karyawan kosong.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      Expanded(
                        child: Scrollbar(
                          controller: _gulir,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _gulir,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowHeight: 32,
                                dataRowMinHeight: 28,
                                dataRowMaxHeight: 32,
                                headingTextStyle: _gayaJudul,
                                dataTextStyle: _gaya,
                                columns: const [
                                  DataColumn(label: Text('Nama')),
                                  DataColumn(label: Text('Peran')),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Hak'),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Kasbon'),
                                  ),
                                  DataColumn(
                                    numeric: true,
                                    label: Text('Dibayar'),
                                  ),
                                  DataColumn(
                                    numeric: true,
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
                                        Text(
                                          _rp(s['total_insentif'], ada: ada),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          'Rp ${formatUang(angkaTeks((s['kasbon'] ?? 0).toString()))}',
                                        ),
                                      ),
                                      DataCell(
                                        Text(_rp(s['dibayar'], ada: ada)),
                                      ),
                                      DataCell(
                                        Text(
                                          ada ? '${s['hari_kerja'] ?? 0}' : '—',
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: _proses
                ? null
                : () => _jalankan(
                    'gaji_sinkron_kasbon_setoran',
                    'Kasbon setoran disalin.',
                  ),
            child: const Text('Sinkron kasbon'),
          ),
          TextButton(
            onPressed: _proses || terkunci
                ? null
                : () => _jalankan(
                    'gaji_generate_slip',
                    'Slip gaji dihitung dan dikunci.',
                  ),
            child: const Text('Generate'),
          ),
          TextButton(
            onPressed: _proses || !terkunci
                ? null
                : () => _jalankan(
                    'gaji_buka_kunci_periode',
                    'Periode dibuka lagi.',
                  ),
            child: const Text('Buka kunci'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _berubah),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
