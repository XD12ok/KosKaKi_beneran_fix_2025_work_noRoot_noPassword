import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://koskaki-api.servermbud.online/api';

  // Token
  static const String _tokenKey = 'auth_token';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // REGISTER
  Future<Map<String, dynamic>?> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
    String role,
  ) async {
    final url = Uri.parse('$baseUrl/auth/register?');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'role': role,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Error Register: $e');
      return null;
    }
  }

  // LOGIN
  Future<String?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login?');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'];
        await saveToken(token);
        return token;
      } else {
        return null;
      }
    } catch (e) {
      print('Error Login: $e');
      return null;
    }
  }

  // GET USER
  Future<Map<String, dynamic>?> getUser() async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/user');

    if (token == null) return null;

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('GET USER STATUS: ${response.statusCode}');
      print('GET USER BODY: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print('Error Get User: $e');
      return null;
    }
  }

  // LOGOUT
  Future<bool> logout() async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/logout');

    if (token == null) return false;

    try {
      var response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 405) {
        response = await http.post(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      if (response.statusCode == 200) {
        await removeToken();
        return true;
      }

      return false;
    } catch (e) {
      print('Error Logout: $e');
      return false;
    }
  }

  // FORGOT PASSWORD
  Future<bool> forgotPassword(String email) async {
    final url = Uri.parse('$baseUrl/auth/forgot-password');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("ERROR FORGOT: $e");
      return false;
    }
  }

  // RESET PASSWORD
  Future<bool> resetPassword(
    String email,
    String password,
    String confirmPassword,
  ) async {
    final url = Uri.parse('$baseUrl/reset-password');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'password_confirmation': confirmPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("ERROR RESET: $e");
      return false;
    }
  }

  // =========================
  // LIVE CHAT
  // =========================

  // GET SEMUA CONVERSATION
  Future<List<dynamic>> getConversations() async {
    final token = await getToken();

    if (token == null) {
      print('TOKEN NULL');
      return [];
    }

    final url = Uri.parse('$baseUrl/conversations');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('GET CONVERSATIONS STATUS: ${response.statusCode}');
      print('GET CONVERSATIONS BODY: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data;
        }

        if (data is Map<String, dynamic>) {
          if (data['data'] != null && data['data'] is List) {
            return data['data'];
          }

          if (data['conversations'] != null && data['conversations'] is List) {
            return data['conversations'];
          }
        }

        return [];
      }

      return [];
    } catch (e) {
      print('ERROR GET CONVERSATIONS: $e');
      return [];
    }
  }

  // CREATE OR GET EXISTING CONVERSATION
  Future<Map<String, dynamic>?> createOrGetConversation({
    required int ownerId,
    required int placePropertyId,
  }) async {
    final token = await getToken();

    if (token == null) {
      print('TOKEN NULL');
      return null;
    }

    final url = Uri.parse('$baseUrl/conversations');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'owner_id': ownerId,
          'place_property_id': placePropertyId,
        }),
      );

      print('CREATE CONVERSATION STATUS: ${response.statusCode}');
      print('CREATE CONVERSATION BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          if (data['data'] != null && data['data'] is Map<String, dynamic>) {
            return data['data'];
          }

          if (data['conversation'] != null &&
              data['conversation'] is Map<String, dynamic>) {
            return data['conversation'];
          }

          return data;
        }
      }

      return null;
    } catch (e) {
      print('ERROR CREATE CONVERSATION: $e');
      return null;
    }
  }

  // GET ISI CHAT BERDASARKAN CONVERSATION ID
  Future<List<dynamic>> getConversationMessages(int conversationId) async {
    final token = await getToken();

    if (token == null) {
      print('TOKEN NULL');
      return [];
    }

    final url = Uri.parse('$baseUrl/conversations/$conversationId/message');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('GET MESSAGE STATUS: ${response.statusCode}');
      print('GET MESSAGE BODY: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data;
        }

        if (data is Map<String, dynamic>) {
          if (data['data'] != null && data['data'] is List) {
            return data['data'];
          }

          if (data['messages'] != null && data['messages'] is List) {
            return data['messages'];
          }
        }

        return [];
      }

      return [];
    } catch (e) {
      print('ERROR GET MESSAGE: $e');
      return [];
    }
  }

  // KIRIM PESAN
  Future<Map<String, dynamic>?> sendConversationMessage({
    required int conversationId,
    required String message,
  }) async {
    final token = await getToken();

    if (token == null) {
      print('TOKEN NULL');
      return null;
    }

    final url = Uri.parse('$baseUrl/conversations/$conversationId/message');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      );

      print('SEND MESSAGE STATUS: ${response.statusCode}');
      print('SEND MESSAGE BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print('ERROR SEND MESSAGE: $e');
      return null;
    }
  }
}
