import 'dart:convert';
import 'dart:io';

class OrgResponse {
  final int status;
  final Map<String, dynamic> body;

  const OrgResponse(this.status, this.body);

  bool get ok => status >= 200 && status < 300;
}

/// Paths are absolute and start with `/services`.
abstract class Org {
  Future<OrgResponse> get(String path);
  Future<OrgResponse> post(String path, Map<String, dynamic> body);
}

/// Over `dart:io`, because there is no `sf` CLI at install time.
class HttpOrg implements Org {
  final String instanceUrl;
  final String accessToken;
  final HttpClient _client;

  HttpOrg({
    required this.instanceUrl,
    required this.accessToken,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  @override
  Future<OrgResponse> get(String path) => _send('GET', path, null);

  @override
  Future<OrgResponse> post(String path, Map<String, dynamic> body) =>
      _send('POST', path, body);

  Future<OrgResponse> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final request = await _client.openUrl(
      method,
      Uri.parse('$instanceUrl$path'),
    );
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
      ..set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return OrgResponse(response.statusCode, _asObject(text));
  }

  /// Salesforce answers errors with an array of them and successes with an object, and a gateway
  /// in front of it answers with HTML. The caller wants one shape.
  static Map<String, dynamic> _asObject(String text) {
    if (text.isEmpty) return const {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'errors': decoded};
    } on FormatException {
      return {'body': text};
    }
  }

  void close() => _client.close();
}
