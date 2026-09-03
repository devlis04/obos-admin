import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:obos_admin/features/setoran/barang_masuk_csv.dart';

void main() {
  test('baca CSV titik koma', () {
    const csv = 'kode_barang;nama_barang;qty;harga_beli\n'
        'SKU01;Teh;10;15000\n'
        'SKU02;Kopi;2;8.000\n';
    final h = BarangMasukCsv.parse(csv);
    expect(h.error, isNull);
    expect(h.baris.length, 2);
    expect(h.baris.first.kode, 'SKU01');
    expect(h.baris.first.qty, 10);
    expect(h.baris.first.harga, 15000);
    expect(h.baris[1].harga, 8000);
  });

  test('gabung kode sama, harga pakai yang lebih tinggi', () {
    const csv = 'kode,nama,qty,harga\n'
        'A,Teh,1,1000\n'
        'A,Teh,2,1500\n';
    final h = BarangMasukCsv.parse(csv);
    expect(h.baris.length, 1);
    expect(h.baris.single.qty, 3);
    expect(h.baris.single.harga, 1500);
  });

  test('template isi kode nama, qty harga kosong', () {
    final bytes = BarangMasukCsv.bytesTemplate([
      (kode: 'SKU01', nama: 'Teh;botol'),
    ]);
    final teks = utf8.decode(bytes);
    expect(teks, contains('kode_barang;nama_barang;qty;harga_beli'));
    expect(teks, contains('SKU01;"Teh;botol";;'));
    final h = BarangMasukCsv.parse(teks);
    expect(h.baris, isEmpty);
  });

  test('tolak tanpa header wajib', () {
    const csv = 'nama;qty\nTeh;1\n';
    final h = BarangMasukCsv.parse(csv);
    expect(h.baris, isEmpty);
    expect(h.error, isNotNull);
  });

  test('unggah batal jika kode atau nama tidak cocok', () {
    const csv = 'kode_barang;nama_barang;qty;harga_beli\n'
        'A;Teh;1;1000\n';
    final h = BarangMasukCsv.parse(csv);
    expect(
      BarangMasukCsv.cekCocokKatalog(h.baris, {'A': 'Kopi'}),
      contains('tidak cocok'),
    );
    expect(
      BarangMasukCsv.cekCocokKatalog(h.baris, {'B': 'Teh'}),
      contains('tidak ada'),
    );
    expect(BarangMasukCsv.cekCocokKatalog(h.baris, {'A': 'Teh'}), isNull);
  });

  test('sku baru batal jika kode sudah ada', () {
    const csv = 'kode_barang;nama_barang;qty;harga_beli\n'
        'Z9;Baru;1;1000\n';
    final h = BarangMasukCsv.parse(csv);
    expect(BarangMasukCsv.cekSkuBaru(h.baris, {'Z9'}), contains('sudah ada'));
    expect(BarangMasukCsv.cekSkuBaru(h.baris, {'A'}), isNull);
  });

  test('template sku baru satu baris contoh kode terbesar', () {
    final contoh = BarangMasukCsv.contohSkuBaru([
      (kode: '12', nama: 'Kecil', harga: 1000),
      (kode: '100', nama: 'Besar', harga: 25000),
    ]);
    expect(contoh.kode, '100');
    expect(contoh.nama, 'Besar');
    expect(contoh.qty, 1);
    expect(contoh.harga, 25000);
    final teks = utf8.decode(BarangMasukCsv.bytesTemplateSkuBaru(contoh));
    final baris = teks.replaceFirst(RegExp(r'^\uFEFF'), '').trim().split('\n');
    expect(baris.length, 2);
  });
}
