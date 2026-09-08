class CloudPage {
  static const int ukuranRentang = 200;
  static const int batasNotaRentang = 1500;
  static const int batasKunjungan = 800;
  static const int batasTokoRute = 800;
  static const Duration batasPermintaan = Duration(seconds: 20);

  static Future<T> denganBatas<T>(Future<T> future) {
    return future.timeout(batasPermintaan);
  }

  static Future<List<Map<String, dynamic>>> unduhHalaman({
    required Future<dynamic> Function(int from, int to) ambil,
    int ukuran = ukuranRentang,
    int batas = batasNotaRentang,
  }) async {
    final List<Map<String, dynamic>> hasil = [];
    var from = 0;
    while (from < batas) {
      final int to = from + ukuran - 1;
      final dynamic response = await denganBatas(ambil(from, to));
      final List<dynamic> page = response is List ? response : const [];
      for (final row in page) {
        if (row is Map) {
          hasil.add(Map<String, dynamic>.from(row));
        }
      }
      if (page.length < ukuran) break;
      from += ukuran;
    }
    return hasil;
  }
}
