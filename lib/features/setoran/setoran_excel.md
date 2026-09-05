# Peta workbook harian → layar Setoran admin

File operasional Senin–Sabtu (`SELASA.xlsx`, `RABU.xlsx`, …) yang mengisi `GAJIAN.xlsx`.
Aplikasi **tidak** mengunggah workbook ini. Layar Setoran mencocokkan **data aplikasi** (Supabase) dengan cara yang sama admin membaca sheet SETORAN.

Pasangan rute tetap (bukan nama sheet truk / sales yang naik hari itu):

| Header SETORAN / `rute_pengirim` | Sales aplikasi |
|---|---|
| SBGP01 | SBGS01 + SBGS02 |
| SBGP02 | SBGS03 + SBGS04 |
| SBGP03 | SBGS05 + SBGS06 |
| SBGP04 | SBGS07 + SBGS08 |

Sheet bernama SBGP01 bisa berisi rute sales lain di baris 1 (contoh Selasa: SBGS05/SBGS06 di I1). Itu truk Excel, bukan pairing aplikasi.

## Sheet SETORAN → kolom layar

| Excel | Aplikasi |
|---|---|
| KIRIMAN (H5 sheet truk) | Kiriman = packed live (`total_pembayaran_terkirim`, status ≠ batal) |
| BATALAN | Batal = packed − actual per nota |
| RETURAN | Tidak dipisah; masuk Batal |
| TK NGANJUK | Tidak ada di aplikasi |
| net = kiriman − batal − pending | Actual |
| TRANSFER (baris bank + lookup rekening) | Transfer kunci pengirim + unggah mutasi CSV |
| CASH (pecahan × nilai) | Tunai pengirim + Tunai admin (total; pecahan hanya alat bantu UI) |
| BOP (+ bensin) | BOP (`jumlah_bop`, maks 170.000 / pengirim / hari) |
| DIPAKE | Kasbon supir + kenek |
| SESA / CEK | Cek = actual − mutasi − tunai admin − BOP − kasbon − retur |

Pending (ditunda ke besok) tetap di Kiriman hari itu, lalu **otomatis masuk Kiriman keesokan harinya**. Actual hari itu = Kiriman − Batal − Pending.

Rumus kunci pengirim sudah: `actual ≈ transfer + tunai + BOP` (kasbon menutup selisih). SESA Excel = rekonsiliasi yang sama.

## Sheet lain (bukan layar ini)

| Sheet | Arti | Di mana di aplikasi |
|---|---|---|
| REPORT | Total perusahaan, absensi, kasbon, cek pecahan | Gaji (absensi, kasbon); pecahan di dialog tunai |
| SBGP01–04 | Per toko: muat / retur / batal / terkirim / kiriman | Nota per rute (tombol Nota) |
| PENDINGAN | Qty packed belum terkirim | Kolom Pending |
| TAMBAHAN / KIRIM ULANG / BONGKAR | Operasional gudang | Belum dicek di layar ini |
| STOK OPNAME | Sumber selisih barang gaji | `stok_opname` / generate slip Gaji, bukan setoran |

## Mutasi bank

Unggah **CSV** (ekspor dari Excel mutasi). Header yang dikenali: Jumlah/Kredit/Nominal, Tanggal, Berita/Keterangan, Rekening.

Pencocokan: baris CR yang Keterangannya berisi token `SBGP02/08-09-2026` (tanggal token = tanggal setoran) — jumlahnya dipakai untuk rute itu. DB diabaikan. Cadangan: nominal unik = transfer pengirim. Admin bisa pilih rute manual.
