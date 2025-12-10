import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String keyUserId = "user_id";

  // Simpan ID user setelah login
  static Future<void> saveUserSession(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyUserId, id);
  }

  // Ambil ID user, return null jika belum login
  static Future<int?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyUserId);
  }

  // Logout
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserId);
  }
}
