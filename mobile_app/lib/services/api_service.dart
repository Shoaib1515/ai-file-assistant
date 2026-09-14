import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:8000";
    }
    return "http://192.168.1.6:8000";
  }

  static const String _tokenKey = "jwt_token";
  static const String _userEmailKey = "user_email";
  static const String _userNameKey = "user_name";
  static const String _favoritesKey = "favorite_file_ids";

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<Set<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? [];
    return list.toSet();
  }

  static Future<void> setFavoriteId(String id, bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_favoritesKey) ?? []).toSet();
    if (isFavorite) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await prefs.setStringList(_favoritesKey, set.toList());
  }

  static Future<void> saveUserProfile(String email, String? fullName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
    if (fullName != null && fullName.isNotEmpty) {
      await prefs.setString(_userNameKey, fullName);
    } else {
      await prefs.remove(_userNameKey);
    }
  }

  static Future<Map<String, String?>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "email": prefs.getString(_userEmailKey),
      "name": prefs.getString(_userNameKey),
    };
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNameKey);
  }

  static Future<Map<String, dynamic>> fetchMe() async {
    final uri = Uri.parse("$baseUrl/auth/me");
    final headers = await _authHeaders(json: true);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        await saveUserProfile(data['email'] ?? '', data['full_name']);
        return data;
      }
    }
    throw Exception("Failed to fetch user profile");
  }

  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    final token = await getToken();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    if (json) {
      headers["Content-Type"] = "application/json";
    }
    return headers;
  }

  // ===========================================================
  // Authentication endpoints
  // ===========================================================

  static Future<Map<String, dynamic>> register(
    String email,
    String password, {
    String? fullName,
  }) async {
    final uri = Uri.parse("$baseUrl/auth/register");
    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "full_name": fullName,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final token = data['access_token'];
      if (token != null) {
        await saveToken(token);
      }
      final userData = data['user'];
      if (userData != null && userData is Map<String, dynamic>) {
        await saveUserProfile(
          userData['email'] ?? email,
          userData['full_name'] ?? fullName,
        );
      } else {
        await saveUserProfile(email, fullName);
      }
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Registration failed');
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final uri = Uri.parse("$baseUrl/auth/login");
    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final token = data['access_token'];
      if (token != null) {
        await saveToken(token);
      }
      final userData = data['user'];
      if (userData != null && userData is Map<String, dynamic>) {
        await saveUserProfile(
          userData['email'] ?? email,
          userData['full_name'],
        );
      } else {
        await saveUserProfile(email, null);
      }
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Login failed');
    }
  }

  static Future<void> logout() async {
    await clearToken();
  }

  static Future<String> checkConnection() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'];
      } else {
        return "Server error: ${response.statusCode}";
      }
    } catch (e) {
      return "Connection failed: $e";
    }
  }

  // ===========================================================
  // Dataset endpoints (authenticated)
  // ===========================================================

  /// Uploads a file to the backend and returns its summary.
  static Future<Map<String, dynamic>> uploadFile({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse("$baseUrl/upload");
    final request = http.MultipartRequest('POST', uri);

    final headers = await _authHeaders(json: false);
    request.headers.addAll(headers);

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Upload failed');
    }
  }

  /// Uploads a file and returns a full analysis report.
  static Future<Map<String, dynamic>> analyzeFile({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse("$baseUrl/analyze");
    final request = http.MultipartRequest('POST', uri);

    final headers = await _authHeaders(json: false);
    request.headers.addAll(headers);

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Analysis failed');
    }
  }

  /// 1-Tap Autonomous AI Structuring & Data Cleaning
  static Future<Map<String, dynamic>> autoStructureFile({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    int? fileId,
  }) async {
    if (fileId != null) {
      final uri = Uri.parse("$baseUrl/auto-structure/$fileId");
      final headers = await _authHeaders(json: true);
      final response = await http.post(uri, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Auto-structuring failed');
      }
    }

    final uri = Uri.parse("$baseUrl/auto-structure");
    final request = http.MultipartRequest('POST', uri);
    final headers = await _authHeaders(json: false);
    request.headers.addAll(headers);

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath, filename: fileName),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Auto-structuring failed');
    }
  }

  /// Sends a question along with optional file summary to the AI.
  static Future<String> askAI(
    String question, [
    Map<String, dynamic>? fileSummary,
  ]) async {
    final uri = Uri.parse("$baseUrl/ask");
    final headers = await _authHeaders(json: true);

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({"question": question, "file_summary": fileSummary}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['answer'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get AI response');
    }
  }

  /// Sends an instruction and gets back a list of proposed changes.
  static Future<List<dynamic>> suggestEdit(
    String filePath,
    String fileName,
    String instruction,
  ) async {
    final uri = Uri.parse("$baseUrl/suggest-edit");
    final request = http.MultipartRequest('POST', uri);

    final headers = await _authHeaders(json: false);
    request.headers.addAll(headers);

    request.fields['instruction'] = instruction;
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['proposed_changes'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get suggestions');
    }
  }

  /// Sends the approved changes and gets back the updated file's raw bytes.
  static Future<Uint8List> applyEdit(
    String filePath,
    String fileName,
    List<dynamic> changes,
  ) async {
    final uri = Uri.parse("$baseUrl/apply-edit");
    final request = http.MultipartRequest('POST', uri);

    final headers = await _authHeaders(json: false);
    request.headers.addAll(headers);

    request.fields['changes'] = jsonEncode(changes);
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to apply changes');
    }
  }

  // ===========================================================
  // Database-backed endpoints (authenticated)
  // ===========================================================

  /// Returns metadata for files uploaded by the authenticated user.
  static Future<List<Map<String, dynamic>>> getAllFiles() async {
    final uri = Uri.parse("$baseUrl/files");
    final headers = await _authHeaders(json: true);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load file history');
    }
  }

  /// Re-analyzes a file stored on the backend.
  static Future<Map<String, dynamic>> analyzeStoredFile(int fileId) async {
    final uri = Uri.parse("$baseUrl/files/$fileId/analyze");
    final headers = await _authHeaders(json: true);
    final response = await http.post(uri, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Analysis failed');
    }
  }

  /// Suggests edits for a file stored on the backend.
  static Future<List<dynamic>> suggestEditStored(
    int fileId,
    String instruction,
  ) async {
    final uri = Uri.parse("$baseUrl/files/$fileId/suggest-edit");
    final headers = await _authHeaders(json: false);
    final response = await http.post(
      uri,
      headers: headers,
      body: {"instruction": instruction},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['proposed_changes'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to get suggestions');
    }
  }

  /// Applies edits to a file stored on the backend.
  static Future<Uint8List> applyEditStored(
    int fileId,
    List<dynamic> changes,
  ) async {
    final uri = Uri.parse("$baseUrl/files/$fileId/apply-edit");
    final headers = await _authHeaders(json: false);
    final response = await http.post(
      uri,
      headers: headers,
      body: {"changes": jsonEncode(changes)},
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to apply changes');
    }
  }

  /// Downloads a file stored on the backend.
  static Future<Uint8List> downloadFile(int fileId) async {
    final uri = Uri.parse("$baseUrl/files/$fileId/download");
    final headers = await _authHeaders(json: false);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download file');
    }
  }

  /// Deletes a file stored on the backend.
  static Future<void> deleteFile(int fileId) async {
    final uri = Uri.parse("$baseUrl/files/$fileId");
    final headers = await _authHeaders(json: true);
    final response = await http.delete(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete file');
    }
  }
}
