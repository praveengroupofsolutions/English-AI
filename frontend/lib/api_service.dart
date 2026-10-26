import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _accessKey = 'english_ai_access_token';
  static const _refreshKey = 'english_ai_refresh_token';
  static const _modeKey = 'english_ai_demo_mode';
  static const _urlKey = 'english_ai_api_url';
  static const _demoUserKey = 'english_ai_demo_user';
  static const _demoUsersKey = 'english_ai_demo_users';
  static const _demoOtpKey = 'english_ai_demo_otp';
  static const _demoResetKey = 'english_ai_demo_reset';
  static const _demoResetEmailKey = 'english_ai_demo_reset_email';
  final http.Client _client = http.Client();

  String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000';
    return 'http://localhost:5000';
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_urlKey) ?? defaultBaseUrl;
  }

  Future<void> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, value.trim().replaceFirst(RegExp(r'/$'), ''));
  }

  Future<bool> getDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_modeKey) ?? true;
  }

  Future<void> setDemoMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modeKey, value);
  }

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey) != null;
  }

  Future<Map<String, dynamic>> health() async {
    final base = await getBaseUrl();
    try {
      final response = await _client.get(Uri.parse('$base/')).timeout(const Duration(seconds: 4));
      final data = _decode(response.body);
      return {'online': response.statusCode >= 200 && response.statusCode < 300, 'message': data['message'] ?? 'Backend response'};
    } catch (_) {
      return {'online': false, 'message': 'Backend unavailable'};
    }
  }

  Future<Map<String, dynamic>> _send(String path, {String method = 'GET', Map<String, dynamic>? body, Map<String, String>? extraHeaders}) async {
    final base = await getBaseUrl();
    final prefs = await SharedPreferences.getInstance();
    final headers = <String, String>{'Content-Type': 'application/json', ...?extraHeaders};
    final access = prefs.getString(_accessKey);
    if (access != null) headers['Authorization'] = 'Bearer $access';

    var response = await _perform('$base$path', method, headers, body);
    if (response.statusCode == 401 && !path.contains('/auth/login') && !path.contains('/auth/refresh')) {
      final refreshToken = prefs.getString(_refreshKey);
      if (refreshToken != null) {
        try {
          final refreshed = await _perform(
            '$base/api/v1/auth/refresh',
            'POST',
            {'Content-Type': 'application/json'},
            {'refreshToken': refreshToken},
          );
          if (refreshed.statusCode >= 200 && refreshed.statusCode < 300) {
            final refreshData = _decode(refreshed.body);
            final nextAccess = refreshData['accessToken'] as String?;
            final nextRefresh = refreshData['refreshToken'] as String?;
            if (nextAccess != null) {
              await prefs.setString(_accessKey, nextAccess);
              if (nextRefresh != null) await prefs.setString(_refreshKey, nextRefresh);
              headers['Authorization'] = 'Bearer $nextAccess';
              response = await _perform('$base$path', method, headers, body);
            }
          } else {
            await clearSession();
          }
        } catch (_) {
          await clearSession();
        }
      }
    }

    final data = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data['message']?.toString() ?? 'Request failed (${response.statusCode})');
    }
    return data;
  }

  Future<http.Response> _perform(String url, String method, Map<String, String> headers, Map<String, dynamic>? body) async {
    try {
      final uri = Uri.parse(url);
      final encodedBody = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'POST':
          return await _client.post(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 15));
        case 'PATCH':
          return await _client.patch(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 15));
        case 'DELETE':
          return await _client.delete(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 15));
        default:
          return await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Cannot reach the API. Check the backend URL and server status.');
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access != null) await prefs.setString(_accessKey, access);
    if (refresh != null) await prefs.setString(_refreshKey, refresh);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  Future<Map<String, dynamic>> login(String email, String password, bool demo) async {
    if (!demo) {
      final result = await _send('/api/v1/auth/login', method: 'POST', body: {'email': email, 'password': password});
      await _saveTokens(result);
      return result;
    }
    final prefs = await SharedPreferences.getInstance();
    final cleanEmail = email.trim().toLowerCase();
    final users = _readUsers(prefs);
    final existing = users.cast<Map<String, dynamic>?>().firstWhere((item) => item?['email'] == cleanEmail, orElse: () => null);
    if (existing != null && existing['password'] != password) throw const ApiException('Invalid email or password');
    final user = existing == null
        ? <String, dynamic>{'id': 'demo-${DateTime.now().millisecondsSinceEpoch}', 'name': cleanEmail.split('@').first, 'email': cleanEmail, 'photo': '', 'isEmailVerified': true}
        : Map<String, dynamic>.from(existing)..remove('password');
    await prefs.setString(_demoUserKey, jsonEncode(user));
    await prefs.setString(_accessKey, 'demo-access-${DateTime.now().millisecondsSinceEpoch}');
    await prefs.setString(_refreshKey, 'demo-refresh-${DateTime.now().millisecondsSinceEpoch}');
    return {'success': true, 'user': user};
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, bool demo) async {
    if (!demo) return _send('/api/v1/auth/register', method: 'POST', body: {'name': name, 'email': email, 'password': password});
    final prefs = await SharedPreferences.getInstance();
    final users = _readUsers(prefs);
    final cleanEmail = email.trim().toLowerCase();
    if (users.any((item) => item['email'] == cleanEmail)) throw const ApiException('Email is already registered');
    final user = {'id': 'demo-${DateTime.now().millisecondsSinceEpoch}', 'name': name.trim(), 'email': cleanEmail, 'photo': '', 'isEmailVerified': false, 'password': password};
    users.add(user);
    await prefs.setString(_demoUsersKey, jsonEncode(users));
    return {'success': true, 'message': 'Registration successful. Please log in.', 'user': Map<String, dynamic>.from(user)..remove('password')};
  }

  Future<Map<String, dynamic>> forgotPassword(String email, bool demo) async {
    if (!demo) return _send('/api/v1/auth/forgot-password', method: 'POST', body: {'email': email});
    final prefs = await SharedPreferences.getInstance();
    final otp = (100000 + Random.secure().nextInt(900000)).toString();
    await prefs.setString(_demoOtpKey, otp);
    await prefs.setString(_demoResetKey, 'demo-reset-${DateTime.now().millisecondsSinceEpoch}');
    await prefs.setString(_demoResetEmailKey, email.trim().toLowerCase());
    return {'success': true, 'message': 'Demo reset code generated', 'demoOtp': otp};
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp, bool demo) async {
    if (!demo) return _send('/api/v1/auth/verify-otp', method: 'POST', body: {'email': email, 'otp': otp});
    final prefs = await SharedPreferences.getInstance();
    if (otp != prefs.getString(_demoOtpKey)) throw const ApiException('Invalid or expired OTP');
    return {'success': true, 'resetToken': prefs.getString(_demoResetKey)};
  }

  Future<Map<String, dynamic>> resetPassword(String resetToken, String newPassword, bool demo) async {
    if (!demo) return _send('/api/v1/auth/reset-password', method: 'POST', body: {'resetToken': resetToken, 'newPassword': newPassword});
    final prefs = await SharedPreferences.getInstance();
    if (resetToken.isEmpty || resetToken != prefs.getString(_demoResetKey)) throw const ApiException('Invalid or expired reset token');
    final email = prefs.getString(_demoResetEmailKey);
    final users = _readUsers(prefs);
    for (final account in users) {
      if (account['email'] == email) account['password'] = newPassword;
    }
    await prefs.setString(_demoUsersKey, jsonEncode(users));
    await prefs.remove(_demoOtpKey);
    await prefs.remove(_demoResetKey);
    await prefs.remove(_demoResetEmailKey);
    return {'success': true, 'message': 'Password reset successful. Please log in again.'};
  }

  Future<Map<String, dynamic>> googleLogin(String idToken, bool demo) async {
    if (!demo) {
      final result = await _send('/api/v1/auth/google', method: 'POST', body: {'idToken': idToken});
      await _saveTokens(result);
      return result;
    }
    final user = {
      'id': 'demo-google-user',
      'name': 'Alex Johnson',
      'email': 'alex.johnson@gmail.com',
      'photo': '',
      'isEmailVerified': true,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_demoUserKey, jsonEncode(user));
    await prefs.setString(_accessKey, 'demo-google-access-${DateTime.now().millisecondsSinceEpoch}');
    await prefs.setString(_refreshKey, 'demo-google-refresh-${DateTime.now().millisecondsSinceEpoch}');
    return {'success': true, 'user': user};
  }

  Future<Map<String, dynamic>> logout(bool demo) async {
    if (!demo) {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString(_refreshKey);
      try {
        await _send('/api/v1/auth/logout', method: 'POST', body: {'refreshToken': refresh});
      } finally {
        await clearSession();
      }
    } else {
      await clearSession();
    }
    return {'success': true};
  }

  Future<Map<String, dynamic>> getProfile(bool demo) async {
    if (!demo) return _send('/api/v1/users/me');
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_demoUserKey);
    if (rawUser == null) throw const ApiException('Please sign in again');
    return {'success': true, 'user': jsonDecode(rawUser) as Map<String, dynamic>};
  }

  Future<Map<String, dynamic>> updateProfile(String name, String photo, bool demo) async {
    if (!demo) return _send('/api/v1/users/me', method: 'PATCH', body: {'name': name, 'photo': photo});
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_demoUserKey);
    if (rawUser == null) throw const ApiException('Please sign in again');
    final user = jsonDecode(rawUser) as Map<String, dynamic>;
    user['name'] = name.trim();
    user['photo'] = photo;
    user['updatedAt'] = DateTime.now().toIso8601String();
    await prefs.setString(_demoUserKey, jsonEncode(user));
    return {'success': true, 'message': 'Profile updated successfully', 'user': user};
  }

  Future<Map<String, dynamic>> deleteAccount(bool demo) async {
    if (!demo) return _send('/api/v1/users/me', method: 'DELETE');
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_demoUserKey);
    if (rawUser != null) {
      final user = jsonDecode(rawUser) as Map<String, dynamic>;
      final users = _readUsers(prefs)..removeWhere((item) => item['email'] == user['email']);
      await prefs.setString(_demoUsersKey, jsonEncode(users));
    }
    return {'success': true, 'message': 'Account deleted successfully'};
  }

  List<Map<String, dynamic>> _readUsers(SharedPreferences prefs) {
    final raw = prefs.getString(_demoUsersKey);
    if (raw == null) return <Map<String, dynamic>>[];
    return (jsonDecode(raw) as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}