import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NetworkProbe {
  static Future<bool> hasConnection() async {
    try {
      final raw = dotenv.env['SUPABASE_URL'] ?? '';
      if (raw.trim().isEmpty) return false;
      final dasar = Uri.parse(raw.trim());
      final uri = Uri.parse('${dasar.scheme}://${dasar.authority}/auth/v1/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
