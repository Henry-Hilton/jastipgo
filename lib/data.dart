import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, dynamic>;

extension RecordValues on Json {
  int number(String key) => int.tryParse('${this[key]}') ?? 0;
  double decimal(String key) => double.tryParse('${this[key]}') ?? 0;
  String string(String key) => this[key]?.toString() ?? '';
  List<Json> rows(String key) => records(this[key]);
}

List<Json> records(dynamic value) => (value as List? ?? [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
String money(num value) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
).format(value);
String operationKey() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

const statusNames = {
  'open': 'Open trip',
  'live': 'Live trip',
  'finished': 'Trip selesai',
  'paid': 'Dibayar',
  'purchased': 'Sudah dibeli',
  'delivered': 'Dikirim / diserahkan',
  'completed': 'Selesai',
  'pending': 'Menunggu',
  'approved': 'Disetujui',
  'rejected': 'Ditolak',
};

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Session extends ChangeNotifier {
  Session({String? baseUrl, http.Client? client})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://ubaya.cloud/flutter/160423172',
          ),
      _client = client ?? http.Client();
  final String baseUrl;
  String token = '';
  String role = 'penitip';
  Json? user;
  bool get isSeller => role == 'jastiper';
  int get userId => user?.number('id') ?? 0;
  final http.Client _client;
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('session_token') ?? '';
    role = prefs.getString('active_role') == 'jastiper'
        ? 'jastiper'
        : 'penitip';
    final saved = prefs.getString('session_user');
    if (saved != null && token.isNotEmpty) {
      try {
        user = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      } catch (_) {
        await clear();
      }
    }
  }

  Future<dynamic> request(String action, [Json values = const {}]) async {
    try {
      final response = await _client
          .post(
            Uri.parse(
              '$baseUrl/${action == 'upload' ? 'uploadimage.php' : 'api.php'}',
            ),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              'X-Role': role,
            },
            body: jsonEncode({'action': action, ...values}),
          )
          .timeout(const Duration(seconds: 35));
      if (response.statusCode == 401 && token.isNotEmpty) await clear();
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw const ApiException(
          'Respons server tidak valid. Periksa alamat API dan konfigurasi PHP.',
        );
      }
      if (response.statusCode != 200 || decoded['result'] != 'success') {
        throw ApiException(
          decoded['message']?.toString() ?? 'Permintaan gagal. Coba lagi.',
        );
      }
      return decoded['data'];
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Tidak dapat terhubung. Periksa internet dan server, lalu coba lagi.',
      );
    }
  }

  Future<void> authenticate(String action, Json data) async {
    final result = await request(action, data) as Map;
    token = result['token'] as String;
    user = Map<String, dynamic>.from(result['user'] as Map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_token', token);
    await prefs.setString('session_user', jsonEncode(user));
    await prefs.setInt('user_id', userId);
    await prefs.setString('active_role', role);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    user = Map<String, dynamic>.from(await request('me') as Map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> switchRole() async {
    role = isSeller ? 'penitip' : 'jastiper';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_role', role);
    notifyListeners();
  }

  Future<void> logout() async {
    await request('logout');
    await clear();
  }

  Future<void> clear() async {
    token = '';
    user = null;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'session_token',
      'session_user',
      'user_id',
      'active_role',
    ]) {
      await prefs.remove(key);
    }
    notifyListeners();
  }

  String photo(String path) => path.isEmpty
      ? ''
      : '$baseUrl/image.php?path=${Uri.encodeQueryComponent(path)}';
  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
