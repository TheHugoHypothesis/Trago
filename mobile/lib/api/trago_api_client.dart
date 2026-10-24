import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account.dart';
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
  final String token;
  final http.Client _client;

  TragoApiClient({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers({String? idempotencyKey}) {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
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

  /// Verifica saúde da API (público, sem auth)
  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(_uri('/health')).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Lista contas do usuário logado (PF/PJ)
  Future<List<Account>> getAccounts() async {
    final response = await _client.get(
      _uri('/v1/me/accounts'),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => Account.fromJson(item as Map<String, dynamic>))
          .toList();
      return items;
    }
    throw ApiException.fromResponse(response.statusCode, response.body);
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
        if (destination != null && destination.isNotEmpty) 'destination': destination,
        if (departureDate != null && departureDate.isNotEmpty) 'departureDate': departureDate,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      }),
      headers: _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => Trip.fromJson(item as Map<String, dynamic>))
          .toList();
      final nextCursor = data['nextCursor'] as String?;
      return PaginatedResult(items: items, nextCursor: nextCursor);
    }
    throw ApiException.fromResponse(response.statusCode, response.body);
  }

  /// Publica nova viagem (apenas identidade dev:traveler)
  Future<Trip> createTrip(TripInput input) async {
    final response = await _client.post(
      _uri('/v1/trips'),
      headers: _headers(),
      body: jsonEncode(input.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return Trip.fromJson(data);
    }
    throw ApiException.fromResponse(response.statusCode, response.body);
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
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => PurchaseRequest.fromJson(item as Map<String, dynamic>))
          .toList();
      final nextCursor = data['nextCursor'] as String?;
      return PaginatedResult(items: items, nextCursor: nextCursor);
    }
    throw ApiException.fromResponse(response.statusCode, response.body);
  }

  /// Cria solicitação de compra em modo DRAFT com chave de idempotência
  Future<PurchaseRequest> createPurchaseRequest(
    RequestInput input,
    String idempotencyKey,
  ) async {
    final response = await _client.post(
      _uri('/v1/purchase-requests'),
      headers: _headers(idempotencyKey: idempotencyKey),
      body: jsonEncode(input.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return PurchaseRequest.fromJson(data);
    }
    throw ApiException.fromResponse(response.statusCode, response.body);
  }
}
