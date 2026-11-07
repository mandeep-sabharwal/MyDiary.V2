import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Anything that went wrong talking to a REST API, with a message fit to show.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message';
}

/// A tiny, reusable REST client: GET a URL, check the status, parse the JSON.
/// Used by the "Thought of the day" card, and ready for any other endpoint.
class ApiClient {
  /// Replaceable in tests (see test/widget_test.dart).
  static http.Client client = http.Client();

  static Future<dynamic> getJson(
    Uri url, {
    Duration timeout = const Duration(seconds: 8),
    Map<String, String>? headers,
  }) async {
    try {
      final res = await client
          .get(url, headers: {'Accept': 'application/json', ...?headers})
          .timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException('The server answered ${res.statusCode}.', statusCode: res.statusCode);
      }
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The request timed out.');
    } on SocketException {
      throw ApiException('No internet connection.');
    } on http.ClientException catch (e) {
      throw ApiException('Could not reach the server: ${e.message}');
    } on FormatException {
      throw ApiException('The server sent something unexpected.');
    }
  }
}
