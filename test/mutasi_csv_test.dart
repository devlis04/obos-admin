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

  test('abaikan baris debit', () {
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
}
