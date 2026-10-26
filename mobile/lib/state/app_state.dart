import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../auth/session_storage.dart';
import '../api/public_integrations_service.dart';
import '../api/trago_api_client.dart';
import '../models/account.dart';
import '../models/auth_session.dart';
import '../models/catalog_product.dart';
import '../models/money.dart';
import '../models/purchase_request.dart';
import '../models/trip.dart';

typedef ApiClientFactory =
    TragoApiClient Function(
      String? token,
      Future<void> Function()? onUnauthorized,
    );

class AppState extends ChangeNotifier {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const bool demoMode = bool.fromEnvironment('TRAGO_DEMO_MODE');
  final TragoApiClient Function(String actor)? clientFactory;
  final ApiClientFactory? apiClientFactory;
  final SessionStorage sessionStorage;
  final bool _demoMode;
  final String _apiBaseUrl;
  final bool _syncOnStart;

  List<Account> _accounts = const [];

  Account? _selectedAccount;
  List<Trip> _trips = const [];
  List<Trip> _myTrips = const [];
  Trip? _selectedTrip;
  CatalogProduct _selectedCatalogProduct = kCuratedCatalog.first;
  LiveMarketData _marketData = LiveMarketData.fallback;

  List<PurchaseRequest> _orders = [
    const PurchaseRequest(
      id: 'ord-xm5-demo',
      accountId: 'personal-buyer',
      tripId: 'trip-ny-sp',
      product: Product(
        description: 'Fone de ouvido sem fio WH-1000XM5',
        url: 'https://www.amazon.com/dp/B09XS7JWHH',
        price: Money(amount: '300', currency: 'USD'),
        estimatedWeightGrams: 800,
      ),
      status: 'PENDING',
      createdAt: '2026-10-22T14:30:00Z',
    ),
  ];
  List<PurchaseRequest> _incomingRequests = const [];

  bool _isSyncing = false;
  bool _authInitialized = false;
  bool _authBusy = false;
  String? _accessToken;
  AuthUser? _authUser;
  String? _authNotice;
  String? _syncError;
  Future<void>? _initialization;
  Future<void>? _clearingSession;

  AppState({
    this.clientFactory,
    this.apiClientFactory,
    SessionStorage? sessionStorage,
    bool syncOnStart = true,
    bool? demoModeOverride,
    String? apiBaseUrlOverride,
  }) : sessionStorage = sessionStorage ?? const SecureSessionStorage(),
       _demoMode = demoModeOverride ?? demoMode,
       _apiBaseUrl = apiBaseUrlOverride ?? apiBaseUrl,
       _syncOnStart = syncOnStart {
    if (_usesDemoFixtures) {
      _accounts = _demoAccounts;
      _trips = List<Trip>.from(kFeaturedTravelerTrips);
    }
    _selectedAccount = _accounts.firstOrNull;
    _selectedTrip = _trips.firstOrNull;
    if (_demoMode) {
      _authInitialized = true;
      if (_syncOnStart && _apiBaseUrl.isNotEmpty) unawaited(syncWithBackend());
    }
  }

  List<Account> get accounts => _accounts;
  Account? get selectedAccount => _selectedAccount;
  List<Trip> get trips => _trips;
  List<Trip> get myTrips => _myTrips;
  Trip? get selectedTrip => _selectedTrip;
  CatalogProduct get selectedCatalogProduct => _selectedCatalogProduct;
  LiveMarketData get marketData => _marketData;
  bool get isSyncing => _isSyncing;
  bool get authInitialized => _authInitialized;
  bool get authBusy => _authBusy;
  bool get isDemoMode => _demoMode;
  bool get isAuthenticated =>
      _demoMode || (_accessToken != null && _authUser != null);
  AuthUser? get authUser => _authUser;
  String? get authNotice => _authNotice;
  String? get syncError => _syncError;
  bool get _usesDemoFixtures => _demoMode || clientFactory != null;

  static const List<Account> _demoAccounts = [
    Account(
      id: 'personal-buyer',
      type: 'PERSONAL',
      displayName: 'Minha Conta Pessoal',
    ),
    Account(
      id: 'company-demo',
      type: 'ORGANIZATION',
      displayName: 'Trago Tech Importadora LTDA',
      taxId: '12.345.678/0001-95',
    ),
  ];

  List<PurchaseRequest> get ordersForCurrentAccount {
    final account = _selectedAccount;
    if (account == null) return const [];
    return _orders.where((o) => o.accountId == account.id).toList();
  }

  List<PurchaseRequest> get allOrders => _orders;
  List<PurchaseRequest> get incomingRequests => _incomingRequests;

  Future<void> initializeSession() {
    return _initialization ??= _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (_demoMode) return;
    String? token;
    try {
      token = await sessionStorage.readToken();
      if (token == null || token.isEmpty) {
        _clearPrivateData();
        return;
      }
    } catch (_) {
      _authNotice =
          'Não foi possível acessar o armazenamento seguro. Entre novamente.';
      _clearPrivateData();
      return;
    } finally {
      if (token == null || token.isEmpty) {
        _authInitialized = true;
        notifyListeners();
      }
    }
    try {
      final user = await _newApiClient(
        token,
        _handleUnauthorized,
      ).getCurrentUser();
      _accessToken = token;
      _authUser = user;
      _clearPrivateData(keepSession: true);
      if (_syncOnStart) unawaited(syncWithBackend());
    } on ApiException catch (error) {
      if (error.statusCode != 401) {
        _authNotice =
            'Não foi possível validar a sessão salva. Entre novamente.';
        _clearPrivateData();
      }
    } catch (_) {
      _authNotice =
          'Não foi possível validar a sessão salva. Verifique a conexão e entre novamente.';
      _clearPrivateData();
    } finally {
      _authInitialized = true;
      notifyListeners();
    }
  }

  TragoApiClient _newApiClient(
    String? token,
    Future<void> Function()? onUnauthorized,
  ) {
    if (apiClientFactory != null) {
      return apiClientFactory!(token, onUnauthorized);
    }
    final uri = Uri.tryParse(_apiBaseUrl);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        code: 'API_NOT_CONFIGURED',
        message: 'A API não está configurada nesta instalação.',
      );
    }
    return TragoApiClient(
      baseUrl: _apiBaseUrl,
      token: token,
      onUnauthorized: onUnauthorized,
    );
  }

  TragoApiClient _clientForRequest({required String demoActor}) {
    if (!_demoMode && clientFactory == null) {
      final token = _accessToken;
      if (token == null || _authUser == null) {
        throw const ApiException(
          statusCode: 401,
          code: 'AUTHENTICATION_REQUIRED',
          message: 'Entre na sua conta para continuar.',
        );
      }
      return _newApiClient(token, _handleUnauthorized);
    }
    if (kReleaseMode) {
      throw const ApiException(
        statusCode: 0,
        code: 'DEMO_DISABLED_IN_RELEASE',
        message: 'A API de demonstração está desativada nesta versão.',
      );
    }
    if (clientFactory != null) return clientFactory!(demoActor);
    final uri = Uri.tryParse(_apiBaseUrl);
    if (!_demoMode ||
        uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        code: 'DEMO_NOT_CONFIGURED',
        message:
            'API de demonstração não configurada. Informe API_BASE_URL e TRAGO_DEMO_MODE=true.',
      );
    }
    return TragoApiClient(baseUrl: _apiBaseUrl, token: 'dev:$demoActor');
  }

  Future<void> login({required String email, required String password}) async {
    await _authenticate(
      () => _newApiClient(
        null,
        null,
      ).login(email: email.trim(), password: password),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _authenticate(
      () => _newApiClient(null, null).register(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
      ),
    );
  }

  Future<void> _authenticate(Future<AuthSession> Function() request) async {
    if (_demoMode) return;
    _authBusy = true;
    _authNotice = null;
    notifyListeners();
    try {
      final session = await request();
      try {
        await sessionStorage.writeToken(session.accessToken);
      } catch (_) {
        try {
          await _newApiClient(session.accessToken, null).logout();
        } catch (_) {}
        throw const ApiException(
          statusCode: 0,
          code: 'SECURE_STORAGE_UNAVAILABLE',
          message:
              'Não foi possível guardar a sessão com segurança neste dispositivo.',
        );
      }
      _accessToken = session.accessToken;
      _authUser = session.user;
      _clearPrivateData(keepSession: true);
      if (_syncOnStart) unawaited(syncWithBackend());
    } finally {
      _authBusy = false;
      _authInitialized = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_demoMode) return;
    _authBusy = true;
    notifyListeners();
    final token = _accessToken;
    ApiException? remoteError;
    try {
      if (token != null) await _newApiClient(token, null).logout();
    } on ApiException catch (error) {
      if (error.statusCode != 401) remoteError = error;
    } finally {
      await _clearSession(
        notice: remoteError == null
            ? null
            : 'Sessão removida deste dispositivo; a API não confirmou a revogação.',
      );
      _authBusy = false;
      notifyListeners();
    }
  }

  Future<void> _handleUnauthorized() {
    return _clearSession(
      notice: 'Sua sessão expirou ou foi revogada. Entre novamente.',
    );
  }

  Future<void> _clearSession({String? notice}) {
    return _clearingSession ??= () async {
      await _deleteStoredToken();
      _accessToken = null;
      _authUser = null;
      _authNotice = notice;
      _clearPrivateData();
      notifyListeners();
      _clearingSession = null;
    }();
  }

  Future<void> _deleteStoredToken() async {
    try {
      await sessionStorage.deleteToken();
    } catch (_) {}
  }

  void _clearPrivateData({bool keepSession = false}) {
    _accounts = _usesDemoFixtures ? _demoAccounts : const [];
    _selectedAccount = _accounts.firstOrNull;
    _trips = _usesDemoFixtures
        ? List<Trip>.from(kFeaturedTravelerTrips)
        : const [];
    _myTrips = const [];
    _selectedTrip = _trips.firstOrNull;
    _orders = _demoMode
        ? [
            const PurchaseRequest(
              id: 'ord-xm5-demo',
              accountId: 'personal-buyer',
              tripId: 'trip-ny-sp',
              product: Product(
                description: 'Fone de ouvido sem fio WH-1000XM5',
                url: 'https://www.amazon.com/dp/B09XS7JWHH',
                price: Money(amount: '300', currency: 'USD'),
                estimatedWeightGrams: 800,
              ),
              status: 'PENDING',
              createdAt: '2026-10-22T14:30:00Z',
            ),
          ]
        : [];
    _incomingRequests = const [];
    _pendingOrderKeys.clear();
    _orderSubmissions.clear();
    _pendingTripKeys.clear();
    _tripSubmissions.clear();
    if (!keepSession) {
      _accessToken = null;
      _authUser = null;
    }
  }

  final _pendingOrderKeys = <String, String>{};
  final _orderSubmissions = <String, Future<PurchaseRequest>>{};
  final _pendingTripKeys = <String, String>{};
  final _tripSubmissions = <String, Future<Trip>>{};

  Future<void> syncWithBackend() async {
    if (!_demoMode && !isAuthenticated) return;
    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      // Atualiza dados de APIs públicas (Câmbio USD/BRL + Clima de aeroportos)
      _marketData = await PublicIntegrationsService.fetchLiveMarketData();
    } catch (_) {}

    try {
      final buyerClient = _clientForRequest(demoActor: 'buyer');
      final remoteAccounts = await buyerClient.getAccounts();
      if (remoteAccounts.isNotEmpty || !_demoMode) {
        _accounts = remoteAccounts;
        if (!_accounts.any((a) => a.id == _selectedAccount?.id)) {
          _selectedAccount = _accounts.firstOrNull;
        }
      }

      final remoteTrips = await buyerClient.searchTrips();
      if (_demoMode && remoteTrips.items.isNotEmpty) {
        final merged = <String, Trip>{};
        for (final t in remoteTrips.items) {
          merged[t.id] = t;
        }
        for (final t in kFeaturedTravelerTrips) {
          merged.putIfAbsent(t.id, () => t);
        }
        _trips = merged.values.toList();
      } else if (!_demoMode) {
        _trips = remoteTrips.items;
      }
      if (!_trips.any((trip) => trip.id == _selectedTrip?.id)) {
        _selectedTrip = _trips.firstOrNull;
      }

      final travelerClient = _clientForRequest(demoActor: 'traveler');
      _myTrips = await travelerClient.getMyTrips();
      _incomingRequests = await travelerClient.getIncomingPurchaseRequests();

      final account = _selectedAccount;
      if (account != null) {
        final remoteOrders = await buyerClient.getPurchaseRequests(account.id);
        if (remoteOrders.items.isNotEmpty || !_demoMode) {
          final mergedOrders = <String, PurchaseRequest>{};
          for (final o in remoteOrders.items) {
            mergedOrders[o.id] = o;
          }
          for (final o in _orders) {
            mergedOrders.putIfAbsent(o.id, () => o);
          }
          _orders = mergedOrders.values.toList();
        }
      } else {
        _orders = [];
      }
    } on ApiException catch (error) {
      _syncError = error.message;
    } catch (_) {
      _syncError = 'Não foi possível atualizar os dados agora.';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void selectAccount(String accountId) {
    final found = _accounts.where((a) => a.id == accountId).firstOrNull;
    if (found != null) {
      _selectedAccount = found;
      notifyListeners();
      syncWithBackend();
    }
  }

  Future<Account> createOrganizationAccount(String displayName) async {
    final name = displayName.trim();
    if (name.length < 2) {
      throw const ApiException(
        statusCode: 400,
        code: 'INVALID_INPUT',
        message: 'Informe um nome com pelo menos 2 caracteres.',
      );
    }
    final created = await _clientForRequest(
      demoActor: 'buyer',
    ).createOrganizationAccount(name);
    _accounts = [
      ..._accounts.where((account) => account.id != created.id),
      created,
    ];
    _selectedAccount = created;
    _orders = [];
    notifyListeners();
    return created;
  }

  Future<void> addMemberToSelectedOrganization(String email) async {
    final account = _selectedAccount;
    if (account == null || !account.canManageMembers) {
      throw const ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message:
            'Somente o titular da conta empresarial pode autorizar membros.',
      );
    }
    final normalized = email.trim();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw const ApiException(
        statusCode: 400,
        code: 'INVALID_INPUT',
        message: 'Informe um email válido.',
      );
    }
    await _clientForRequest(
      demoActor: 'buyer',
    ).addOrganizationMember(account.id, normalized);
  }

  void selectTrip(Trip trip) {
    _selectedTrip = trip;
    notifyListeners();
  }

  Future<void> refreshAvailableTrips() async {
    final result = await _clientForRequest(demoActor: 'buyer').searchTrips();
    if (_demoMode) {
      final merged = <String, Trip>{
        for (final trip in result.items) trip.id: trip,
      };
      for (final trip in kFeaturedTravelerTrips) {
        merged.putIfAbsent(trip.id, () => trip);
      }
      _trips = merged.values.toList();
    } else {
      _trips = result.items;
    }
    if (!_trips.any((trip) => trip.id == _selectedTrip?.id)) {
      _selectedTrip = _trips.firstOrNull;
    }
    notifyListeners();
  }

  Future<void> refreshMyTrips() async {
    _myTrips = await _clientForRequest(demoActor: 'traveler').getMyTrips();
    notifyListeners();
  }

  Future<void> refreshIncomingRequests() async {
    final refreshed = await _clientForRequest(
      demoActor: 'traveler',
    ).getIncomingPurchaseRequests();
    _incomingRequests = refreshed;
    notifyListeners();
  }

  Future<PurchaseRequest> loadPurchaseRequestDetails(String requestId) {
    return _clientForRequest(
      demoActor: 'traveler',
    ).getPurchaseRequest(requestId);
  }

  Future<PurchaseRequest> decidePurchaseRequest(
    PurchaseRequest request, {
    required bool accept,
  }) async {
    final decided = await _clientForRequest(
      demoActor: 'traveler',
    ).decidePurchaseRequest(request.id, accept: accept);
    _incomingRequests = [
      for (final item in _incomingRequests)
        if (item.id == decided.id) decided else item,
    ];
    _orders = [
      for (final item in _orders)
        if (item.id == decided.id) decided else item,
    ];
    final capacity = decided.tripCapacity;
    if (capacity != null) {
      Trip apply(Trip trip) => trip.id == decided.tripId
          ? trip.withCapacity(
              totalWeightGrams: capacity.totalWeightGrams,
              reservedWeightGrams: capacity.reservedWeightGrams,
              availableWeightGrams: capacity.availableWeightGrams,
            )
          : trip;
      _myTrips = _myTrips.map(apply).toList();
      _trips = _trips.map(apply).toList();
      if (_selectedTrip?.id == decided.tripId) {
        _selectedTrip = apply(_selectedTrip!);
      }
    }
    notifyListeners();
    return decided;
  }

  Future<Trip> loadTripDetails(String tripId) async {
    if (_demoMode) {
      final local = _trips.where((trip) => trip.id == tripId).firstOrNull;
      if (local != null) {
        _selectedTrip = local;
        notifyListeners();
        return local;
      }
    }
    final detailed = await _clientForRequest(
      demoActor: 'buyer',
    ).getTrip(tripId);
    _selectedTrip = detailed;
    _trips = [
      for (final trip in _trips)
        if (trip.id == detailed.id) detailed else trip,
    ];
    notifyListeners();
    return detailed;
  }

  void selectCatalogProduct(CatalogProduct product) {
    _selectedCatalogProduct = product;
    final matchingTrip = _trips
        .where(
          (t) => t.origin.toLowerCase().contains(
            product.originCity.split(' ').first.toLowerCase(),
          ),
        )
        .firstOrNull;
    if (matchingTrip != null) {
      _selectedTrip = matchingTrip;
    }
    notifyListeners();
  }

  Future<PurchaseRequest> createOrder({
    required String description,
    String? url,
    required int priceUsd,
    required int weightGrams,
    Trip? tripOverride,
  }) async {
    if (!_demoMode && clientFactory == null && !isAuthenticated) {
      throw const ApiException(
        statusCode: 401,
        code: 'AUTHENTICATION_REQUIRED',
        message: 'Entre na sua conta para continuar.',
      );
    }
    final account = _selectedAccount;
    if (account == null) {
      throw const ApiException(
        statusCode: 403,
        code: 'ACCOUNT_REQUIRED',
        message: 'Sua conta de compras ainda não está disponível.',
      );
    }
    final targetTrip = tripOverride ?? _selectedTrip;
    if (targetTrip == null || !targetTrip.isAvailable) {
      throw const ApiException(
        statusCode: 409,
        code: 'TRIP_UNAVAILABLE',
        message: 'Selecione uma viagem disponível para continuar.',
      );
    }
    final product = Product(
      description: description.trim(),
      url: (url != null && url.trim().isNotEmpty) ? url.trim() : null,
      price: Money(amount: priceUsd.toString(), currency: 'USD'),
      estimatedWeightGrams: weightGrams,
    );

    final input = RequestInput(
      accountId: account.id,
      tripId: targetTrip.id,
      product: product,
    );

    final fingerprint = jsonEncode(input.toJson());
    return _orderSubmissions.putIfAbsent(
      fingerprint,
      () => _submitOrder(input, fingerprint).whenComplete(() {
        _orderSubmissions.remove(fingerprint);
      }),
    );
  }

  Future<PurchaseRequest> _submitOrder(
    RequestInput input,
    String fingerprint,
  ) async {
    final key = _pendingOrderKeys.putIfAbsent(
      fingerprint,
      () =>
          'ord-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
    );
    final created = await _clientForRequest(
      demoActor: 'buyer',
    ).createPurchaseRequest(input, key);
    _pendingOrderKeys.remove(fingerprint);
    if (!_orders.any((order) => order.id == created.id)) {
      _orders = [created, ..._orders];
      notifyListeners();
    }
    return created;
  }

  Future<Trip> publishTrip({
    required String travelerName,
    required String origin,
    required String destination,
    required String departureDate,
    required int availableWeightKg,
    required int pricePerKgUsd,
  }) async {
    final input = TripInput(
      origin: origin.trim(),
      destination: destination.trim(),
      departureDate: departureDate.trim(),
      timeZone: 'America/Sao_Paulo',
      availableWeightGrams: availableWeightKg * 1000,
      pricePerKg: Money(
        amount: (pricePerKgUsd * 100).toString(),
        currency: 'USD',
      ),
    );

    final fingerprint = jsonEncode(input.toJson());
    return _tripSubmissions.putIfAbsent(
      fingerprint,
      () => _submitTrip(input, fingerprint, travelerName).whenComplete(() {
        _tripSubmissions.remove(fingerprint);
      }),
    );
  }

  Future<Trip> _submitTrip(
    TripInput input,
    String fingerprint,
    String travelerName,
  ) async {
    final key = _pendingTripKeys.putIfAbsent(
      fingerprint,
      () =>
          'trip-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
    );
    final created = await _clientForRequest(
      demoActor: 'traveler',
    ).createTrip(input, key);
    _pendingTripKeys.remove(fingerprint);
    final stored = _demoMode && travelerName.trim().isNotEmpty
        ? Trip(
            id: created.id,
            travelerName: travelerName.trim(),
            origin: created.origin,
            destination: created.destination,
            departureDate: created.departureDate,
            timeZone: created.timeZone,
            availableWeightGrams: created.availableWeightGrams,
            pricePerKg: created.pricePerKg,
            isDemo: created.isDemo,
            status: created.status,
            rating: 0,
            reviewCount: 0,
          )
        : created;
    _replaceOwnedTrip(stored);
    if (stored.isAvailable) {
      _trips = [stored, ..._trips.where((trip) => trip.id != stored.id)];
    }
    _selectedTrip = stored;
    notifyListeners();
    return stored;
  }

  Future<Trip> updateTrip({
    required Trip trip,
    required String origin,
    required String destination,
    required String departureDate,
    required int availableWeightKg,
    required int pricePerKgUsd,
  }) async {
    final input = TripInput(
      origin: origin.trim(),
      destination: destination.trim(),
      departureDate: departureDate.trim(),
      timeZone: trip.timeZone,
      availableWeightGrams: availableWeightKg * 1000,
      pricePerKg: Money(
        amount: (pricePerKgUsd * 100).toString(),
        currency: 'USD',
      ),
    );
    final updated = await _clientForRequest(
      demoActor: 'traveler',
    ).updateTrip(trip.id, input);
    _replaceOwnedTrip(updated);
    _trips = [
      for (final available in _trips)
        if (available.id == updated.id) updated else available,
    ];
    if (_selectedTrip?.id == updated.id) _selectedTrip = updated;
    notifyListeners();
    return updated;
  }

  Future<Trip> cancelTrip(Trip trip) async {
    final cancelled = await _clientForRequest(
      demoActor: 'traveler',
    ).cancelTrip(trip.id);
    _replaceOwnedTrip(cancelled);
    _trips = _trips.where((available) => available.id != trip.id).toList();
    if (_selectedTrip?.id == trip.id) _selectedTrip = null;
    notifyListeners();
    return cancelled;
  }

  void _replaceOwnedTrip(Trip trip) {
    _myTrips = [trip, ..._myTrips.where((owned) => owned.id != trip.id)];
  }
}
