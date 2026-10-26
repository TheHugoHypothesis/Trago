import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account.dart';
import '../models/auth_session.dart';
import '../models/trip.dart';
import '../models/purchase_request.dart';

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final String? correlationId;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.correlationId,
  });

  factory ApiException.fromResponse(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return ApiException(
        statusCode: statusCode,
        code: json['code'] as String? ?? 'ERROR_$statusCode',
        message: json['message'] as String? ?? 'Ocorreu um erro inesperado.',
        correlationId: json['correlationId'] as String?,
      );
    } catch (_) {
      return ApiException(
        statusCode: statusCode,
        code: 'HTTP_$statusCode',
        message: body.isNotEmpty ? body : 'Erro HTTP $statusCode',
      );
    }
  }

  @override
  String toString() => message;
}

class PaginatedResult<T> {
  final List<T> items;
  final String? nextCursor;

  const PaginatedResult({required this.items, this.nextCursor});
}

class TragoApiClient {
  final String baseUrl;
  final String? token;
  final http.Client _client;
  final Future<void> Function()? onUnauthorized;

  TragoApiClient({
    required this.baseUrl,
    this.token,
    http.Client? client,
    this.onUnauthorized,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers({String? idempotencyKey}) {
    final accessToken = token;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        code: 'AUTHENTICATION_REQUIRED',
        message: 'Entre na sua conta para continuar.',
      );
    }
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Map<String, String> get _publicHeaders => const {
    'Content-Type': 'application/json',
  };

  Future<Never> _throwResponse(http.Response response) async {
    final error = ApiException.fromResponse(response.statusCode, response.body);
    if (response.statusCode == 401 && token != null) {
      await onUnauthorized?.call();
    }
    throw error;
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$cleanBase$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final filtered = <String, String>{};
      queryParameters.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          filtered[k] = v.toString();
        }
      });
      return uri.replace(queryParameters: filtered);
    }
    return uri;
  }

  Future<http.Response> _write(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ApiException(
        statusCode: 0,
        code: 'TIMEOUT',
        message: 'A API demorou a responder. Tente novamente.',
      );
    } on http.ClientException {
      throw const ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Não foi possível conectar à API. Verifique a rede.',
      );
    }
  }

  /// Verifica saúde da API (público, sem auth)
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(_uri('/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _write(
      () => _client.post(
        _uri('/v1/auth/register'),
        headers: _publicHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
          'displayName': displayName,
        }),
      ),
    );
    if (response.statusCode == 201) {
      return AuthSession.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _write(
      () => _client.post(
        _uri('/v1/auth/login'),
        headers: _publicHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    if (response.statusCode == 200) {
      return AuthSession.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }

  Future<AuthUser> getCurrentUser() async {
    final response = await _write(
      () => _client.get(_uri('/v1/auth/me'), headers: _headers()),
    );
    if (response.statusCode == 200) {
      return AuthUser.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }

  Future<void> logout() async {
    final response = await _write(
      () => _client.post(_uri('/v1/auth/logout'), headers: _headers()),
    );
    if (response.statusCode == 204) return;
    await _throwResponse(response);
  }

  /// Lista contas do usuário logado (PF/PJ)
  Future<List<Account>> getAccounts() async {
    final response = await _client.get(
      _uri('/v1/me/accounts'),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => Account.fromJson(item as Map<String, dynamic>))
          .toList();
      return items;
    }
    return _throwResponse(response);
  }

  Future<Account> createOrganizationAccount(String displayName) async {
    final response = await _write(
      () => _client.post(
        _uri('/v1/me/accounts/organizations'),
        headers: _headers(),
        body: jsonEncode({'displayName': displayName}),
      ),
    );
    if (response.statusCode == 201) {
      return Account.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }

  Future<void> addOrganizationMember(String accountId, String email) async {
    final response = await _write(
      () => _client.post(
        _uri('/v1/me/accounts/${Uri.encodeComponent(accountId)}/members'),
        headers: _headers(),
        body: jsonEncode({'email': email}),
      ),
    );
    if (response.statusCode == 204) return;
    await _throwResponse(response);
  }

  /// Busca viagens com filtros opcionais e paginação por cursor
  Future<PaginatedResult<Trip>> searchTrips({
    String? origin,
    String? destination,
    String? departureDate,
    String? cursor,
  }) async {
    final response = await _client.get(
      _uri('/v1/trips', {
        if (origin != null && origin.isNotEmpty) 'origin': origin,
        if (destination != null && destination.isNotEmpty)
          'destination': destination,
        if (departureDate != null && departureDate.isNotEmpty)
          'departureDate': departureDate,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      }),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => Trip.fromJson(item as Map<String, dynamic>))
          .toList();
      final nextCursor = data['nextCursor'] as String?;
      return PaginatedResult(items: items, nextCursor: nextCursor);
    }
    return _throwResponse(response);
  }

  /// Publica nova viagem para a identidade autenticada.
  Future<Trip> createTrip(TripInput input, String idempotencyKey) async {
    final response = await _write(
      () => _client.post(
        _uri('/v1/trips'),
        headers: _headers(idempotencyKey: idempotencyKey),
        body: jsonEncode(input.toJson()),
      ),
    );

    if (response.statusCode == 201) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return Trip.fromJson(data);
    }
    return _throwResponse(response);
  }

  Future<List<Trip>> getMyTrips() async {
    final response = await _client.get(
      _uri('/v1/me/trips'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (data['items'] as List<dynamic>? ?? [])
          .map((item) => Trip.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return _throwResponse(response);
  }

  Future<Trip> getTrip(String tripId) async {
    final response = await _client.get(
      _uri('/v1/trips/${Uri.encodeComponent(tripId)}'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return Trip.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }

  Future<Trip> updateTrip(String tripId, TripInput input) async {
    final response = await _write(
      () => _client.patch(
        _uri('/v1/trips/${Uri.encodeComponent(tripId)}'),
        headers: _headers(),
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode == 200) {
      return Trip.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }

  Future<Trip> cancelTrip(String tripId) async {
    final response = await _write(
      () => _client.post(
        _uri('/v1/trips/${Uri.encodeComponent(tripId)}/cancel'),
        headers: _headers(),
      ),
    );
    if (response.statusCode == 200) {
      return Trip.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }

  /// Lista solicitações de compra privadas de uma conta
  Future<PaginatedResult<PurchaseRequest>> getPurchaseRequests(
    String accountId, {
    String? cursor,
  }) async {
    final response = await _client.get(
      _uri('/v1/purchase-requests', {
        'accountId': accountId,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      }),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => PurchaseRequest.fromJson(item as Map<String, dynamic>))
          .toList();
      final nextCursor = data['nextCursor'] as String?;
      return PaginatedResult(items: items, nextCursor: nextCursor);
    }
    return _throwResponse(response);
  }

  /// Cria solicitação pendente com chave de idempotência.
  Future<PurchaseRequest> createPurchaseRequest(
    RequestInput input,
    String idempotencyKey,
  ) async {
    final response = await _write(
      () => _client.post(
        _uri('/v1/purchase-requests'),
        headers: _headers(idempotencyKey: idempotencyKey),
        body: jsonEncode(input.toJson()),
      ),
    );

    if (response.statusCode == 201) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return PurchaseRequest.fromJson(data);
    }
    return _throwResponse(response);
  }

  Future<List<PurchaseRequest>> getIncomingPurchaseRequests() async {
    final response = await _client.get(
      _uri('/v1/me/incoming-requests'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (data['items'] as List<dynamic>? ?? [])
          .map((item) => PurchaseRequest.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return _throwResponse(response);
  }

  Future<PurchaseRequest> getPurchaseRequest(String requestId) async {
    final response = await _client.get(
      _uri('/v1/purchase-requests/${Uri.encodeComponent(requestId)}'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      return PurchaseRequest.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }

  Future<PurchaseRequest> decidePurchaseRequest(
    String requestId, {
    required bool accept,
  }) async {
    final action = accept ? 'accept' : 'reject';
    final response = await _write(
      () => _client.post(
        _uri('/v1/purchase-requests/${Uri.encodeComponent(requestId)}/$action'),
        headers: _headers(),
      ),
    );
    if (response.statusCode == 200) {
      return PurchaseRequest.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    return _throwResponse(response);
  }
}
