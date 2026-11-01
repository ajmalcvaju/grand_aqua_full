import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final dioProvider = Provider<Dio>((ref) => ApiClient().dio);

class ApiClient {
  static const String defaultUrl = 'http://192.168.29.44:4000/api/v1';

  final Dio dio = Dio(
    BaseOptions(
      baseUrl: defaultUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static String normalizeUrl(String raw) {
    var clean = raw.trim();
    if (clean.isEmpty) return defaultUrl;

    // Ignore old dead tunnels
    if (clean.contains('trycloudflare.com')) {
      return defaultUrl;
    }

    // Prepend http:// if missing scheme
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }

    // Strip trailing slashes
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }

    // If port 4000 is missing from LAN IP, add it
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.host.startsWith('192.168.') && uri.port == 80) {
      clean = '${uri.scheme}://${uri.host}:4000${uri.path}';
      while (clean.endsWith('/')) {
        clean = clean.substring(0, clean.length - 1);
      }
    }

    // Ensure /api/v1 is present
    if (!clean.endsWith('/api/v1')) {
      clean = '$clean/api/v1';
    }

    return clean;
  }

  ApiClient() {
    _initUrl();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final customUrl = prefs.getString('custom_backend_url');
          if (customUrl != null && customUrl.trim().isNotEmpty) {
            options.baseUrl = normalizeUrl(customUrl);
          } else {
            options.baseUrl = defaultUrl;
          }

          final token = prefs.getString('buyer_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<void> _initUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_backend_url');
    if (customUrl != null && customUrl.contains('trycloudflare.com')) {
      await prefs.remove('custom_backend_url');
      dio.options.baseUrl = defaultUrl;
      return;
    }
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      dio.options.baseUrl = normalizeUrl(customUrl);
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = normalizeUrl(newUrl);
    await prefs.setString('custom_backend_url', normalized);
    dio.options.baseUrl = normalized;
  }
}
