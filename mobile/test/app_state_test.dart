import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trago/api/trago_api_client.dart';
import 'package:trago/models/money.dart';
import 'package:trago/models/purchase_request.dart';
import 'package:trago/models/trip.dart';
import 'package:trago/state/app_state.dart';
import 'package:trago/screens/publish_screen.dart';
import 'package:trago/screens/draft_screen.dart';
import 'package:trago/screens/incoming_requests_screen.dart';

class RecordingClient extends TragoApiClient {
  RecordingClient() : super(baseUrl: 'http://test.invalid', token: 'test');

  bool failOrder = true;
  bool failTrip = true;
  bool failUpdate = true;
  bool failCancel = true;
  bool failDecision = true;
  ApiException decisionFailure = const ApiException(
    statusCode: 503,
    code: 'UNAVAILABLE',
    message: 'API indisponível',
  );
  List<PurchaseRequest> incoming = const [];
  final keys = <String>[];
  final tripKeys = <String>[];
  Completer<void>? pauseOrder;

  @override
  Future<PurchaseRequest> createPurchaseRequest(
    RequestInput input,
    String key,
  ) async {
    keys.add(key);
    if (pauseOrder != null) await pauseOrder!.future;
    if (failOrder) {
      throw const ApiException(
        statusCode: 503,
        code: 'UNAVAILABLE',
        message: 'API indisponível',
      );
    }
    return PurchaseRequest(
      id: 'remote-order',
      accountId: input.accountId,
      tripId: input.tripId,
      product: input.product,
      status: 'PENDING',
      createdAt: '2026-10-25T12:00:00Z',
    );
  }

  @override
  Future<Trip> createTrip(TripInput input, String idempotencyKey) async {
    tripKeys.add(idempotencyKey);
    if (failTrip) {
      throw const ApiException(
        statusCode: 503,
        code: 'UNAVAILABLE',
        message: 'API indisponível',
      );
    }
    return Trip(
      id: 'remote-trip',
      travelerName: 'Viajante (exemplo)',
      origin: input.origin,
      destination: input.destination,
      departureDate: input.departureDate,
      timeZone: input.timeZone,
      availableWeightGrams: input.availableWeightGrams,
      pricePerKg: const Money(amount: '4200', currency: 'USD'),
      isDemo: true,
    );
  }

  @override
  Future<Trip> updateTrip(String tripId, TripInput input) async {
    if (failUpdate) {
      throw const ApiException(
        statusCode: 503,
        code: 'UNAVAILABLE',
        message: 'API indisponível',
      );
    }
    return Trip(
      id: tripId,
      travelerName: 'Viajante real',
      origin: input.origin,
      destination: input.destination,
      departureDate: input.departureDate,
      timeZone: input.timeZone,
      availableWeightGrams: input.availableWeightGrams,
      pricePerKg: input.pricePerKg,
      isDemo: false,
    );
  }

  @override
  Future<Trip> cancelTrip(String tripId) async {
    if (failCancel) {
      throw const ApiException(
        statusCode: 503,
        code: 'UNAVAILABLE',
        message: 'API indisponível',
      );
    }
    return Trip(
      id: tripId,
      travelerName: 'Viajante real',
      origin: 'Nova York (EUA)',
      destination: 'São Paulo (SP)',
      departureDate: '2026-12-26',
      timeZone: 'America/Sao_Paulo',
      availableWeightGrams: 8000,
      pricePerKg: const Money(amount: '4200', currency: 'USD'),
      isDemo: false,
      status: 'CANCELLED',
    );
  }

  @override
  Future<List<PurchaseRequest>> getIncomingPurchaseRequests() async => incoming;

  @override
  Future<PurchaseRequest> decidePurchaseRequest(
    String requestId, {
    required bool accept,
  }) async {
    if (failDecision) {
      throw decisionFailure;
    }
    final request = incoming.singleWhere((item) => item.id == requestId);
    final decided = PurchaseRequest(
      id: request.id,
      accountId: request.accountId,
      tripId: request.tripId,
      product: request.product,
      status: accept ? 'ACCEPTED' : 'REJECTED',
      createdAt: request.createdAt,
      updatedAt: '2026-10-25T13:00:00Z',
      tripCapacity: TripCapacity(
        totalWeightGrams: 8000,
        reservedWeightGrams: accept ? request.product.estimatedWeightGrams : 0,
        availableWeightGrams: accept
            ? 8000 - request.product.estimatedWeightGrams
            : 8000,
      ),
    );
    incoming = [decided];
    return decided;
  }
}

void main() {
  test(
    'sem modo demo explícito, criação é bloqueada sem sucesso local',
    () async {
      final state = AppState(syncOnStart: false);
      final initialCount = state.allOrders.length;
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          state.createOrder(
            description: 'Produto',
            priceUsd: 300,
            weightGrams: 800,
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'AUTHENTICATION_REQUIRED',
            ),
          ),
        );
      }
      expect(state.allOrders.length, initialCount);
      state.dispose();
    },
  );
  test('retry de A conserva chave mesmo após tentativa de B', () async {
    final client = RecordingClient();
    final state = AppState(clientFactory: (_) => client, syncOnStart: false);
    Future<PurchaseRequest> submit(String description) => state.createOrder(
      description: description,
      priceUsd: 300,
      weightGrams: 800,
    );
    await expectLater(submit('A'), throwsA(isA<ApiException>()));
    await expectLater(submit('B'), throwsA(isA<ApiException>()));
    client.failOrder = false;
    await submit('A');
    expect(client.keys[0], client.keys[2]);
    expect(client.keys[1], isNot(client.keys[0]));
    state.dispose();
  });

  test('envios simultâneos equivalentes fazem uma única chamada', () async {
    final client = RecordingClient()..failOrder = false;
    client.pauseOrder = Completer<void>();
    final state = AppState(clientFactory: (_) => client, syncOnStart: false);
    Future<PurchaseRequest> submit() =>
        state.createOrder(description: 'A', priceUsd: 300, weightGrams: 800);
    final first = submit();
    final second = submit();
    expect(client.keys, hasLength(1));
    client.pauseOrder!.complete();
    final results = await Future.wait([first, second]);
    expect(results[0].id, results[1].id);
    expect(
      state.allOrders.where((order) => order.id == 'remote-order'),
      hasLength(1),
    );
    state.dispose();
  });

  testWidgets('modal mostra envio, falha e retry sem duplicar', (tester) async {
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = RecordingClient()..pauseOrder = Completer<void>();
    final state = AppState(clientFactory: (_) => client, syncOnStart: false);
    final initialCount = state.allOrders.length;
    var navigations = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: DraftScreen(onNavigateTab: (_) => navigations++),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Revisar solicitação'), 400);
    await tester.tap(find.text('Revisar solicitação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar solicitação'));
    await tester.pump();
    expect(find.text('Enviando solicitação…'), findsOneWidget);
    client.pauseOrder!.complete();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível enviar a solicitação'),
      findsOneWidget,
    );
    expect(state.allOrders.length, initialCount);
    expect(navigations, 0);
    client.failOrder = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(client.keys[0], client.keys[1]);
    expect(state.allOrders.length, initialCount + 1);
    expect(navigations, 1);
    state.dispose();
  });
  test(
    'falha na criação não inventa pedido; retry preserva chave e não duplica',
    () async {
      final client = RecordingClient();
      final state = AppState(clientFactory: (_) => client, syncOnStart: false);
      final initialCount = state.allOrders.length;
      Future<PurchaseRequest> submit() => state.createOrder(
        description: 'Produto de teste',
        priceUsd: 300,
        weightGrams: 800,
      );

      await expectLater(submit(), throwsA(isA<ApiException>()));
      expect(state.allOrders.length, initialCount);
      client.failOrder = false;
      final created = await submit();
      expect(client.keys, hasLength(2));
      expect(client.keys[0], client.keys[1]);
      expect(created.status, 'PENDING');
      expect(
        state.allOrders.where((order) => order.id == created.id),
        hasLength(1),
      );
      state.dispose();
    },
  );

  test('falha na publicação não inventa viagem nem muda seleção', () async {
    final client = RecordingClient();
    final state = AppState(clientFactory: (_) => client, syncOnStart: false);
    final initialCount = state.trips.length;
    final initialSelected = state.selectedTrip!.id;
    Future<Trip> submit() => state.publishTrip(
      travelerName: 'Teste',
      origin: 'Nova York (EUA)',
      destination: 'São Paulo (SP)',
      departureDate: '2026-12-26',
      availableWeightKg: 8,
      pricePerKgUsd: 42,
    );

    await expectLater(submit(), throwsA(isA<ApiException>()));
    expect(state.trips.length, initialCount);
    expect(state.selectedTrip!.id, initialSelected);
    client.failTrip = false;
    final created = await submit();
    expect(client.tripKeys[0], client.tripKeys[1]);
    expect(created.id, 'remote-trip');
    expect(state.trips.length, initialCount + 1);
    expect(state.myTrips.single.id, created.id);
    state.dispose();
  });

  testWidgets('tela de publicação mostra falha e permite tentar novamente', (
    tester,
  ) async {
    final client = RecordingClient();
    final state = AppState(clientFactory: (_) => client, syncOnStart: false);
    final initialCount = state.trips.length;
    var navigations = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: PublishScreen(onNavigateTab: (_) => navigations++),
        ),
      ),
    );
    final button = find.text('Publicar oferta de bagagem');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível publicar a viagem'),
      findsOneWidget,
    );
    expect(state.trips.length, initialCount);
    expect(navigations, 0);
    expect(button, findsOneWidget);
    state.dispose();
  });

  test(
    'edição e cancelamento só alteram estado após confirmação da API',
    () async {
      final client = RecordingClient()..failTrip = false;
      final state = AppState(clientFactory: (_) => client, syncOnStart: false);
      final trip = await state.publishTrip(
        travelerName: 'Teste',
        origin: 'Nova York (EUA)',
        destination: 'São Paulo (SP)',
        departureDate: '2026-12-26',
        availableWeightKg: 8,
        pricePerKgUsd: 42,
      );
      await expectLater(
        state.updateTrip(
          trip: trip,
          origin: trip.origin,
          destination: 'Rio de Janeiro (RJ)',
          departureDate: trip.departureDate,
          availableWeightKg: 7,
          pricePerKgUsd: 40,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(state.myTrips.single.destination, trip.destination);
      await expectLater(state.cancelTrip(trip), throwsA(isA<ApiException>()));
      expect(state.myTrips.single.status, 'AVAILABLE');

      client.failUpdate = false;
      final updated = await state.updateTrip(
        trip: trip,
        origin: trip.origin,
        destination: 'Rio de Janeiro (RJ)',
        departureDate: trip.departureDate,
        availableWeightKg: 7,
        pricePerKgUsd: 40,
      );
      expect(state.myTrips.single.destination, 'Rio de Janeiro (RJ)');
      client.failCancel = false;
      final cancelled = await state.cancelTrip(updated);
      expect(cancelled.status, 'CANCELLED');
      expect(state.myTrips.single.status, 'CANCELLED');
      expect(state.trips.any((available) => available.id == trip.id), isFalse);
    },
  );

  test(
    'falha de decisão preserva pedido pendente até confirmação da API',
    () async {
      const pending = PurchaseRequest(
        id: 'incoming-1',
        accountId: 'personal-buyer',
        tripId: 'remote-trip',
        product: Product(
          description: 'Produto solicitado',
          price: Money(amount: '100', currency: 'USD'),
          estimatedWeightGrams: 500,
        ),
        status: 'PENDING',
        createdAt: '2026-10-25T12:00:00Z',
      );
      final client = RecordingClient()
        ..incoming = const [pending]
        ..failTrip = false;
      final state = AppState(clientFactory: (_) => client, syncOnStart: false);
      await state.publishTrip(
        travelerName: 'Teste',
        origin: 'Recife',
        destination: 'Lisboa',
        departureDate: '2026-12-26',
        availableWeightKg: 8,
        pricePerKgUsd: 42,
      );
      await state.refreshIncomingRequests();
      await expectLater(
        state.decidePurchaseRequest(pending, accept: true),
        throwsA(isA<ApiException>()),
      );
      expect(state.incomingRequests.single.status, 'PENDING');
      expect(state.myTrips.single.availableWeightGrams, 8000);

      client.failDecision = false;
      await state.decidePurchaseRequest(pending, accept: true);
      expect(state.incomingRequests.single.status, 'ACCEPTED');
      expect(state.myTrips.single.availableWeightGrams, 7500);
      expect(state.myTrips.single.reservedWeightGrams, 500);
      state.dispose();
    },
  );

  testWidgets(
    'capacidade insuficiente exibe erro e não confirma reserva no Flutter',
    (tester) async {
      const pending = PurchaseRequest(
        id: 'incoming-capacity',
        accountId: 'personal-buyer',
        tripId: 'remote-trip',
        product: Product(
          description: 'Produto sem espaço restante',
          price: Money(amount: '100', currency: 'USD'),
          estimatedWeightGrams: 900,
        ),
        status: 'PENDING',
        createdAt: '2026-10-25T12:00:00Z',
      );
      final client = RecordingClient()
        ..incoming = const [pending]
        ..decisionFailure = const ApiException(
          statusCode: 422,
          code: 'CAPACITY_EXCEEDED',
          message: 'Capacidade disponível insuficiente.',
        );
      final state = AppState(clientFactory: (_) => client, syncOnStart: false);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: const MaterialApp(home: IncomingRequestsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produto sem espaço restante'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceitar'));
      await tester.pumpAndSettle();
      expect(find.text('Capacidade disponível insuficiente.'), findsOneWidget);
      expect(state.incomingRequests.single.status, 'PENDING');
      state.dispose();
    },
  );
}
