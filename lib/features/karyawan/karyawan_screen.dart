import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_dialog.dart';
import '../../core/format_uang.dart';
import '../../core/gulir.dart';
import '../../core/network_probe.dart';
import '../../core/ui_feedback.dart';
import '../auth/login_screen.dart';

class KaryawanScreen extends StatefulWidget {
  final AuthController auth;
  final VoidCallback bukaMenu;
  const KaryawanScreen({
    super.key,
    required this.auth,
    required this.bukaMenu,
  });

  @override
  State<KaryawanScreen> createState() => _KaryawanScreenState();
}

class _KaryawanScreenState extends State<KaryawanScreen> {
  static const _gaya = TextStyle(fontSize: 12, height: 1.2);
  static const _gayaJudul = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  final _sb = Supabase.instance.client;
  final _gulir = ScrollController();
  bool _muat = true;
  String? _error;
  List<Map<String, dynamic>> _data = [];

  Map<String, dynamic> _peta(dynamic row) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) return Map<String, dynamic>.from(row);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _daftar(dynamic v) {
    if (v is! List) return const [];
    return v.map(_peta).toList();
  }

  String _labelRute(Map<String, dynamic> k) {
    final peran = (k['peran']?.toString() ?? '').toLowerCase();
    if (peran == 'sales') return k['rute_sales']?.toString() ?? '';
    if (peran == 'pengirim') {
      final rute = k['rute_pengirim']?.toString() ?? '';
      final kursi = k['peran_kirim']?.toString() ?? '';
      if (kursi.isEmpty) return rute;
      return '$rute $kursi';
    }
    return '';
  }

  int _angka(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return angkaTeks(v?.toString() ?? '0');
  }

  double _persenAngka(dynamic v) {
    if (v is num) return v.toDouble();
    final s = (v?.toString() ?? '').trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  String _teksPersen(dynamic v) {
    final n = _persenAngka(v);
    if (n == 0) return '0';
    var t = n.toStringAsFixed(4);
    t = t.replaceFirst(RegExp(r'0+$'), '');
    t = t.replaceFirst(RegExp(r'\.$'), '');
    return t.replaceAll('.', ',');
  }

  int _targetLaba(int omset, double persen) {
    if (omset <= 0 || persen <= 0) return 0;
    return (omset * persen / (100 + persen)).round();
  }

  List<Map<String, dynamic>> _peran(String peran) {
    return _data
        .where(
          (k) => (k['peran']?.toString() ?? '').trim().toLowerCase() == peran,
        )
        .toList();
  }

  Widget _kartuPeran({
    required String judul,
    required String peran,
    required bool tampilRute,
  }) {
    final isi = _peran(peran);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judul,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            if (isi.isEmpty)
              Text(
                'Belum ada.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Expanded(child: Text('Nama', style: _gayaJudul)),
                    if (tampilRute)
                      const SizedBox(
                        width: 72,
                        child: Text('Rute', style: _gayaJudul),
                      ),
                    if (peran == 'sales') ...[
                      const SizedBox(
                        width: 88,
                        child: Text('Omset', style: _gayaJudul),
                      ),
                      const SizedBox(
                        width: 52,
                        child: Text('% laba', style: _gayaJudul),
                      ),
                      const SizedBox(
                        width: 88,
                        child: Text('Laba', style: _gayaJudul),
                      ),
                    ],
                    if (peran != 'sales')
                      const SizedBox(
                        width: 52,
                        child: Text('Urutan', style: _gayaJudul),
                      ),
                    const SizedBox(
                      width: 40,
                      child: Text('Aktif', style: _gayaJudul),
                    ),
                  ],
                ),
              ),
              for (final k in isi)
                InkWell(
                  onTap: () => _dialogKaryawan(awal: k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${k['nama'] ?? ''}', style: _gaya),
                        ),
                        if (tampilRute)
                          SizedBox(
                            width: 72,
                            child: Text(_labelRute(k), style: _gaya),
                          ),
                        if (peran == 'sales') ...[
                          SizedBox(
                            width: 88,
                            child: Text(
                              formatUang(_angka(k['target_omset'])),
                              style: _gaya,
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              _teksPersen(k['target_profit_pct']),
                              style: _gaya,
                            ),
                          ),
                          SizedBox(
                            width: 88,
                            child: Text(
                              formatUang(
                                _targetLaba(
                                  _angka(k['target_omset']),
                                  _persenAngka(k['target_profit_pct']),
                                ),
                              ),
                              style: _gaya,
                            ),
                          ),
                        ],
                        if (peran != 'sales')
                          SizedBox(
                            width: 52,
                            child: Text('${k['urutan'] ?? 0}', style: _gaya),
                          ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            k['aktif'] != false ? 'ya' : 'tidak',
                            style: _gaya,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
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
        _data = [];
      });
      return;
    }
    setState(() {
      _muat = true;
      _error = null;
    });
    try {
      final mentah = await _sb.rpc('gaji_karyawan_lihat');
      final data = _peta(mentah);
      if (data['ok'] != true) {
        throw StateError(data['pesan']?.toString() ?? 'RPC ditolak');
      }
      if (!mounted) return;
      setState(() {
        _data = _daftar(data['data']);
        _muat = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _muat = false;
        _error =
            'Gagal memuat karyawan. Jalankan ulang supabase/gaji.sql di Supabase, lalu segarkan.';
        _data = [];
      });
    }
  }

  Future<void> _dialogKaryawan({Map<String, dynamic>? awal}) async {
    if (!await _adaNet()) return;
    final edit = awal != null;
    final namaCtrl = TextEditingController(text: awal?['nama']?.toString() ?? '');
    final kunciCtrl = TextEditingController(
      text: awal?['nama_kunci']?.toString() ?? '',
    );
    final ruteSalesCtrl = TextEditingController(
      text: awal?['rute_sales']?.toString() ?? '',
    );
    final ruteKirimCtrl = TextEditingController(
      text: awal?['rute_pengirim']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: awal?['user_email']?.toString() ?? '',
    );
    final urutanCtrl = TextEditingController(
      text: '${awal?['urutan'] ?? 0}',
    );
    final omsetCtrl = TextEditingController(
      text: formatUang(_angka(awal?['target_omset'])),
    );
    final persenCtrl = TextEditingController(
      text: _teksPersen(awal?['target_profit_pct']),
    );
    var peran = (awal?['peran']?.toString() ?? 'gudang').toLowerCase();
    var kursi = (awal?['peran_kirim']?.toString() ?? 'supir').toLowerCase();
    var aktif = awal?['aktif'] != false;
    var proses = false;

    if (!mounted) {
      namaCtrl.dispose();
      kunciCtrl.dispose();
      ruteSalesCtrl.dispose();
      ruteKirimCtrl.dispose();
      emailCtrl.dispose();
      urutanCtrl.dispose();
      omsetCtrl.dispose();
      persenCtrl.dispose();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            InputDecoration dekor(String label) {
              return InputDecoration(
                isDense: true,
                labelText: label,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              );
            }

            Future<void> simpan() async {
              if (proses) return;
              var kunci = kunciCtrl.text.trim().toLowerCase();
              if (kunci.isEmpty) {
                kunci = namaCtrl.text.trim().toLowerCase().replaceAll(
                  RegExp(r'[^a-z0-9]+'),
                  '_',
                );
              }
              setLocal(() => proses = true);
              try {
                final mentah = await _sb.rpc(
                  'gaji_karyawan_ubah',
                  params: {
                    'p_nama_kunci': kunci,
                    'p_nama': namaCtrl.text.trim(),
                    'p_peran': peran,
                    'p_rute_sales': ruteSalesCtrl.text.trim(),
                    'p_rute_pengirim': ruteKirimCtrl.text.trim(),
                    'p_peran_kirim': kursi,
                    'p_user_email': emailCtrl.text.trim(),
                    'p_urutan': int.tryParse(urutanCtrl.text.trim()) ?? 0,
                    'p_aktif': aktif,
                    'p_target_omset': angkaTeks(omsetCtrl.text),
                    'p_target_profit_pct': _persenAngka(persenCtrl.text),
                  },
                );
                final data = _peta(mentah);
                if (!mounted) return;
                if (data['ok'] != true) {
                  showAppSnackBar(
                    this.context,
                    message: data['pesan']?.toString() ?? 'Gagal menyimpan.',
                    warna: AppSnackBarTone.kuning,
                  );
                  if (ctx.mounted) setLocal(() => proses = false);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                showAppSnackBar(
                  this.context,
                  message: 'Karyawan disimpan.',
                  warna: AppSnackBarTone.hijau,
                );
                await _muatData();
              } catch (e) {
                if (mounted) {
                  showAppSnackBar(
                    this.context,
                    message: e is PostgrestException
                        ? (e.message.isNotEmpty
                            ? e.message
                            : 'Gagal menyimpan karyawan.')
                        : 'Gagal menyimpan karyawan.',
                  );
                }
                if (ctx.mounted) setLocal(() => proses = false);
              }
            }

            Future<void> hapus() async {
              if (!edit || proses) return;
              final kunci = kunciCtrl.text.trim().toLowerCase();
              final nama = namaCtrl.text.trim();
              final ya = await _konfirmasiHapus(nama.isEmpty ? kunci : nama);
              if (!ya || !mounted) return;
              setLocal(() => proses = true);
              final ok = await _hapusKaryawan(kunci);
              if (!ok) {
                if (ctx.mounted) setLocal(() => proses = false);
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (!mounted) return;
              showAppSnackBar(
                this.context,
                message: 'Karyawan dihapus.',
                warna: AppSnackBarTone.hijau,
              );
              await _muatData();
            }

            return AppDialog(
              title: Text(edit ? 'Ubah karyawan' : 'Karyawan baru'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaCtrl,
                      style: _gaya,
                      decoration: dekor('Nama'),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: kunciCtrl,
                      style: _gaya,
                      enabled: !edit,
                      decoration: dekor('Kunci (huruf kecil, unik)'),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: peran,
                      decoration: dekor('Peran'),
                      style: _gaya.copyWith(color: Colors.black),
                      items: const [
                        DropdownMenuItem(value: 'sales', child: Text('sales')),
                        DropdownMenuItem(
                          value: 'pengirim',
                          child: Text('pengirim'),
                        ),
                        DropdownMenuItem(value: 'gudang', child: Text('gudang')),
                        DropdownMenuItem(value: 'admin', child: Text('admin')),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => peran = v);
                      },
                    ),
                    if (peran == 'sales') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: ruteSalesCtrl,
                        style: _gaya,
                        decoration: dekor('Rute sales (SBGS01)'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: omsetCtrl,
                        style: _gaya,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [FormatRibuan()],
                        decoration: dekor('Target omset').copyWith(
                          prefixText: 'Rp ',
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: persenCtrl,
                        style: _gaya,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: dekor('Target % laba'),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Target laba: Rp ${formatUang(_targetLaba(angkaTeks(omsetCtrl.text), _persenAngka(persenCtrl.text)))}',
                          style: _gaya.copyWith(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                    if (peran == 'pengirim') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: ruteKirimCtrl,
                        style: _gaya,
                        decoration: dekor('Rute pengirim (SBGP01)'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: kursi == 'kenek' ? 'kenek' : 'supir',
                        decoration: dekor('Kursi'),
                        style: _gaya.copyWith(color: Colors.black),
                        items: const [
                          DropdownMenuItem(value: 'supir', child: Text('supir')),
                          DropdownMenuItem(value: 'kenek', child: Text('kenek')),
                        ],
                        onChanged: (v) {
                          if (v != null) setLocal(() => kursi = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      style: _gaya,
                      decoration: dekor('Email akun (opsional)'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: urutanCtrl,
                      style: _gaya,
                      decoration: dekor('Urutan tampil'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktif', style: _gaya),
                      value: aktif,
                      onChanged: (v) => setLocal(() => aktif = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: proses ? null : () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
                if (edit)
                  TextButton(
                    onPressed: proses ? null : hapus,
                    child: const Text('Hapus'),
                  ),
                FilledButton(
                  onPressed: proses ? null : simpan,
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    namaCtrl.dispose();
    kunciCtrl.dispose();
    ruteSalesCtrl.dispose();
    ruteKirimCtrl.dispose();
    emailCtrl.dispose();
    urutanCtrl.dispose();
    omsetCtrl.dispose();
    persenCtrl.dispose();
  }

  Future<bool> _konfirmasiHapus(String nama) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: const Text('Hapus karyawan?'),
        content: Text(
          'Hapus $nama beserta absensi, kasbon, dan slip gajinya. Tidak bisa dibatalkan.',
        ),
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
    return ya == true;
  }

  Future<bool> _hapusKaryawan(String kunci) async {
    try {
      final mentah = await _sb.rpc(
        'gaji_karyawan_hapus',
        params: {'p_nama_kunci': kunci},
      );
      final data = _peta(mentah);
      if (data['ok'] != true) {
        if (mounted) {
          showAppSnackBar(
            context,
            message: data['pesan']?.toString() ?? 'Gagal menghapus.',
            warna: AppSnackBarTone.kuning,
          );
        }
        return false;
      }
      return true;
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, message: 'Gagal menghapus karyawan.');
      }
      return false;
    }
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
        title: const Text('Data karyawan'),
        actions: [
          IconButton(
            tooltip: 'Tambah',
            onPressed: _muat ? null : () => _dialogKaryawan(),
            icon: const Icon(Icons.person_add_outlined),
          ),
          IconButton(
            tooltip: 'Segarkan',
            onPressed: _muat ? null : _muatData,
            icon: const Icon(Icons.refresh),
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
                    'Halo, ${widget.auth.nama}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Absensi harian hanya untuk pengirim dan gudang. Admin dan sales tidak dicentang hadir.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
                  if (_data.isEmpty)
                    Text(
                      'Belum ada karyawan.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, batas) {
                        final kartu = [
                          _kartuPeran(
                            judul: 'Sales',
                            peran: 'sales',
                            tampilRute: true,
                          ),
                          _kartuPeran(
                            judul: 'Pengirim',
                            peran: 'pengirim',
                            tampilRute: true,
                          ),
                          _kartuPeran(
                            judul: 'Gudang',
                            peran: 'gudang',
                            tampilRute: false,
                          ),
                          _kartuPeran(
                            judul: 'Admin',
                            peran: 'admin',
                            tampilRute: false,
                          ),
                        ];
                        if (batas.maxWidth < 720) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < kartu.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                kartu[i],
                              ],
                            ],
                          );
                        }
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: kartu[0]),
                                const SizedBox(width: 12),
                                Expanded(child: kartu[1]),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: kartu[2]),
                                const SizedBox(width: 12),
                                Expanded(child: kartu[3]),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
