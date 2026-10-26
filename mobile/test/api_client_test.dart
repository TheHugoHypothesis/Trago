import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trago/api/trago_api_client.dart';
import 'package:trago/models/money.dart';
import 'package:trago/models/purchase_request.dart';
import 'package:trago/models/trip.dart';

void main() {
  const input = RequestInput(
    accountId: 'personal-buyer',
    tripId: 'trip-ny-sp',
    product: Product(
      description: 'Produto',
      price: Money(amount: '300', currency: 'USD'),
      estimatedWeightGrams: 800,
    ),
  );

  for (final status in [400, 401, 403, 409, 422, 503]) {
    test(
      'HTTP $status preserva erro da API e envia chave de idempotência',
      () async {
        String? key;
        final client = TragoApiClient(
          baseUrl: 'http://test.invalid',
          token: 'test',
          client: MockClient((request) async {
            key = request.headers['idempotency-key'];
            return http.Response(
              '{"code":"ERROR","message":"Falha da API"}',
              status,
            );
          }),
        );
        await expectLater(
          client.createPurchaseRequest(input, 'retry-key-123'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              status,
            ),
          ),
        );
        expect(key, 'retry-key-123');
      },
    );
  }

  testWidgets('timeout retorna erro tipado', (tester) async {
    final response = Completer<http.Response>();
    final client = TragoApiClient(
      baseUrl: 'http://test.invalid',
      token: 'test',
      client: MockClient((_) => response.future),
    );
    final expectation = expectLater(
      client.createPurchaseRequest(input, 'retry-key-123'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TIMEOUT')),
    );
    await tester.pump(const Duration(seconds: 11));
    await expectation;
    response.complete(http.Response('{}', 503));
    await tester.pump();
  });

  test('falha de rede vira erro tipado sem pedido fictício', () async {
    final client = TragoApiClient(
      baseUrl: 'http://test.invalid',
      token: 'test',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      client.createPurchaseRequest(input, 'retry-key-123'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR'),
      ),
    );
  });

  test(
    'login e cadastro usam endpoints públicos e interpretam a sessão',
    () async {
      final requests = <http.Request>[];
      final client = TragoApiClient(
        baseUrl: 'http://test.invalid',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"accessToken":"jwt-token","tokenType":"Bearer","expiresIn":900,'
            '"user":{"id":"10000000-0000-4000-8000-000000000001",'
            '"email":"alice@example.invalid","displayName":"Alice",'
            '"createdAt":"2026-10-25T12:00:00.000Z"}}',
            request.url.path.endsWith('/register') ? 201 : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final login = await client.login(
        email: 'alice@example.invalid',
        password: 'long-valid-password',
      );
      final registration = await client.register(
        email: 'alice@example.invalid',
        password: 'long-valid-password',
        displayName: 'Alice',
      );
      expect(login.accessToken, 'jwt-token');
      expect(registration.user.displayName, 'Alice');
      expect(requests.map((request) => request.url.path), [
        '/v1/auth/login',
        '/v1/auth/register',
      ]);
      expect(
        requests.every(
          (request) => !request.headers.containsKey('authorization'),
        ),
        isTrue,
      );
    },
  );

  test('requisição protegida envia JWT e 401 notifica expiração', () async {
    var unauthorized = 0;
    String? authorization;
    final client = TragoApiClient(
      baseUrl: 'http://test.invalid',
      token: 'jwt-token',
      onUnauthorized: () async => unauthorized++,
      client: MockClient((request) async {
        authorization = request.headers['authorization'];
        return http.Response(
          '{"code":"UNAUTHENTICATED","message":"Sessão inválida ou expirada."}',
          401,
        );
      }),
    );
    await expectLater(client.getCurrentUser(), throwsA(isA<ApiException>()));
    expect(authorization, 'Bearer jwt-token');
    expect(unauthorized, 1);
  });

  test('criação e associação PJ enviam JWT e dados esperados', () async {
    final requests = <http.Request>[];
    final client = TragoApiClient(
      baseUrl: 'http://test.invalid',
      token: 'jwt-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/members')) {
          return http.Response('', 204);
        }
        return http.Response(
          '{"id":"organization-real-user","type":"ORGANIZATION",'
          '"displayName":"Empresa Sintética Alfa","accessRole":"OWNER"}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final account = await client.createOrganizationAccount(
      'Empresa Sintética Alfa',
    );
    await client.addOrganizationMember(
      account.id,
      'bob+member@example.invalid',
    );
    expect(account.canManageMembers, isTrue);
    expect(requests.map((request) => request.url.path), [
      '/v1/me/accounts/organizations',
      '/v1/me/accounts/organization-real-user/members',
    ]);
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer jwt-token',
      ),
      isTrue,
    );
    expect(requests[0].body, contains('Empresa Sintética Alfa'));
    expect(requests[1].body, contains('bob+member@example.invalid'));
  });

  test('gestão de viagens usa rotas reais, JWT e idempotência', () async {
    final requests = <http.Request>[];
    const tripJson =
        '{"id":"trip-real","travelerName":"Alice","origin":"Recife",'
        '"destination":"Lisboa","departureDate":"2026-12-20",'
        '"timeZone":"UTC","availableWeightGrams":3000,'
        '"pricePerKg":{"amount":"100","currency":"USD"},'
        '"isDemo":false,"status":"AVAILABLE"}';
    final client = TragoApiClient(
      baseUrl: 'http://test.invalid',
      token: 'jwt-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/v1/me/trips') {
          return http.Response('{"items":[$tripJson]}', 200);
        }
        return http.Response(
          tripJson,
          request.method == 'POST' && request.url.path == '/v1/trips'
              ? 201
              : 200,
        );
      }),
    );
    const tripInput = TripInput(
      origin: 'Recife',
      destination: 'Lisboa',
      departureDate: '2026-12-20',
      timeZone: 'UTC',
      availableWeightGrams: 3000,
      pricePerKg: Money(amount: '100', currency: 'USD'),
    );
    final created = await client.createTrip(tripInput, 'trip-key-123');
    final own = await client.getMyTrips();
    await client.getTrip(created.id);
    await client.updateTrip(created.id, tripInput);
    await client.cancelTrip(created.id);
    expect(own.single.id, created.id);
    expect(requests.map((request) => '${request.method} ${request.url.path}'), [
      'POST /v1/trips',
      'GET /v1/me/trips',
      'GET /v1/trips/trip-real',
      'PATCH /v1/trips/trip-real',
      'POST /v1/trips/trip-real/cancel',
    ]);
    expect(requests.first.headers['idempotency-key'], 'trip-key-123');
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer jwt-token',
      ),
      isTrue,
    );
  });

  test(
    'caixa de entrada, detalhe e decisões usam rotas autenticadas',
    () async {
      final requests = <http.Request>[];
      const requestJson =
          '{"id":"request-real","accountId":"account-real",'
          '"tripId":"trip-real","product":{"description":"Produto",'
          '"price":{"amount":"100","currency":"USD"},'
          '"estimatedWeightGrams":500},"status":"PENDING",'
          '"createdAt":"2026-10-25T12:00:00Z"}';
      final client = TragoApiClient(
        baseUrl: 'http://test.invalid',
        token: 'jwt-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/v1/me/incoming-requests') {
            return http.Response('{"items":[$requestJson]}', 200);
          }
          final status = request.url.path.endsWith('/accept')
              ? 'ACCEPTED'
              : request.url.path.endsWith('/reject')
              ? 'REJECTED'
              : 'PENDING';
          var body = requestJson.replaceFirst('PENDING', status);
          if (request.url.path.endsWith('/accept')) {
            body =
                '${body.substring(0, body.length - 1)},'
                '"tripCapacity":{"totalWeightGrams":1000,'
                '"reservedWeightGrams":500,"availableWeightGrams":500}}';
          }
          return http.Response(body, 200);
        }),
      );
      expect(
        (await client.getIncomingPurchaseRequests()).single.isPending,
        isTrue,
      );
      expect(
        (await client.getPurchaseRequest('request-real')).id,
        'request-real',
      );
      final accepted = await client.decidePurchaseRequest(
        'request-real',
        accept: true,
      );
      expect(accepted.status, 'ACCEPTED');
      expect(accepted.tripCapacity?.availableWeightGrams, 500);
      expect(
        (await client.decidePurchaseRequest(
          'request-real',
          accept: false,
        )).status,
        'REJECTED',
      );
      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'GET /v1/me/incoming-requests',
          'GET /v1/purchase-requests/request-real',
          'POST /v1/purchase-requests/request-real/accept',
          'POST /v1/purchase-requests/request-real/reject',
        ],
      );
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer jwt-token',
        ),
        isTrue,
      );
    },
  );
}
