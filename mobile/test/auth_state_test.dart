import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trago/api/trago_api_client.dart';
import 'package:trago/auth/session_storage.dart';
import 'package:trago/main.dart';
import 'package:trago/models/account.dart';
import 'package:trago/models/auth_session.dart';
import 'package:trago/models/purchase_request.dart';
import 'package:trago/models/trip.dart';
import 'package:trago/state/app_state.dart';

class MemorySessionStorage implements SessionStorage {
  String? token;
  int writes = 0;
  int deletes = 0;

  MemorySessionStorage([this.token]);

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async {
    token = value;
    writes++;
  }

  @override
  Future<void> deleteToken() async {
    token = null;
    deletes++;
  }
}

class FakeAuthBackend {
  static const user = AuthUser(
    id: '10000000-0000-4000-8000-000000000001',
    email: 'alice@example.invalid',
    displayName: 'Alice',
    createdAt: '2026-10-25T12:00:00.000Z',
  );

  bool rejectLogin = false;
  bool rejectSession = false;
  bool forbidAccounts = false;
  int loginCalls = 0;
  int registerCalls = 0;
  int meCalls = 0;
  int logoutCalls = 0;
  int createOrganizationCalls = 0;
  int addMemberCalls = 0;
  String? lastToken;
  String? invitedEmail;
  List<Account> accounts = const [
    Account(
      id: 'personal-real-user',
      type: 'PERSONAL',
      displayName: 'Conta pessoal de Alice',
      accessRole: 'OWNER',
    ),
  ];
  List<Trip> availableTrips = const [];
  List<Trip> ownedTrips = const [];

  TragoApiClient client(
    String? token,
    Future<void> Function()? onUnauthorized,
  ) {
    lastToken = token;
    return FakeAuthClient(this, token, onUnauthorized);
  }
}

class FakeAuthClient extends TragoApiClient {
  final FakeAuthBackend backend;
  final Future<void> Function()? unauthorized;

  FakeAuthClient(this.backend, String? token, this.unauthorized)
    : super(baseUrl: 'http://test.invalid', token: token);

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    backend.loginCalls++;
    if (backend.rejectLogin) {
      throw const ApiException(
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'Email ou senha inválidos.',
      );
    }
    return const AuthSession(
      accessToken: 'valid-login-token',
      tokenType: 'Bearer',
      expiresIn: 900,
      user: FakeAuthBackend.user,
    );
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    backend.registerCalls++;
    return const AuthSession(
      accessToken: 'valid-register-token',
      tokenType: 'Bearer',
      expiresIn: 900,
      user: FakeAuthBackend.user,
    );
  }

  @override
  Future<AuthUser> getCurrentUser() async {
    backend.meCalls++;
    if (backend.rejectSession) {
      await unauthorized?.call();
      throw const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'Sessão inválida ou expirada.',
      );
    }
    return FakeAuthBackend.user;
  }

  @override
  Future<void> logout() async {
    backend.logoutCalls++;
  }

  @override
  Future<List<Account>> getAccounts() async {
    if (backend.forbidAccounts) {
      throw const ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'Sem permissão.',
      );
    }
    return backend.accounts;
  }

  @override
  Future<List<Trip>> getMyTrips() async => backend.ownedTrips;

  @override
  Future<PaginatedResult<Trip>> searchTrips({
    String? origin,
    String? destination,
    String? departureDate,
    String? cursor,
  }) async => PaginatedResult(items: backend.availableTrips);

  @override
  Future<PaginatedResult<PurchaseRequest>> getPurchaseRequests(
    String accountId, {
    String? cursor,
  }) async => const PaginatedResult(items: []);

  @override
  Future<Account> createOrganizationAccount(String displayName) async {
    backend.createOrganizationCalls++;
    final created = Account(
      id: 'organization-real-user',
      type: 'ORGANIZATION',
      displayName: displayName,
      accessRole: 'OWNER',
    );
    backend.accounts = [...backend.accounts, created];
    return created;
  }

  @override
  Future<void> addOrganizationMember(String accountId, String email) async {
    backend.addMemberCalls++;
    backend.invitedEmail = email;
  }
}

AppState stateFor(FakeAuthBackend backend, MemorySessionStorage storage) {
  return AppState(
    apiClientFactory: backend.client,
    sessionStorage: storage,
    syncOnStart: false,
    demoModeOverride: false,
    apiBaseUrlOverride: 'http://test.invalid',
  );
}

void main() {
  test(
    'login válido persiste token e login inválido mantém estado anônimo',
    () async {
      final backend = FakeAuthBackend();
      final storage = MemorySessionStorage();
      final state = stateFor(backend, storage);
      await state.initializeSession();

      backend.rejectLogin = true;
      await expectLater(
        state.login(email: 'alice@example.invalid', password: 'wrong'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      expect(state.isAuthenticated, isFalse);
      expect(storage.token, isNull);

      backend.rejectLogin = false;
      await state.login(
        email: 'alice@example.invalid',
        password: 'long-valid-password',
      );
      expect(state.isAuthenticated, isTrue);
      expect(state.authUser?.email, 'alice@example.invalid');
      expect(storage.token, 'valid-login-token');
      expect(storage.writes, 1);
    },
  );

  test('cadastro autentica e persiste a nova sessão', () async {
    final backend = FakeAuthBackend();
    final storage = MemorySessionStorage();
    final state = stateFor(backend, storage);
    await state.initializeSession();
    await state.register(
      email: 'alice@example.invalid',
      password: 'long-valid-password',
      displayName: 'Alice',
    );
    expect(backend.registerCalls, 1);
    expect(storage.token, 'valid-register-token');
    expect(state.isAuthenticated, isTrue);
  });

  test('sessão persistida é revalidada no backend ao reiniciar', () async {
    final backend = FakeAuthBackend();
    final storage = MemorySessionStorage('saved-token');
    final state = stateFor(backend, storage);
    await state.initializeSession();
    expect(backend.meCalls, 1);
    expect(backend.lastToken, 'saved-token');
    expect(state.isAuthenticated, isTrue);
    expect(state.authUser, FakeAuthBackend.user);
  });

  test('sessão expirada ou revogada apaga token e dados privados', () async {
    final backend = FakeAuthBackend()..rejectSession = true;
    final storage = MemorySessionStorage('expired-token');
    final state = stateFor(backend, storage);
    await state.initializeSession();
    expect(state.isAuthenticated, isFalse);
    expect(storage.token, isNull);
    expect(storage.deletes, greaterThanOrEqualTo(1));
    expect(state.accounts, isEmpty);
    expect(state.allOrders, isEmpty);
    expect(state.authNotice, contains('expirou'));
  });

  test('logout revoga no backend e limpa sessão e dados locais', () async {
    final backend = FakeAuthBackend();
    final storage = MemorySessionStorage();
    final state = stateFor(backend, storage);
    await state.initializeSession();
    await state.login(
      email: 'alice@example.invalid',
      password: 'long-valid-password',
    );
    await state.syncWithBackend();
    expect(state.accounts, isNotEmpty);
    await state.logout();
    expect(backend.logoutCalls, 1);
    expect(state.isAuthenticated, isFalse);
    expect(storage.token, isNull);
    expect(state.accounts, isEmpty);
    expect(state.allOrders, isEmpty);
  });

  test(
    'alternância PF/PJ aceita apenas contas retornadas pela sessão',
    () async {
      final backend = FakeAuthBackend();
      final state = stateFor(backend, MemorySessionStorage());
      await state.initializeSession();
      await state.login(
        email: 'alice@example.invalid',
        password: 'long-valid-password',
      );
      await state.syncWithBackend();
      expect(state.selectedAccount?.id, 'personal-real-user');

      final organization = await state.createOrganizationAccount(
        'Empresa Sintética Alfa',
      );
      expect(organization.isOrganization, isTrue);
      expect(state.selectedAccount?.id, organization.id);
      state.selectAccount('account-from-another-user');
      expect(state.selectedAccount?.id, organization.id);
      state.selectAccount('personal-real-user');
      expect(state.selectedAccount?.id, 'personal-real-user');
      state.selectAccount(organization.id);
      await state.addMemberToSelectedOrganization('bob@example.invalid');
      expect(backend.createOrganizationCalls, 1);
      expect(backend.addMemberCalls, 1);
      expect(backend.invitedEmail, 'bob@example.invalid');
    },
  );

  test(
    'acesso sem autenticação é bloqueado antes de qualquer gravação',
    () async {
      final backend = FakeAuthBackend();
      final state = stateFor(backend, MemorySessionStorage());
      await state.initializeSession();
      await expectLater(
        state.createOrder(
          description: 'Produto',
          priceUsd: 300,
          weightGrams: 800,
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'AUTHENTICATION_REQUIRED',
          ),
        ),
      );
      expect(state.allOrders, isEmpty);
    },
  );

  test('modo autenticado não injeta viagens fictícias', () async {
    final backend = FakeAuthBackend();
    final state = stateFor(backend, MemorySessionStorage());
    await state.initializeSession();
    await state.login(
      email: 'alice@example.invalid',
      password: 'long-valid-password',
    );
    await state.syncWithBackend();
    expect(state.trips, isEmpty);
    expect(state.myTrips, isEmpty);
    expect(state.selectedTrip, isNull);
  });

  test('erro 403 preserva a sessão autenticada', () async {
    final backend = FakeAuthBackend()..forbidAccounts = true;
    final storage = MemorySessionStorage();
    final state = stateFor(backend, storage);
    await state.initializeSession();
    await state.login(
      email: 'alice@example.invalid',
      password: 'long-valid-password',
    );
    await state.syncWithBackend();
    expect(state.isAuthenticated, isTrue);
    expect(storage.token, 'valid-login-token');
    expect(state.syncError, 'Sem permissão.');
  });

  testWidgets('navegação exige login e a tela envia credenciais válidas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = FakeAuthBackend();
    final state = stateFor(backend, MemorySessionStorage());
    await state.initializeSession();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const TragoApp()),
    );
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Pedidos'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'alice@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'long-valid-password',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(backend.loginCalls, 1);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.textContaining('sessão autenticada'), findsOneWidget);
  });
}
