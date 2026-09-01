import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Prefer passing the backend URL at build time via:
  // flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  // or on a physical device: --dart-define=API_BASE_URL=http://<your-lan-ip>:8000
  static String get baseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000',
      );
  static const String _tokenKey = "jwt_token";

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
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
  static Future<Map<String, dynamic>> uploadFile(
    String filePath,
    String fileName,
  ) async {
    final uri = Uri.parse("$baseUrl/upload");
    final request = http.MultipartRequest('POST', uri);

    final headers = await _authHeaders(json: false);
    request.headers.addAll(headers);

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

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
  static Future<Map<String, dynamic>> analyzeFile(
    String filePath,
    String fileName,
  ) async {
    final uri = Uri.parse("$baseUrl/analyze");
    final request = http.MultipartRequest('POST', uri);

    final headers = await _authHeaders(json: false);
    request.headers.addAll(headers);

    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Analysis failed');
    }
  }

  /// Sends a question along with the file's summary to the AI.
  static Future<String> askAI(
    String question,
    Map<String, dynamic> fileSummary,
  ) async {
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
