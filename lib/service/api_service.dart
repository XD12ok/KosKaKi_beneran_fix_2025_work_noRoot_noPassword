import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://koskaki-api.servermbud.online/api';

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

  // =========================
  // REGISTER
  // =========================

  Future<Map<String, dynamic>?> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
    String role,
  ) async {
    final url = Uri.parse('$baseUrl/auth/register');

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

      print('REGISTER STATUS: ${response.statusCode}');
      print('REGISTER BODY: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return null;
    } catch (e) {
      print('ERROR REGISTER: $e');
      return null;
    }
  }

  // =========================
  // LOGIN
  // =========================

  Future<String?> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

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
        }),
      );

      print('LOGIN STATUS: ${response.statusCode}');
      print('LOGIN BODY: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        final token =
            decoded['token']?.toString() ??
            decoded['access_token']?.toString() ??
            decoded['data']?['token']?.toString() ??
            decoded['data']?['access_token']?.toString();

        if (token != null && token.isNotEmpty) {
          await saveToken(token);
          return token;
        }
      }

      return null;
    } catch (e) {
      print('ERROR LOGIN: $e');
      return null;
    }
  }

  // =========================
  // GET USER
  // =========================

  Future<Map<String, dynamic>?> getUser() async {
    final token = await getToken();

    if (token == null) {
      print('TOKEN NULL');
      return null;
    }

    final url = Uri.parse('$baseUrl/user');

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
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          if (decoded['data'] is Map) {
            return Map<String, dynamic>.from(decoded['data']);
          }

          if (decoded['user'] is Map) {
            return Map<String, dynamic>.from(decoded['user']);
          }

          return decoded;
        }
      }

      return null;
    } catch (e) {
      print('ERROR GET USER: $e');
      return null;
    }
  }

  // =========================
  // LOGOUT
  // =========================

  Future<bool> logout() async {
    final token = await getToken();

    if (token == null) return false;

    final url = Uri.parse('$baseUrl/logout');

    try {
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('LOGOUT STATUS: ${response.statusCode}');
      print('LOGOUT BODY: ${response.body}');

      if (response.statusCode == 200) {
        await removeToken();
        return true;
      }

      return false;
    } catch (e) {
      print('ERROR LOGOUT: $e');
      return false;
    }
  }

  // =========================
  // FORGOT PASSWORD
  // =========================

  Future<bool> forgotPassword(String email) async {
    final url = Uri.parse('$baseUrl/auth/forgot-password');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      print('FORGOT PASSWORD STATUS: ${response.statusCode}');
      print('FORGOT PASSWORD BODY: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('ERROR FORGOT PASSWORD: $e');
      return false;
    }
  }

  // =========================
  // RESET PASSWORD
  // =========================

  Future<bool> resetPassword(
    String email,
    String password,
    String confirmPassword,
  ) async {
    final url = Uri.parse('$baseUrl/auth/reset-password');

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

      print('RESET PASSWORD STATUS: ${response.statusCode}');
      print('RESET PASSWORD BODY: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('ERROR RESET PASSWORD: $e');
      return false;
    }
  }

  // =========================
  // HELPER
  // =========================

  int? _toInt(dynamic value) {
    if (value == null) return null;

    return int.tryParse(value.toString());
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];

      if (data is List) {
        return data;
      }

      if (data is Map) {
        final mapData = Map<String, dynamic>.from(data);

        if (mapData['data'] is List) {
          return mapData['data'];
        }

        if (mapData['messages'] is List) {
          return mapData['messages'];
        }

        if (mapData['conversations'] is List) {
          return mapData['conversations'];
        }
      }

      if (decoded['messages'] is List) {
        return decoded['messages'];
      }

      if (decoded['conversations'] is List) {
        return decoded['conversations'];
      }
    }

    return [];
  }

  Map<String, dynamic>? _extractMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data']);
      }

      if (decoded['conversation'] is Map) {
        return Map<String, dynamic>.from(decoded['conversation']);
      }

      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return null;
  }

  int? extractConversationId(dynamic decoded) {
    final map = _extractMap(decoded);

    if (map == null) return null;

    final dataMap = _toMap(map['data']);
    final conversationMap = _toMap(map['conversation']);

    return _toInt(map['id']) ??
        _toInt(map['conversation_id']) ??
        _toInt(map['conversationId']) ??
        _toInt(dataMap?['id']) ??
        _toInt(dataMap?['conversation_id']) ??
        _toInt(dataMap?['conversationId']) ??
        _toInt(conversationMap?['id']) ??
        _toInt(conversationMap?['conversation_id']) ??
        _toInt(conversationMap?['conversationId']);
  }

  // =========================
  // LIVE CHAT
  // =========================

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

      print('GET CONVERSATIONS URL: $url');
      print('GET CONVERSATIONS STATUS: ${response.statusCode}');
      print('GET CONVERSATIONS BODY: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        return _extractList(decoded);
      }

      return [];
    } catch (e) {
      print('ERROR GET CONVERSATIONS: $e');
      return [];
    }
  }

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

    final payloads = [
      {
        'owner_id': ownerId,
        'place_property_id': placePropertyId,
      },
      {
        'owner_id': ownerId,
        'property_id': placePropertyId,
      },
      {
        'receiver_id': ownerId,
        'place_property_id': placePropertyId,
      },
      {
        'receiver_id': ownerId,
        'property_id': placePropertyId,
      },
      {
        'user_id': ownerId,
        'place_property_id': placePropertyId,
      },
      {
        'user_id': ownerId,
        'property_id': placePropertyId,
      },
      {
        'place_property_id': placePropertyId,
      },
      {
        'property_id': placePropertyId,
      },
    ];

    try {
      for (final payload in payloads) {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        );

        print('CREATE CONVERSATION URL: $url');
        print('CREATE CONVERSATION PAYLOAD: ${jsonEncode(payload)}');
        print('CREATE CONVERSATION STATUS: ${response.statusCode}');
        print('CREATE CONVERSATION BODY: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = jsonDecode(response.body);

          final conversationId = extractConversationId(decoded);

          if (conversationId != null && conversationId > 0) {
            final map = _extractMap(decoded);

            return map ??
                {
                  'id': conversationId,
                };
          }
        }
      }

      return null;
    } catch (e) {
      print('ERROR CREATE CONVERSATION: $e');
      return null;
    }
  }

  Future<int?> createOrGetConversationId({
    required int ownerId,
    required int placePropertyId,
  }) async {
    final conversation = await createOrGetConversation(
      ownerId: ownerId,
      placePropertyId: placePropertyId,
    );

    final conversationId = extractConversationId(conversation);

    print('EXTRACTED CONVERSATION ID: $conversationId');

    return conversationId;
  }

  Future<List<dynamic>> getConversationMessages(int conversationId) async {
    final token = await getToken();

    if (token == null) {
      print('TOKEN NULL');
      return [];
    }

    final url = Uri.parse('$baseUrl/conversations/$conversationId/messages');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('GET MESSAGE URL: $url');
      print('GET MESSAGE STATUS: ${response.statusCode}');
      print('GET MESSAGE BODY: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        return _extractList(decoded);
      }

      return [];
    } catch (e) {
      print('ERROR GET MESSAGE: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> sendConversationMessage({
    required int conversationId,
    required String message,
  }) async {
    final token = await getToken();

    if (token == null) {
      print('TOKEN NULL');
      return null;
    }

    final url = Uri.parse('$baseUrl/conversations/$conversationId/messages');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': message,
        }),
      );

      print('SEND MESSAGE URL: $url');
      print('SEND MESSAGE STATUS: ${response.statusCode}');
      print('SEND MESSAGE BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }

        return {
          'success': true,
        };
      }

      return null;
    } catch (e) {
      print('ERROR SEND MESSAGE: $e');
      return null;
    }
  }

  // =========================
  // OWNER FAMILY / MEMBERS
  // =========================

  Future<List<dynamic>> getOwnerPropertiesWithMembers() async {
    final token = await getToken();

    if (token == null) {
      print('TOKEN NULL');
      return [];
    }

    final url = Uri.parse('$baseUrl/owner/properties-with-members');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('GET OWNER PROPERTIES URL: $url');
      print('GET OWNER PROPERTIES STATUS: ${response.statusCode}');
      print('GET OWNER PROPERTIES BODY: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        return _extractList(decoded);
      }

      return [];
    } catch (e) {
      print('ERROR GET OWNER PROPERTIES: $e');
      return [];
    }
  }
}