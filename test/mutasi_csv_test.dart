import 'package:flutter_test/flutter_test.dart';
import 'package:obos_admin/features/setoran/mutasi_csv.dart';

void main() {
  test('baca CSV kredit bertitik ribuan', () {
    const csv = 'Tanggal;Kredit;Berita;Rekening\n'
        '02/09/2026;1.250.000;SBGP01/02-09-2026;Devlis\n'
        '02/09/2026;50000;parkir;-\n';
    final h = MutasiCsv.parse(csv);
    expect(h.error, isNull);
    expect(h.baris.length, 2);
    expect(h.baris.first.jumlah, 1250000);
    expect(h.baris.first.berita, 'SBGP01/02-09-2026');
    expect(h.baris.first.tanggalMutasi, '2026-09-02');
    expect(h.baris.first.rekening, 'Devlis');
  });

  test('abaikan baris debit dari kolom Jenis dan berita DB', () {
    const csv = 'keterangan,kredit,debit\n'
        'setor,0,100000\n'
        'masuk,750000,0\n';
    final h = MutasiCsv.parse(csv);
    expect(h.baris.length, 1);
    expect(h.baris.single.jumlah, 750000);
  });

  test('CSV bank: Jumlah+Jenis CR, token SBGP di Keterangan', () {
    const csv =
        'Tanggal,Keterangan,Cabang,Jumlah,Jenis,Saldo\n'
        '"01/09","TRSF E-BANKING CR 0109/FTTRX/SBGP04/02-09-2026",,"150.000,00","CR","1.500.000,00"\n'
        '"02/09","BI-FAST TRSF DB 0209/TO_MANDIRI",,"50.000,00","DB","1.450.000,00"\n';
    final h = MutasiCsv.parse(csv);
    expect(h.error, isNull);
    expect(h.baris.length, 1);
    expect(h.baris.single.jumlah, 150000);
    expect(
      h.baris.single.berita,
      'TRSF E-BANKING CR 0109/FTTRX/SBGP04/02-09-2026',
    );
  });

  test('CSV BCA korporat: kop, PEND, jumlah 8,520,000.00 CR', () {
    const csv = '"Informasi Rekening - Mutasi Rekening"," "," "," "," ",\n'
        '"No. rekening : 0552372610"\n'
        '"Nama : ALHAN BERKAH MAKMUR PT"\n'
        '"Periode : 08/09/2026 - 08/09/2026"\n'
        '"Kode Mata Uang : Rp"\n'
        '"Tanggal Transaksi","Keterangan","Cabang","Jumlah","Saldo"\n'
        '"PEND","TRSF E-BANKING CR 0809/FTSCY/WS95031 100.00  NABILA IRAMA PUTRA  ","0000","100.00 CR","154,376,421.00"\n'
        '"PEND","TRSF E-BANKING CR 0809/FTSCY/WS95271 8520000.00  SBGP 02, 08 SEPTEM BER 2026  AGUS TRIHERANTO ","0000","8,520,000.00 CR","162,896,421.00"\n'
        '"PEND","BI-FAST TRSF DB 0809/TO_MANDIRI","0000","50,000.00 DB","162,846,421.00"\n'
        '"Saldo Awal : 154,376,321.00"\n'
        '"Mutasi Debet : 0.00","0"\n'
        '"Mutasi Kredit : 77,001,100.00","5"\n'
        '"Saldo Akhir : 231,377,421.00"\n';
    final h = MutasiCsv.parse(csv);
    expect(h.error, isNull);
    expect(h.baris.length, 2);
    expect(h.baris[0].jumlah, 100);
    expect(h.baris[0].tanggalMutasi, '2026-09-08');
    expect(h.baris[0].rekening, 'NABILA IRAMA PUTRA');
    expect(h.baris[1].jumlah, 8520000);
    expect(h.baris[1].rekening, 'AGUS TRIHERANTO');
    expect(h.baris[1].berita, contains('AGUS TRIHERANTO'));
  });

  test('kode pengirim dari berita BCA yang terpotong spasi', () {
    expect(
      MutasiCsv.ruteDariBerita('SBGP01/02-09-2026', '2026-09-02'),
      'SBGP01',
    );
    expect(
      MutasiCsv.ruteDariBerita(
        'TRSF E-BANKING CR 0109/FTTRX/SBGP04/02-09-2026',
        '2026-09-02',
      ),
      'SBGP04',
    );
    expect(
      MutasiCsv.ruteDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95271 8520000.00  SBGP 02, 08 SEPTEM BER 2026  AGUS TRIHERANTO',
        '2026-09-08',
      ),
      'SBGP02',
    );
    expect(
      MutasiCsv.ruteDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95271 16937000.00  SBGP03 - 08/09/202 6  MUHAMMAD AFJAYNI Z',
        '2026-09-08',
      ),
      'SBGP03',
    );
    expect(
      MutasiCsv.ruteDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95031 36544000.00  SBGP04 08 SEP 2026 NABILA IRAMA PUTRA',
        '2026-09-08',
      ),
      'SBGP04',
    );
    expect(
      MutasiCsv.ruteDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95031 15000000.00  TEGUH HARI HERMAWA',
        '2026-09-08',
      ),
      isNull,
    );
    expect(
      MutasiCsv.ruteDariBerita('SBGP04 08 SEP 2026', '2026-09-07'),
      isNull,
    );
  });

  test('nama pengirim dari keterangan BCA korporat', () {
    expect(
      MutasiCsv.namaDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95031 100.00  NABILA IRAMA PUTRA',
      ),
      'NABILA IRAMA PUTRA',
    );
    expect(
      MutasiCsv.namaDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95271 8520000.00  SBGP 02, 08 SEPTEM BER 2026  AGUS TRIHERANTO',
      ),
      'AGUS TRIHERANTO',
    );
    expect(
      MutasiCsv.namaDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95271 16937000.00  SBGP03 - 08/09/202 6  MUHAMMAD AFJAYNI Z',
      ),
      'MUHAMMAD AFJAYNI Z',
    );
    expect(
      MutasiCsv.namaDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95031 36544000.00  SBGP04 08 SEP 2026 NABILA IRAMA PUTRA',
      ),
      'NABILA IRAMA PUTRA',
    );
    expect(
      MutasiCsv.namaDariBerita(
        'TRSF E-BANKING CR 0809/FTSCY/WS95031 15000000.00  TEGUH HARI HERMAWA',
      ),
      'TEGUH HARI HERMAWA',
    );
  });
}
